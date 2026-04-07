// core/model/Message.ets
// 消息模型定义

export enum MessageRole {
  USER = 'user',
  ASSISTANT = 'assistant',
  SYSTEM = 'system'
}

export enum ContentType {
  TEXT = 'text',
  IMAGE = 'image',
  TOOL_USE = 'tool_use',
  TOOL_RESULT = 'tool_result'
}

// 内容块基类
export interface ContentBlock {
  type: ContentType;
}

// 文本块
export interface TextBlock extends ContentBlock {
  type: ContentType.TEXT;
  text: string;
}

// 图片块
export interface ImageBlock extends ContentBlock {
  type: ContentType.IMAGE;
  source: {
    type: 'base64' | 'url';
    media_type: string;
    data: string;
  };
}

// 工具使用块
export interface ToolUseBlock extends ContentBlock {
  type: ContentType.TOOL_USE;
  id: string;
  name: string;
  input: object;
}

// 工具结果块
export interface ToolResultBlock extends ContentBlock {
  type: ContentType.TOOL_RESULT;
  tool_use_id: string;
  content: string | ContentBlock[];
  is_error?: boolean;
}

export type Content = TextBlock | ImageBlock | ToolUseBlock | ToolResultBlock;

// 对话消息
export class ConversationMessage {
  id: string;
  role: MessageRole;
  content: Content[];
  timestamp: number;
  metadata?: Record<string, object>;

  constructor(role: MessageRole, content: Content[], metadata?: Record<string, object>) {
    this.id = this.generateId();
    this.role = role;
    this.content = content;
    this.timestamp = Date.now();
    this.metadata = metadata;
  }

  // 创建文本消息
  static fromText(role: MessageRole, text: string): ConversationMessage {
    return new ConversationMessage(role, [{ type: ContentType.TEXT, text }]);
  }

  // 创建用户文本消息
  static fromUserText(text: string): ConversationMessage {
    return this.fromText(MessageRole.USER, text);
  }

  // 创建助手文本消息
  static fromAssistantText(text: string): ConversationMessage {
    return this.fromText(MessageRole.ASSISTANT, text);
  }

  // 创建系统消息
  static fromSystem(text: string): ConversationMessage {
    return this.fromText(MessageRole.SYSTEM, text);
  }

  // 创建工具使用消息
  static fromToolUse(toolUse: ToolUseBlock): ConversationMessage {
    return new ConversationMessage(MessageRole.ASSISTANT, [toolUse]);
  }

  // 创建工具结果消息
  static fromToolResult(toolResult: ToolResultBlock): ConversationMessage {
    return new ConversationMessage(MessageRole.USER, [toolResult]);
  }

  // 获取纯文本内容
  getTextContent(): string {
    return this.content
      .filter((c): c is TextBlock => c.type === ContentType.TEXT)
      .map(c => c.text)
      .join('');
  }

  // 获取工具使用块
  getToolUses(): ToolUseBlock[] {
    return this.content.filter((c): c is ToolUseBlock => c.type === ContentType.TOOL_USE);
  }

  // 检查是否包含工具使用
  hasToolUses(): boolean {
    return this.content.some(c => c.type === ContentType.TOOL_USE);
  }

  // 检查是否是工具结果消息
  isToolResult(): boolean {
    return this.content.every(c => c.type === ContentType.TOOL_RESULT);
  }

  // 转换为 API 格式
  toApiFormat(): object {
    return {
      role: this.role,
      content: this.content.map(c => {
        switch (c.type) {
          case ContentType.TEXT:
            return { type: 'text', text: (c as TextBlock).text };
          case ContentType.IMAGE:
            return { type: 'image', source: (c as ImageBlock).source };
          case ContentType.TOOL_USE:
            return {
              type: 'tool_use',
              id: (c as ToolUseBlock).id,
              name: (c as ToolUseBlock).name,
              input: (c as ToolUseBlock).input
            };
          case ContentType.TOOL_RESULT:
            return {
              type: 'tool_result',
              tool_use_id: (c as ToolResultBlock).tool_use_id,
              content: (c as ToolResultBlock).content,
              is_error: (c as ToolResultBlock).is_error
            };
          default:
            return c;
        }
      })
    };
  }

  private generateId(): string {
    return `${Date.now()}-${Math.random().toString(36).substr(2, 9)}`;
  }
}

// 对话会话
export class Conversation {
  id: string;
  title: string;
  messages: ConversationMessage[];
  createdAt: number;
  updatedAt: number;
  model: string;
  systemPrompt?: string;
  metadata?: Record<string, object>;

  constructor(model: string, systemPrompt?: string) {
    this.id = this.generateId();
    this.title = '新对话';
    this.messages = [];
    this.createdAt = Date.now();
    this.updatedAt = Date.now();
    this.model = model;
    this.systemPrompt = systemPrompt;
  }

  addMessage(message: ConversationMessage): void {
    this.messages.push(message);
    this.updatedAt = Date.now();
    this.updateTitle();
  }

  clear(): void {
    this.messages = [];
    this.updatedAt = Date.now();
  }

  getLastMessage(): ConversationMessage | undefined {
    return this.messages[this.messages.length - 1];
  }

  hasPendingToolResults(): boolean {
    const lastMsg = this.getLastMessage();
    if (!lastMsg || lastMsg.role !== MessageRole.USER) {
      return false;
    }
    return lastMsg.isToolResult();
  }

  private updateTitle(): void {
    // 根据第一条用户消息生成标题
    if (this.title === '新对话' && this.messages.length > 0) {
      const firstUserMsg = this.messages.find(m => m.role === MessageRole.USER);
      if (firstUserMsg) {
        const text = firstUserMsg.getTextContent();
        this.title = text.slice(0, 20) + (text.length > 20 ? '...' : '');
      }
    }
  }

  private generateId(): string {
    return `conv-${Date.now()}-${Math.random().toString(36).substr(2, 9)}`;
  }
}
