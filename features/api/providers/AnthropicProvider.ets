// api/providers/AnthropicProvider.ets
// Anthropic API 提供者实现

import { LLMClient, LLMClientConfig, StreamParams, LLMClientError, LLMErrorCode } from '../base/LLMClient';
import { StreamEvent, EventType } from '../../core/model/StreamEvent';
import http from '@ohos.net.http';

export class AnthropicProvider implements LLMClient {
  private config: LLMClientConfig;

  constructor(config: LLMClientConfig) {
    this.config = {
      timeout: 60000,
      maxRetries: 3,
      ...config
    };
  }

  async *streamMessages(params: StreamParams): AsyncIterable<StreamEvent> {
    const requestBody = this.buildRequestBody(params);
    
    let retries = 0;
    const maxRetries = this.config.maxRetries || 3;

    while (retries < maxRetries) {
      try {
        const httpRequest = http.createHttp();
        
        const response = await new Promise<http.HttpResponse>((resolve, reject) => {
          httpRequest.request(`${this.config.baseUrl}/v1/messages`, {
            method: http.RequestMethod.POST,
            header: {
              'Content-Type': 'application/json',
              'Authorization': `Bearer ${this.config.apiKey}`,
              'Accept': 'text/event-stream'
            },
            extraData: JSON.stringify(requestBody)
          }, (err, data) => {
            if (err) {
              reject(err);
            } else {
              resolve(data);
            }
          });

          // 设置超时
          setTimeout(() => {
            httpRequest.destroy();
            reject(new Error('Request timeout'));
          }, this.config.timeout);
        });

        if (response.responseCode !== 200) {
          throw this.handleErrorResponse(response);
        }

        // 解析 SSE 流
        yield* this.parseSSEStream(response.result);
        return;

      } catch (error) {
        retries++;
        if (retries >= maxRetries) {
          throw error;
        }
        // 指数退避
        await this.delay(Math.pow(2, retries) * 1000);
      }
    }
  }

  private buildRequestBody(params: StreamParams): object {
    return {
      model: params.model,
      messages: params.messages,
      system: params.system,
      max_tokens: params.maxTokens || 4096,
      temperature: params.temperature,
      top_p: params.topP,
      stop_sequences: params.stopSequences,
      tools: params.tools,
      stream: true
    };
  }

  private async *parseSSEStream(streamData: string): AsyncIterable<StreamEvent> {
    const lines = streamData.split('\n');
    let currentToolUse: { id: string; name: string; input: string } | null = null;

    for (const line of lines) {
      if (!line.startsWith('data: ')) continue;
      
      const data = line.slice(6);
      if (data === '[DONE]') {
        yield { type: EventType.DONE, timestamp: Date.now() };
        continue;
      }

      try {
        const event = JSON.parse(data);
        
        switch (event.type) {
          case 'message_start':
            // 消息开始
            break;
            
          case 'content_block_start':
            if (event.content_block?.type === 'tool_use') {
              currentToolUse = {
                id: event.content_block.id,
                name: event.content_block.name,
                input: ''
              };
              yield {
                type: EventType.TOOL_USE_START,
                tool_use_id: event.content_block.id,
                name: event.content_block.name,
                input: event.content_block.input || {},
                timestamp: Date.now()
              };
            }
            break;
            
          case 'content_block_delta':
            if (event.delta?.type === 'text_delta') {
              yield {
                type: EventType.TEXT_DELTA,
                delta: event.delta.text,
                timestamp: Date.now()
              };
            } else if (event.delta?.type === 'input_json_delta' && currentToolUse) {
              currentToolUse.input += event.delta.partial_json;
            }
            break;
            
          case 'content_block_stop':
            if (currentToolUse) {
              yield {
                type: EventType.TOOL_USE_END,
                tool_use_id: currentToolUse.id,
                timestamp: Date.now()
              };
              currentToolUse = null;
            }
            break;
            
          case 'message_delta':
            if (event.usage) {
              yield {
                type: EventType.USAGE_UPDATE,
                usage: {
                  input_tokens: event.usage.input_tokens || 0,
                  output_tokens: event.usage.output_tokens || 0
                },
                timestamp: Date.now()
              };
            }
            break;
            
          case 'message_stop':
            yield {
              type: EventType.DONE,
              stop_reason: event.message?.stop_reason,
              timestamp: Date.now()
            };
            break;
        }
      } catch (e) {
        console.error('Failed to parse SSE event:', e);
      }
    }
  }

  private handleErrorResponse(response: http.HttpResponse): LLMClientError {
    const statusCode = response.responseCode;
    let code = LLMErrorCode.UNKNOWN;
    let message = `HTTP ${statusCode}`;

    try {
      const body = JSON.parse(response.result);
      message = body.error?.message || message;

      switch (statusCode) {
        case 401:
          code = LLMErrorCode.AUTH_ERROR;
          break;
        case 429:
          code = LLMErrorCode.RATE_LIMIT;
          break;
        case 400:
          code = LLMErrorCode.INVALID_REQUEST;
          break;
        case 413:
          code = LLMErrorCode.CONTEXT_LENGTH_EXCEEDED;
          break;
        case 500:
        case 502:
        case 503:
          code = LLMErrorCode.SERVER_ERROR;
          break;
      }
    } catch {
      // 解析失败，使用默认错误
    }

    return new LLMClientError(message, code, statusCode);
  }

  async countTokens(text: string): Promise<number> {
    // 简单估算：中文字符 2 tokens，英文单词 1.3 tokens
    let tokens = 0;
    for (const char of text) {
      tokens = char.charCodeAt(0) > 127 ? tokens + 2 : tokens + 1;
    }
    return Math.ceil(tokens * 0.5);
  }

  private delay(ms: number): Promise<void> {
    return new Promise(resolve => setTimeout(resolve, ms));
  }
}
