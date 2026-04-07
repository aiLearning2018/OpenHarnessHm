// tools/implementations/GlobTool.ets
// 文件模式匹配工具

import { BaseTool, FileTool } from '../base/BaseTool';
import { ToolContext, ToolResult } from '../base/ToolContext';
import fs from '@ohos.file.fs';
import path from 'path';

interface GlobInput {
  pattern: string;
  path?: string;
}

interface FileMatch {
  path: string;
  size: number;
  modified: number;
}

export class GlobTool extends FileTool<GlobInput> {
  readonly name = 'glob';
  readonly description = '根据模式查找文件，支持 * 和 ** 通配符';
  
  readonly inputSchema = {
    type: 'object' as const,
    properties: {
      pattern: {
        type: 'string',
        description: '匹配模式，如 "*.ets" 或 "src/**/*.ts"'
      },
      path: {
        type: 'string',
        description: '搜索起始路径 (可选，默认当前目录)'
      }
    },
    required: ['pattern']
  };

  isReadOnly(): boolean {
    return true;
  }

  async execute(args: GlobInput, context: ToolContext): Promise<ToolResult> {
    const startTime = Date.now();
    
    try {
      const searchPath = args.path 
        ? this.resolvePath(args.path, context)
        : context.cwd;

      // 解析模式
      const pattern = args.pattern;
      const isRecursive = pattern.includes('**');
      const filePattern = pattern.replace(/\*\*\//g, '').replace(/\*/g, '.*');
      const regex = new RegExp(filePattern + '$', 'i');

      // 执行搜索
      const matches: FileMatch[] = [];
      await this.searchDirectory(searchPath, regex, isRecursive, matches, context);

      // 格式化输出
      const output = matches.length > 0
        ? matches.map(m => `${m.path}`).join('\n')
        : '未找到匹配的文件';

      const executionTime = Date.now() - startTime;

      return this.successResult(output, {
        pattern: args.pattern,
        search_path: searchPath,
        match_count: matches.length,
        execution_time_ms: executionTime
      });

    } catch (error) {
      return this.errorResult(
        `搜索失败: ${error instanceof Error ? error.message : String(error)}`,
        { pattern: args.pattern }
      );
    }
  }

  private async searchDirectory(
    dir: string,
    pattern: RegExp,
    recursive: boolean,
    matches: FileMatch[],
    context: ToolContext,
    depth: number = 0
  ): Promise<void> {
    // 限制递归深度
    if (depth > 10) return;

    try {
      const list = fs.listFile(dir);
      
      for (const item of list) {
        const fullPath = path.join(dir, item);
        const stat = fs.stat(fullPath);
        
        if (stat.isDirectory()) {
          if (recursive) {
            await this.searchDirectory(fullPath, pattern, recursive, matches, context, depth + 1);
          }
        } else if (stat.isFile() && pattern.test(item)) {
          matches.push({
            path: fullPath,
            size: stat.size,
            modified: stat.mtime
          });
        }
      }
    } catch (error) {
      console.error(`Error reading directory ${dir}:`, error);
    }
  }

  private resolvePath(inputPath: string, context: ToolContext): string {
    if (path.isAbsolute(inputPath)) {
      return inputPath;
    }
    return path.join(context.cwd, inputPath);
  }

  protected getExamples(): ToolExample[] {
    return [
      {
        description: '查找所有 ets 文件',
        input: { pattern: '*.ets' }
      },
      {
        description: '递归查找所有测试文件',
        input: { pattern: '**/*.test.ets' }
      },
      {
        description: '在特定目录查找',
        input: { pattern: '*.json', path: 'src/resources' }
      }
    ];
  }
}
