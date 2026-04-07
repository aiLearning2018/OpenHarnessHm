// tools/implementations/WebSearchTool.ets
// 网页搜索工具

import { BaseTool, WebTool } from '../base/BaseTool';
import { ToolContext, ToolResult } from '../base/ToolContext';
import http from '@ohos.net.http';

interface WebSearchInput {
  query: string;
  num_results?: number;
}

interface SearchResult {
  title: string;
  url: string;
  snippet: string;
}

export class WebSearchTool extends WebTool<WebSearchInput> {
  readonly name = 'web_search';
  readonly description = '搜索网页内容，获取相关信息';
  
  readonly inputSchema = {
    type: 'object' as const,
    properties: {
      query: {
        type: 'string',
        description: '搜索关键词'
      },
      num_results: {
        type: 'number',
        description: '返回结果数量 (默认 5)',
        default: 5
      }
    },
    required: ['query']
  };

  private searchApiUrl: string = 'https://search.brave.com/api/suggest';

  async execute(args: WebSearchInput, context: ToolContext): Promise<ToolResult> {
    const startTime = Date.now();
    const numResults = args.num_results || 5;

    try {
      // 创建 HTTP 请求
      const httpRequest = http.createHttp();
      
      // 构建搜索 URL (使用 DuckDuckGo 即时答案 API)
      const searchUrl = `https://api.duckduckgo.com/?q=${encodeURIComponent(args.query)}&format=json`;

      const response = await new Promise<http.HttpResponse>((resolve, reject) => {
        httpRequest.request(searchUrl, {
          method: http.RequestMethod.GET,
          header: { 'Accept': 'application/json' }
        }, (err, data) => {
          if (err) {
            reject(err);
          } else {
            resolve(data);
          }
        });
      });

      if (response.responseCode !== 200) {
        return this.errorResult(`搜索请求失败: HTTP ${response.responseCode}`);
      }

      // 解析结果
      const results = this.parseSearchResults(response.result);
      
      // 格式化输出
      const formattedResults = results.slice(0, numResults).map((r, i) => {
        return `${i + 1}. ${r.title}\n   ${r.url}\n   ${r.snippet}`;
      }).join('\n\n');

      const executionTime = Date.now() - startTime;

      return this.successResult(formattedResults || '未找到相关结果', {
        query: args.query,
        result_count: results.length,
        execution_time_ms: executionTime
      });

    } catch (error) {
      return this.errorResult(
        `搜索失败: ${error instanceof Error ? error.message : String(error)}`,
        { query: args.query }
      );
    }
  }

  private parseSearchResults(result: string): SearchResult[] {
    try {
      // DuckDuckGo 返回格式特殊，需要自定义解析
      // 这里简化处理
      const results: SearchResult[] = [];
      
      // 尝试解析 JSON
      const data = JSON.parse(result);
      
      if (data.RelatedTopics) {
        for (const topic of data.RelatedTopics) {
          if (topic.FirstURL && topic.Text) {
            results.push({
              title: topic.Text.split(' - ')[0] || topic.Text,
              url: topic.FirstURL,
              snippet: topic.Text
            });
          }
        }
      }

      return results;
    } catch {
      return [];
    }
  }

  protected getExamples(): ToolExample[] {
    return [
      {
        description: '搜索鸿蒙开发文档',
        input: { query: 'HarmonyOS ArkTS 开发文档' }
      },
      {
        description: '搜索技术概念',
        input: { query: '什么是 LLM Agent', num_results: 3 }
      }
    ];
  }
}
