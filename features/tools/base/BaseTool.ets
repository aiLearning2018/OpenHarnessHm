// tools/base/BaseTool.ets
// 工具基类定义

import { ToolContext, ToolResult } from './ToolContext';

// 工具参数定义
export interface ToolParameter {
  type: string;
  description: string;
  enum?: string[];
  required?: boolean;
  properties?: Record<string, ToolParameter>;
  items?: ToolParameter;
}

// 工具输入 Schema
export interface ToolInputSchema {
  type: 'object';
  properties: Record<string, ToolParameter>;
  required?: string[];
}

// 工具基类
export abstract class BaseTool<TInput extends object = object> {
  // 工具名称
  abstract readonly name: string;
  
  // 工具描述
  abstract readonly description: string;
  
  // 输入参数 Schema
  abstract readonly inputSchema: ToolInputSchema;
  
  // 执行工具
  abstract execute(args: TInput, context: ToolContext): Promise<ToolResult>;

  // 是否是只读操作 (影响权限检查)
  isReadOnly(args: TInput): boolean {
    return false;
  }

  // 是否需要用户确认 (即使非只读)
  requiresConfirmation(args: TInput): boolean {
    return !this.isReadOnly(args);
  }

  // 转换为 API Schema 格式
  toApiSchema(): object {
    return {
      name: this.name,
      description: this.description,
      input_schema: this.inputSchema
    };
  }

  // 获取详细的工具信息 (用于 UI 展示)
  getToolInfo(): ToolInfo {
    return {
      name: this.name,
      description: this.description,
      schema: this.inputSchema,
      isReadOnly: false,
      examples: this.getExamples(),
      notes: this.getNotes()
    };
  }

  // 获取使用示例
  protected getExamples(): ToolExample[] {
    return [];
  }

  // 获取使用注意事项
  protected getNotes(): string[] {
    return [];
  }

  // 验证输入参数 (可选重写)
  validateInput(args: unknown): args is TInput {
    // 基础类型检查
    if (typeof args !== 'object' || args === null) {
      return false;
    }
    
    // 检查必需参数
    const required = this.inputSchema.required || [];
    const argObj = args as Record<string, unknown>;
    
    for (const key of required) {
      if (!(key in argObj)) {
        return false;
      }
    }
    
    return true;
  }

  // 格式化错误结果
  protected errorResult(message: string, details?: object): ToolResult {
    return {
      output: message,
      isError: true,
      metadata: { ...details, tool_name: this.name }
    };
  }

  // 格式化成功结果
  protected successResult(output: string, metadata?: object): ToolResult {
    return {
      output,
      isError: false,
      metadata: { ...metadata, tool_name: this.name }
    };
  }
}

// 工具信息
export interface ToolInfo {
  name: string;
  description: string;
  schema: ToolInputSchema;
  isReadOnly: boolean;
  examples: ToolExample[];
  notes: string[];
}

// 工具使用示例
export interface ToolExample {
  description: string;
  input: object;
  expectedOutput?: string;
}

// 工具类别
export enum ToolCategory {
  FILE = 'file',
  SHELL = 'shell',
  SEARCH = 'search',
  WEB = 'web',
  AGENT = 'agent',
  TASK = 'task',
  MCP = 'mcp',
  SYSTEM = 'system',
  UTILITY = 'utility'
}

// 分类工具基类
export abstract class FileTool<TInput extends object> extends BaseTool<TInput> {
  readonly category = ToolCategory.FILE;
}

export abstract class WebTool<TInput extends object> extends BaseTool<TInput> {
  readonly category = ToolCategory.WEB;
  
  isReadOnly(): boolean {
    return true; // Web 工具默认只读
  }
}

export abstract class SystemTool<TInput extends object> extends BaseTool<TInput> {
  readonly category = ToolCategory.SYSTEM;
}
