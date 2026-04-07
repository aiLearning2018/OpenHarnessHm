// api/base/LLMClient.ets
// LLM 客户端接口定义

// 流式请求参数
export interface StreamParams {
  messages: object[];
  tools?: object[];
  system?: string;
  model: string;
  maxTokens?: number;
  temperature?: number;
  topP?: number;
  stopSequences?: string[];
}

// Token 使用统计
export interface TokenUsage {
  input_tokens: number;
  output_tokens: number;
  cache_creation_input_tokens?: number;
  cache_read_input_tokens?: number;
}

// LLM 客户端接口
export interface LLMClient {
  // 流式发送消息
  streamMessages(params: StreamParams): AsyncIterable<StreamEvent>;
  
  // 计算 Token 数量 (如果 API 支持)
  countTokens?(text: string): Promise<number>;
  
  // 获取可用模型列表
  listModels?(): Promise<string[]>;
  
  // 健康检查
  healthCheck?(): Promise<boolean>;
}

// 引入 StreamEvent
import { StreamEvent } from '../../core/model/StreamEvent';

// 客户端配置
export interface LLMClientConfig {
  baseUrl: string;
  apiKey: string;
  defaultModel?: string;
  timeout?: number;
  maxRetries?: number;
}

// 客户端错误
export class LLMClientError extends Error {
  constructor(
    message: string,
    public code: string,
    public statusCode?: number,
    public details?: object
  ) {
    super(message);
    this.name = 'LLMClientError';
  }
}

// 错误类型
export enum LLMErrorCode {
  AUTH_ERROR = 'auth_error',
  RATE_LIMIT = 'rate_limit',
  INVALID_REQUEST = 'invalid_request',
  CONTEXT_LENGTH_EXCEEDED = 'context_length_exceeded',
  SERVER_ERROR = 'server_error',
  NETWORK_ERROR = 'network_error',
  TIMEOUT = 'timeout',
  UNKNOWN = 'unknown'
}

// 提供者类型
export enum ProviderType {
  ANTHROPIC = 'anthropic',
  OPENAI = 'openai',
  COPILOT = 'copilot',
  CODEX = 'codex',
  CUSTOM = 'custom'
}

// 提供者配置
export interface ProviderConfig {
  id: string;
  name: string;
  type: ProviderType;
  baseUrl: string;
  apiKey?: string;
  authType: 'api_key' | 'oauth' | 'bearer';
  defaultModel: string;
  availableModels: string[];
  features: {
    streaming: boolean;
    functionCalling: boolean;
    vision: boolean;
    reasoning: boolean;
  };
}
