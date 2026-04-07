// tools/implementations/FileWriteTool.ets
// 文件写入工具

import { BaseTool, FileTool } from '../base/BaseTool';
import { ToolContext, ToolResult } from '../base/ToolContext';
import fs from '@ohos.file.fs';
import path from 'path';

interface FileWriteInput {
  path: string;
  content: string;
  append?: boolean;
}

export class FileWriteTool extends FileTool<FileWriteInput> {
  readonly name = 'file_write';
  readonly description = '写入或追加文件内容';
  
  readonly inputSchema = {
    type: 'object' as const,
    properties: {
      path: {
        type: 'string',
        description: '文件路径'
      },
      content: {
        type: 'string',
        description: '要写入的内容'
      },
      append: {
        type: 'boolean',
        description: '是否追加模式 (默认 false)'
      }
    },
    required: ['path', 'content']
  };

  isReadOnly(): boolean {
    return false;
  }

  requiresConfirmation(): boolean {
    return true;
  }

  async execute(args: FileWriteInput, context: ToolContext): Promise<ToolResult> {
    const startTime = Date.now();
    
    try {
      const fullPath = this.resolvePath(args.path, context);
      
      // 确保目录存在
      const dir = path.dirname(fullPath);
      if (!fs.access(dir)) {
        fs.mkdir(dir, true);
      }

      // 检查文件是否已存在
      const exists = fs.access(fullPath);
      
      // 写入文件
      if (args.append) {
        fs.access(fullPath) 
          ? fs.writeSync(fullPath, args.content, { append: true })
          : fs.writeTextSync(fullPath, args.content);
      } else {
        fs.writeTextSync(fullPath, args.content);
      }

      const executionTime = Date.now() - startTime;
      const stat = fs.stat(fullPath);

      return this.successResult(
        `${exists ? '更新' : '创建'}文件成功: ${args.path}`,
        {
          file_path: fullPath,
          file_size: stat.size,
          existed: exists,
          append_mode: args.append || false,
          execution_time_ms: executionTime
        }
      );

    } catch (error) {
      return this.errorResult(
        `写入文件失败: ${error instanceof Error ? error.message : String(error)}`,
        { file_path: args.path }
      );
    }
  }

  private resolvePath(inputPath: string, context: ToolContext): string {
    if (path.isAbsolute(inputPath)) {
      return inputPath;
    }
    return path.join(context.cwd, inputPath);
  }
}
