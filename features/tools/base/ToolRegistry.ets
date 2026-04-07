// tools/base/ToolRegistry.ets
// 工具注册表 - 管理所有可用工具

import { BaseTool } from './BaseTool';
import { ToolContext, ToolResult } from './ToolContext';

export class ToolRegistry {
  // 工具存储 Map
  private tools: Map<string, BaseTool> = new Map();
  
  // 工具别名 Map
  private aliases: Map<string, string> = new Map();

  // 注册工具
  register(tool: BaseTool): void {
    if (this.tools.has(tool.name)) {
      console.warn(`[ToolRegistry] Tool '${tool.name}' is already registered, overwriting`);
    }
    this.tools.set(tool.name, tool);
  }

  // 注册别名
  registerAlias(alias: string, targetToolName: string): void {
    if (!this.tools.has(targetToolName)) {
      throw new Error(`Cannot register alias '${alias}' for non-existent tool '${targetToolName}'`);
    }
    this.aliases.set(alias, targetToolName);
  }

  // 获取工具
  get(name: string): BaseTool | undefined {
    // 先检查是否是别名
    const aliasedName = this.aliases.get(name);
    if (aliasedName) {
      return this.tools.get(aliasedName);
    }
    return this.tools.get(name);
  }

  // 检查工具是否存在
  has(name: string): boolean {
    return this.tools.has(name) || this.aliases.has(name);
  }

  // 列出所有工具
  list(): BaseTool[] {
    return Array.from(this.tools.values());
  }

  // 列出工具名称
  listNames(): string[] {
    return Array.from(this.tools.keys());
  }

  // 获取 API Schema 列表
  toApiSchema(): object[] {
    return this.list().map(tool => tool.toApiSchema());
  }

  // 执行工具
  async execute(
    name: string,
    args: object,
    context: ToolContext
  ): Promise<ToolResult> {
    const tool = this.get(name);
    
    if (!tool) {
      return {
        output: `错误: 未找到工具 '${name}'`,
        isError: true,
        metadata: { attempted_tool: name }
      };
    }

    // 验证输入
    if (!tool.validateInput(args)) {
      return {
        output: `错误: 工具 '${name}' 的参数格式不正确`,
        isError: true,
        metadata: { 
          tool_name: name,
          provided_args: args,
          expected_schema: tool.inputSchema
        }
      };
    }

    try {
      // 执行工具
      const result = await tool.execute(args, context);
      return {
        ...result,
        metadata: {
          ...result.metadata,
          tool_name: name,
          execution_successful: !result.isError
        }
      };
    } catch (error) {
      return {
        output: `工具执行错误: ${error instanceof Error ? error.message : String(error)}`,
        isError: true,
        metadata: {
          tool_name: name,
          error_type: error instanceof Error ? error.name : 'Unknown',
          stack: error instanceof Error ? error.stack : undefined
        }
      };
    }
  }

  // 搜索工具
  search(query: string): BaseTool[] {
    const lowerQuery = query.toLowerCase();
    return this.list().filter(tool => 
      tool.name.toLowerCase().includes(lowerQuery) ||
      tool.description.toLowerCase().includes(lowerQuery)
    );
  }

  // 按类别获取工具
  getByCategory(category: string): BaseTool[] {
    return this.list().filter(tool => {
      const cat = (tool as unknown as Record<string, string>)['category'];
      return cat === category;
    });
  }

  // 移除工具
  unregister(name: string): boolean {
    return this.tools.delete(name);
  }

  // 清空所有工具
  clear(): void {
    this.tools.clear();
    this.aliases.clear();
  }

  // 获取工具数量
  size(): number {
    return this.tools.size;
  }

  // 创建标准工具注册表 (预注册所有标准工具)
  static createStandard(): ToolRegistry {
    const registry = new ToolRegistry();
    // 标准工具将在单独的文件中注册
    return registry;
  }
}

// 全局注册表实例 (单例)
let globalRegistry: ToolRegistry | null = null;

export function getGlobalToolRegistry(): ToolRegistry {
  if (!globalRegistry) {
    globalRegistry = ToolRegistry.createStandard();
  }
  return globalRegistry;
}

export function setGlobalToolRegistry(registry: ToolRegistry): void {
  globalRegistry = registry;
}
