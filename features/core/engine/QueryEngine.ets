// core/engine/QueryEngine.ets
// 查询引擎 - 核心 Agent 循环

import { Conversation, ConversationMessage, MessageRole } from '../model/Message';
import { StreamEvent, EventType, ToolUseStartEvent } from '../model/StreamEvent';
import { ToolRegistry } from '../../tools/base/ToolRegistry';
import { ToolContext } from '../../tools/base/ToolContext';
import { PermissionChecker } from '../../security/PermissionChecker';
import { LLMClient, StreamParams } from '../../api/base/LLMClient';

export interface QueryEngineConfig {
  // API 客户端
  apiClient: LLMClient;
  
  // 工具注册表
  toolRegistry: ToolRegistry;
  
  // 权限检查器
  permissionChecker: PermissionChecker;
  
  // 当前工作目录
  cwd: string;
  
  // 使用的模型
  model: string;
  
  // 系统提示词
  systemPrompt: string;
  
  // 最大 Token 数
  maxTokens?: number;
  
  // 最大轮数
  maxTurns?: number;
  
  // 工具执行上下文
  toolContext: ToolContext;
}

export class QueryEngine {
  private config: QueryEngineConfig;
  private conversation: Conversation;
  private totalUsage = { input_tokens: 0, output_tokens: 0 };
  private currentToolUses: Map<string, ToolUseStartEvent> = new Map();

  constructor(config: QueryEngineConfig, conversation: Conversation) {
    this.config = {
      maxTokens: 4096,
      maxTurns: 8,
      ...config
    };
    this.conversation = conversation;
  }

  // 提交用户消息并执行 Agent 循环
  async *submitMessage(prompt: string): AsyncIterable<StreamEvent> {
    // 添加用户消息
    const userMessage = ConversationMessage.fromUserText(prompt);
    this.conversation.addMessage(userMessage);

    // 执行查询循环
    yield* this.runQueryLoop();
  }

  // 继续待处理的工具循环
  async *continuePending(): AsyncIterable<StreamEvent> {
    if (!this.conversation.hasPendingToolResults()) {
      yield {
        type: EventType.ERROR,
        error: { code: 'NO_PENDING', message: '没有待处理的工具结果' }
      };
      return;
    }
    yield* this.runQueryLoop();
  }

  // 核心查询循环
  private async *runQueryLoop(): AsyncIterable<StreamEvent> {
    let turns = 0;
    const maxTurns = this.config.maxTurns || 8;

    while (turns < maxTurns) {
      turns++;

      // 构建请求参数
      const params: StreamParams = {
        messages: this.conversation.messages.map(m => m.toApiFormat()),
        tools: this.config.toolRegistry.toApiSchema(),
        system: this.config.systemPrompt,
        model: this.config.model,
        maxTokens: this.config.maxTokens
      };

      try {
        // 调用 LLM API
        const stream = this.config.apiClient.streamMessages(params);
        let hasToolUse = false;

        for await (const event of stream) {
          yield event;

          // 处理不同类型的事件
          switch (event.type) {
            case EventType.TOOL_USE_START:
              this.currentToolUses.set(event.tool_use_id, event);
              hasToolUse = true;
              break;

            case EventType.TOOL_USE_END:
              // 执行工具
              const toolEvent = this.currentToolUses.get(event.tool_use_id);
              if (toolEvent) {
                yield* this.executeTool(toolEvent);
                this.currentToolUses.delete(event.tool_use_id);
              }
              break;

            case EventType.USAGE_UPDATE:
              this.totalUsage.input_tokens += event.usage.input_tokens;
              this.totalUsage.output_tokens += event.usage.output_tokens;
              break;

            case EventType.DONE:
              // 如果是正常结束且没有工具调用，退出循环
              if (!hasToolUse) {
                return;
              }
              break;

            case EventType.ERROR:
              // 遇到错误，停止循环
              return;
          }
        }

        // 检查是否还有待处理的工具调用
        if (this.currentToolUses.size === 0) {
          return;
        }

      } catch (error) {
        yield {
          type: EventType.ERROR,
          error: {
            code: 'STREAM_ERROR',
            message: error instanceof Error ? error.message : '流处理错误'
          }
        };
        return;
      }
    }

    // 达到最大轮数
    yield {
      type: EventType.ERROR,
      error: {
        code: 'MAX_TURNS_REACHED',
        message: `已达到最大轮数限制 (${maxTurns})`
      }
    };
  }

  // 执行工具
  private async *executeTool(toolEvent: ToolUseStartEvent): AsyncIterable<StreamEvent> {
    const toolName = toolEvent.name;
    const toolInput = toolEvent.input;
    const toolUseId = toolEvent.tool_use_id;

    // 获取工具
    const tool = this.config.toolRegistry.get(toolName);
    if (!tool) {
      yield {
        type: EventType.TOOL_RESULT,
        tool_use_id: toolUseId,
        result: {
          output: `错误: 未找到工具 '${toolName}'`,
          isError: true
        }
      };
      return;
    }

    // 检查是否是只读操作
    const isReadOnly = tool.isReadOnly(toolInput as object);

    // 权限检查
    const permitted = await this.config.permissionChecker.check({
      toolName,
      toolInput: toolInput as object,
      isReadOnly,
      cwd: this.config.cwd
    });

    if (!permitted) {
      yield {
        type: EventType.TOOL_RESULT,
        tool_use_id: toolUseId,
        result: {
          output: `权限被拒绝: 用户未授权执行 '${toolName}'`,
          isError: true
        }
      };
      return;
    }

    // 执行工具
    const result = await this.config.toolRegistry.execute(
      toolName,
      toolInput as object,
      this.config.toolContext
    );

    // 添加工具结果到对话
    this.conversation.addMessage(
      ConversationMessage.fromToolResult({
        type: 'tool_result' as const,
        tool_use_id: toolUseId,
        content: result.output,
        is_error: result.isError
      })
    );

    yield {
      type: EventType.TOOL_RESULT,
      tool_use_id: toolUseId,
      result
    };
  }

  // 获取总使用量
  getTotalUsage(): { input_tokens: number; output_tokens: number } {
    return { ...this.totalUsage };
  }

  // 清空对话历史
  clear(): void {
    this.conversation.clear();
    this.totalUsage = { input_tokens: 0, output_tokens: 0 };
    this.currentToolUses.clear();
  }

  // 设置系统提示词
  setSystemPrompt(prompt: string): void {
    this.conversation.systemPrompt = prompt;
  }

  // 设置模型
  setModel(model: string): void {
    this.conversation.model = model;
  }
}
