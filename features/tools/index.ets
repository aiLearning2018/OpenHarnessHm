// tools/index.ets
// 工具模块导出

// 基础类
export { BaseTool, FileTool, WebTool, SystemTool, ToolInfo, ToolExample } from './base/BaseTool';
export { ToolContext, ToolResult, ToolExecution, ToolExecutionStatus } from './base/ToolContext';
export { ToolRegistry, getGlobalToolRegistry, setGlobalToolRegistry } from './base/ToolRegistry';

// 工具实现
export { FileReadTool } from './implementations/FileReadTool';
export { FileWriteTool } from './implementations/FileWriteTool';
export { GlobTool } from './implementations/GlobTool';
export { GrepTool } from './implementations/GrepTool';
export { WebSearchTool } from './implementations/WebSearchTool';
export { 
  TaskCreateTool, 
  TaskListTool, 
  TaskGetTool, 
  TaskStopTool 
} from './implementations/TaskCreateTool';

// 创建标准工具注册表的函数
export function createStandardToolRegistry(): ToolRegistry {
  const registry = new ToolRegistry();
  
  // 注册文件工具
  registry.register(new FileReadTool());
  registry.register(new FileWriteTool());
  registry.register(new GlobTool());
  registry.register(new GrepTool());
  
  // 注册 Web 工具
  registry.register(new WebSearchTool());
  
  // 注册任务工具
  registry.register(new TaskCreateTool());
  registry.register(new TaskListTool());
  registry.register(new TaskGetTool());
  registry.register(new TaskStopTool());
  
  return registry;
}
