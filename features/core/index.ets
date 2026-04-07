// core/index.ets
// 核心模块导出

// 模型
export { 
  Conversation, 
  ConversationMessage, 
  MessageRole, 
  ContentType,
  Content,
  TextBlock,
  ImageBlock,
  ToolUseBlock,
  ToolResultBlock
} from './model/Message';

export { 
  StreamEvent,
  EventType,
  TextDeltaEvent,
  ToolUseStartEvent,
  ToolResultEvent,
  PermissionRequestEvent,
  ErrorEvent,
  DoneEvent,
  StreamEventFactory
} from './model/StreamEvent';

// 引擎
export { QueryEngine, QueryEngineConfig } from './engine/QueryEngine';
