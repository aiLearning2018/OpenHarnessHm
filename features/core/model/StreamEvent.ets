// core/model/StreamEvent.ets
// 流事件定义 - 用于 LLM 响应流

export enum EventType {
  // 文本增量
  TEXT_DELTA = 'text_delta',
  
  // 工具使用
  TOOL_USE_START = 'tool_use_start',
  TOOL_USE_DELTA = 'tool_use_delta',
  TOOL_USE_END = 'tool_use_end',
  
  // 工具结果
  TOOL_RESULT = 'tool_result',
  
  // 权限请求
  PERMISSION_REQUEST = 'permission_request',
  PERMISSION_GRANTED = 'permission_granted',
  PERMISSION_DENIED = 'permission_denied',
  
  // 使用统计
  USAGE_UPDATE = 'usage_update',
  
  // 错误
  ERROR = 'error',
  
  // 完成
  DONE = 'done',
  
  // 思考/推理 (用于推理模型)
  THINKING_DELTA = 'thinking_delta',
  THINKING_END = 'thinking_end'
}

// 基础事件
export interface BaseStreamEvent {
  type: EventType;
  timestamp?: number;
}

// 文本增量事件
export interface TextDeltaEvent extends BaseStreamEvent {
  type: EventType.TEXT_DELTA;
  delta: string;
}

// 思考增量事件
export interface ThinkingDeltaEvent extends BaseStreamEvent {
  type: EventType.THINKING_DELTA;
  delta: string;
}

// 思考结束事件
export interface ThinkingEndEvent extends BaseStreamEvent {
  type: EventType.THINKING_END;
}

// 工具使用开始
export interface ToolUseStartEvent extends BaseStreamEvent {
  type: EventType.TOOL_USE_START;
  tool_use_id: string;
  name: string;
  input: object;
}

// 工具使用增量 (用于流式输入)
export interface ToolUseDeltaEvent extends BaseStreamEvent {
  type: EventType.TOOL_USE_DELTA;
  tool_use_id: string;
  partial_input: string;
}

// 工具使用结束
export interface ToolUseEndEvent extends BaseStreamEvent {
  type: EventType.TOOL_USE_END;
  tool_use_id: string;
}

// 工具结果
export interface ToolResultEvent extends BaseStreamEvent {
  type: EventType.TOOL_RESULT;
  tool_use_id: string;
  result: {
    output: string;
    isError?: boolean;
    metadata?: Record<string, object>;
  };
}

// 权限请求
export interface PermissionRequestEvent extends BaseStreamEvent {
  type: EventType.PERMISSION_REQUEST;
  tool_name: string;
  tool_input: object;
  is_read_only: boolean;
  request_id: string;
}

// 权限已授予
export interface PermissionGrantedEvent extends BaseStreamEvent {
  type: EventType.PERMISSION_GRANTED;
  request_id: string;
}

// 权限已拒绝
export interface PermissionDeniedEvent extends BaseStreamEvent {
  type: EventType.PERMISSION_DENIED;
  request_id: string;
  reason?: string;
}

// Token 使用统计
export interface UsageUpdateEvent extends BaseStreamEvent {
  type: EventType.USAGE_UPDATE;
  usage: {
    input_tokens: number;
    output_tokens: number;
    total_tokens: number;
  };
}

// 错误事件
export interface ErrorEvent extends BaseStreamEvent {
  type: EventType.ERROR;
  error: {
    code: string;
    message: string;
    details?: object;
  };
}

// 完成事件
export interface DoneEvent extends BaseStreamEvent {
  type: EventType.DONE;
  stop_reason?: 'end_turn' | 'max_tokens' | 'stop_sequence' | 'tool_use' | string;
}

// 联合类型
export type StreamEvent =
  | TextDeltaEvent
  | ThinkingDeltaEvent
  | ThinkingEndEvent
  | ToolUseStartEvent
  | ToolUseDeltaEvent
  | ToolUseEndEvent
  | ToolResultEvent
  | PermissionRequestEvent
  | PermissionGrantedEvent
  | PermissionDeniedEvent
  | UsageUpdateEvent
  | ErrorEvent
  | DoneEvent;

// 事件工厂函数
export class StreamEventFactory {
  static textDelta(delta: string): TextDeltaEvent {
    return { type: EventType.TEXT_DELTA, delta, timestamp: Date.now() };
  }

  static thinkingDelta(delta: string): ThinkingDeltaEvent {
    return { type: EventType.THINKING_DELTA, delta, timestamp: Date.now() };
  }

  static toolUseStart(tool_use_id: string, name: string, input: object): ToolUseStartEvent {
    return { type: EventType.TOOL_USE_START, tool_use_id, name, input, timestamp: Date.now() };
  }

  static toolResult(
    tool_use_id: string, 
    output: string, 
    isError?: boolean, 
    metadata?: Record<string, object>
  ): ToolResultEvent {
    return {
      type: EventType.TOOL_RESULT,
      tool_use_id,
      result: { output, isError, metadata },
      timestamp: Date.now()
    };
  }

  static permissionRequest(
    tool_name: string, 
    tool_input: object, 
    is_read_only: boolean
  ): PermissionRequestEvent {
    return {
      type: EventType.PERMISSION_REQUEST,
      tool_name,
      tool_input,
      is_read_only,
      request_id: `perm-${Date.now()}-${Math.random().toString(36).substr(2, 9)}`,
      timestamp: Date.now()
    };
  }

  static error(code: string, message: string, details?: object): ErrorEvent {
    return {
      type: EventType.ERROR,
      error: { code, message, details },
      timestamp: Date.now()
    };
  }

  static done(stop_reason?: string): DoneEvent {
    return { type: EventType.DONE, stop_reason, timestamp: Date.now() };
  }

  static usageUpdate(input_tokens: number, output_tokens: number): UsageUpdateEvent {
    return {
      type: EventType.USAGE_UPDATE,
      usage: {
        input_tokens,
        output_tokens,
        total_tokens: input_tokens + output_tokens
      },
      timestamp: Date.now()
    };
  }
}
