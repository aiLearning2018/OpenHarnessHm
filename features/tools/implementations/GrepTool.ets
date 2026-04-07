// tools/implementations/GrepTool.ets
// 文本搜索工具

import { BaseTool, FileTool } from '../base/BaseTool';
import { ToolContext, ToolResult } from '../base/ToolContext';
import fs from '@ohos.file.fs';
import path from 'path';

interface GrepInput {
  pattern: string;
  path?: string;
  include?: string;
  output_mode?: 'content' | 'files_with_matches';
}

interface GrepMatch {
  file: string;
  line: number;
  content: string;
}

export class GrepTool extends FileTool<GrepInput> {
  readonly name = 'grep';
  readonly description = '在文件中搜索文本模式，支持正则表达式';
  
  readonly inputSchema = {
    type: 'object' as const,
    properties: {
      pattern: {
        type: 'string',
        description: '搜索模式 (正则表达式)'
      },
      path: {
        type: 'string',
        description: '搜索路径 (可选，默认当前目录)'
      },
      include: {
        type: 'string',
        description: '文件匹配模式，如 "*.ets" (可选)'
      },
      output_mode: {
        type: 'string',
        enum: ['content', 'files_with_matches'],
        description: '输出模式：内容或仅文件名'
      }
    },
    required: ['pattern']
  };

  isReadOnly(): boolean {
    return true;
  }

  async execute(args: GrepInput, context: ToolContext): Promise<ToolResult> {
    const startTime = Date.now();
    const outputMode = args.output_mode || 'content';
    
    try {
      const searchPath = args.path
        ? this.resolvePath(args.path, context)
        : context.cwd;

      // 编译正则
      let regex: RegExp;
      try {
        regex = new RegExp(args.pattern, 'gi');
      } catch (e) {
        return this.errorResult(`无效的正则表达式: ${args.pattern}`);
      }

      // 文件过滤模式
      const includePattern = args.include 
        ? new RegExp(args.include.replace(/\*/g, '.*').replace(/\?/g, '.') + '$', 'i')
        : null;

      // 搜索文件
      const matches: GrepMatch[] = [];
      const matchedFiles = new Set<string>();
      
      await this.searchInDirectory(
        searchPath,
        regex,
        includePattern,
        matches,
        matchedFiles,
        context
      );

      // 格式化输出
      let output: string;
      if (outputMode === 'files_with_matches') {
        output = Array.from(matchedFiles).join('\n') || '未找到匹配的文件';
      } else {
        output = matches.length > 0
          ? matches.map(m => `${m.file}:${m.line}: ${m.content}`).join('\n')
          : '未找到匹配的内容';
      }

      const executionTime = Date.now() - startTime;

      return this.successResult(output, {
        pattern: args.pattern,
        search_path: searchPath,
        match_count: matches.length,
        file_count: matchedFiles.size,
        execution_time_ms: executionTime
      });

    } catch (error) {
      return this.errorResult(
        `搜索失败: ${error instanceof Error ? error.message : String(error)}`,
        { pattern: args.pattern }
      );
    }
  }

  private async searchInDirectory(
    dir: string,
    pattern: RegExp,
    includePattern: RegExp | null,
    matches: GrepMatch[],
    matchedFiles: Set<string>,
    context: ToolContext
  ): Promise<void> {
    try {
      const list = fs.listFile(dir);
      
      for (const item of list) {
        const fullPath = path.join(dir, item);
        const stat = fs.stat(fullPath);
        
        if (stat.isDirectory()) {
          // 递归搜索子目录
          await this.searchInDirectory(
            fullPath, pattern, includePattern, matches, matchedFiles, context
          );
        } else if (stat.isFile()) {
          // 检查文件是否匹配 include 模式
          if (includePattern && !includePattern.test(item)) {
            continue;
          }

          // 跳过太大的文件 (> 1MB)
          if (stat.size > 1024 * 1024) {
            continue;
          }

          // 搜索文件内容
          await this.searchInFile(fullPath, pattern, matches, matchedFiles);
        }
      }
    } catch (error) {
      console.error(`Error reading directory ${dir}:`, error);
    }
  }

  private async searchInFile(
    filePath: string,
    pattern: RegExp,
    matches: GrepMatch[],
    matchedFiles: Set<string>
  ): Promise<void> {
    try {
      const content = fs.readTextSync(filePath);
      const lines = content.split('\n');
      let hasMatch = false;

      lines.forEach((line, index) => {
        if (pattern.test(line)) {
          hasMatch = true;
          matches.push({
            file: filePath,
            line: index + 1,
            content: line.trim()
          });
        }
        // 重置正则 lastIndex
        pattern.lastIndex = 0;
      });

      if (hasMatch) {
        matchedFiles.add(filePath);
      }
    } catch (error) {
      // 跳过无法读取的文件
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
        description: '搜索函数定义',
        input: { pattern: 'function\\s+\\w+', include: '*.ets' }
      },
      {
        description: '查找 TODO 注释',
        input: { pattern: 'TODO|FIXME', output_mode: 'files_with_matches' }
      },
      {
        description: '搜索特定字符串',
        input: { pattern: 'QueryEngine', path: 'src' }
      }
    ];
  }
}
