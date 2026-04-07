// tools/base/ToolContext.ets
// 工具执行上下文和结果

// 工具执行上下文
export interface ToolContext {
  // 当前工作目录 (应用沙箱路径)
  cwd: string;
  
  // 元数据 (传递额外信息)
  metadata: Record<string, object>;
  
  // 获取应用文件路径
  getAppFilePath(relativePath: string): string;
  
  // 获取临时目录路径
  getTempDir(): string;
  
  // 获取缓存目录路径
  getCacheDir(): string;
  
  // 发送进度更新 (用于长时间运行的工具)
  reportProgress?(progress: number, message?: string): void;
}

// 工具执行结果
export interface ToolResult {
  // 输出内容 (文本)
  output: string;
  
  // 是否是错误
  isError?: boolean;
  
  // 元数据
  metadata?: {
    tool_name?: string;
    execution_time_ms?: number;
    [key: string]: object | string | number | boolean | undefined;
  };
}

// 工具执行状态
export enum ToolExecutionStatus {
  PENDING = 'pending',
  RUNNING = 'running',
  COMPLETED = 'completed',
  ERROR = 'error',
  CANCELLED = 'cancelled'
}

// 工具执行记录
export class ToolExecution {
  id: string;
  tool_name: string;
  input: object;
  status: ToolExecutionStatus;
  start_time: number;
  end_time?: number;
  result?: ToolResult;
  progress?: number;
  progress_message?: string;

  constructor(tool_name: string, input: object) {
    this.id = `exec-${Date.now()}-${Math.random().toString(36).substr(2, 9)}`;
    this.tool_name = tool_name;
    this.input = input;
    this.status = ToolExecutionStatus.PENDING;
    this.start_time = Date.now();
  }

  start(): void {
    this.status = ToolExecutionStatus.RUNNING;
    this.start_time = Date.now();
  }

  complete(result: ToolResult): void {
    this.status = result.isError ? ToolExecutionStatus.ERROR : ToolExecutionStatus.COMPLETED;
    this.result = result;
    this.end_time = Date.now();
    this.progress = 100;
  }

  cancel(): void {
    this.status = ToolExecutionStatus.CANCELLED;
    this.end_time = Date.now();
  }

  updateProgress(progress: number, message?: string): void {
    this.progress = progress;
    if (message) {
      this.progress_message = message;
    }
  }

  getExecutionTime(): number {
    const end = this.end_time || Date.now();
    return end - this.start_time;
  }
}

// 工具上下文实现
export class ToolContextImpl implements ToolContext {
  cwd: string;
  metadata: Record<string, object> = {};
  private appContext: Context;

  constructor(appContext: Context, cwd?: string) {
    this.appContext = appContext;
    this.cwd = cwd || appContext.filesDir;
  }

  getAppFilePath(relativePath: string): string {
    return `${this.appContext.filesDir}/${relativePath}`;
  }

  getTempDir(): string {
    return this.appContext.tempDir;
  }

  getCacheDir(): string {
    return this.appContext.cacheDir;
  }

  reportProgress?(progress: number, message?: string): void {
    // 默认实现，可通过构造函数注入
  }
}

// 引入 Context 类型
import { Context } from '@kit.AbilityKit';
