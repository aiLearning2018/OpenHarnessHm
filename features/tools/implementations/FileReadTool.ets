// tools/implementations/FileReadTool.ets
// 文件读取工具

import { BaseTool, FileTool } from '../base/BaseTool';
import { ToolContext, ToolResult } from '../base/ToolContext';
import fs from '@ohos.file.fs';
import path from 'path';

// 输入参数接口
interface FileReadInput {
  path: string;
  offset?: number;
  limit?: number;
}

// 文件读取工具
export class FileReadTool extends FileTool<FileReadInput> {
  readonly name = 'file_read';
  readonly description = '读取文件内容，支持指定偏移和行数限制';
  
  readonly inputSchema = {
    type: 'object' as const,
    properties: {
      path: {
        type: 'string',
        description: '文件路径 (相对或绝对)'
      },
      offset: {
        type: 'number',
        description: '起始行号 (从1开始，可选)'
      },
      limit: {
        type: 'number',
        description: '最大读取行数 (可选)'
      }
    },
    required: ['path']
  };

  isReadOnly(): boolean {
    return true;
  }

  async execute(args: FileReadInput, context: ToolContext): Promise<ToolResult> {
    const startTime = Date.now();
    
    try {
      // 解析路径
      const fullPath = this.resolvePath(args.path, context);
      
      // 检查文件是否存在
      if (!fs.access(fullPath)) {
        return this.errorResult(`文件不存在: ${args.path}`);
      }

      // 检查是否是文件
      const stat = fs.stat(fullPath);
      if (!stat.isFile()) {
        return this.errorResult(`路径不是文件: ${args.path}`);
      }

      // 检查文件大小 (限制 1MB)
      const maxSize = 1024 * 1024;
      if (stat.size > maxSize) {
        return this.errorResult(
          `文件太大 (${(stat.size / 1024 / 1024).toFixed(2)}MB)，最大支持 1MB。` +
          `请使用 offset 和 limit 参数分段读取`
        );
      }

      // 读取文件
      let content = fs.readTextSync(fullPath);
      
      // 处理行号偏移和限制
      const lines = content.split('\n');
      const totalLines = lines.length;
      
      let startLine = (args.offset || 1) - 1;
      let endLine = args.limit ? startLine + args.limit : totalLines;
      
      // 边界检查
      startLine = Math.max(0, Math.min(startLine, totalLines));
      endLine = Math.max(startLine, Math.min(endLine, totalLines));
      
      const selectedLines = lines.slice(startLine, endLine);
      content = selectedLines.join('\n');

      // 生成行号
      const numberedLines = selectedLines.map((line, idx) => {
        const lineNum = startLine + idx + 1;
        return `${lineNum.toString().padStart(4, ' ')} | ${line}`;
      });

      const output = numberedLines.join('\n');
      const executionTime = Date.now() - startTime;

      return this.successResult(output, {
        file_path: fullPath,
        file_size: stat.size,
        total_lines: totalLines,
        displayed_lines: selectedLines.length,
        start_line: startLine + 1,
        end_line: endLine,
        execution_time_ms: executionTime
      });

    } catch (error) {
      return this.errorResult(
        `读取文件失败: ${error instanceof Error ? error.message : String(error)}`,
        { file_path: args.path }
      );
    }
  }

  protected getExamples(): ToolExample[] {
    return [
      {
        description: '读取整个文件',
        input: { path: 'src/main.ets' }
      },
      {
        description: '读取文件前 50 行',
        input: { path: 'src/main.ets', limit: 50 }
      },
      {
        description: '从第 100 行开始读取 50 行',
        input: { path: 'src/main.ets', offset: 100, limit: 50 }
      }
    ];
  }

  protected getNotes(): string[] {
    return [
      '支持相对路径 (相对于当前工作目录) 或绝对路径',
      '文件大小限制为 1MB，大文件请分段读取',
      '读取结果会显示行号，方便引用'
    ];
  }

  // 解析路径
  private resolvePath(inputPath: string, context: ToolContext): string {
    if (path.isAbsolute(inputPath)) {
      return inputPath;
    }
    return path.join(context.cwd, inputPath);
  }
}
