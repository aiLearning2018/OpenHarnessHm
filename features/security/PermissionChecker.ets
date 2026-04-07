// security/PermissionChecker.ets
// 权限检查器

// 权限模式
export enum PermissionMode {
  // 默认模式：写操作和危险操作需要确认
  DEFAULT = 'default',
  
  // 自动模式：允许所有操作 (仅在可信环境使用)
  AUTO = 'auto',
  
  // 计划模式：禁止所有写操作
  PLAN = 'plan',
  
  // 严格模式：所有操作都需要确认
  STRICT = 'strict'
}

// 权限检查请求
export interface PermissionRequest {
  toolName: string;
  toolInput: object;
  isReadOnly: boolean;
  cwd: string;
}

// 权限检查结果
export interface PermissionResult {
  granted: boolean;
  reason?: string;
  expiresAt?: number; // 临时授权过期时间
}

// 路径规则
export interface PathRule {
  pattern: string;
  allow: boolean;
  description?: string;
}

// 命令规则
export interface CommandRule {
  pattern: string;
  allow: boolean;
  description?: string;
}

// 权限配置
export interface PermissionConfig {
  mode: PermissionMode;
  pathRules: PathRule[];
  deniedCommands: string[];
  allowedPaths?: string[];
  autoApproveReadOnly: boolean;
  requireConfirmationFor: string[];
}

// 权限检查器接口
export interface IPermissionChecker {
  check(request: PermissionRequest): Promise<boolean>;
  requestUserConfirmation?(request: PermissionRequest): Promise<boolean>;
}

// 权限检查器实现
export class PermissionChecker implements IPermissionChecker {
  private config: PermissionConfig;
  private temporaryGrants: Map<string, number> = new Map();

  constructor(config?: Partial<PermissionConfig>) {
    this.config = {
      mode: PermissionMode.DEFAULT,
      pathRules: [],
      deniedCommands: [],
      autoApproveReadOnly: true,
      requireConfirmationFor: [],
      ...config
    };
  }

  // 检查权限
  async check(request: PermissionRequest): Promise<boolean> {
    const { toolName, toolInput, isReadOnly } = request;

    // 根据模式处理
    switch (this.config.mode) {
      case PermissionMode.AUTO:
        return true;
      
      case PermissionMode.PLAN:
        // 计划模式下禁止所有写操作
        if (!isReadOnly) {
          return false;
        }
        return true;
      
      case PermissionMode.STRICT:
        // 严格模式下所有操作都需要确认
        return await this.requestUserConfirmation(request);
      
      case PermissionMode.DEFAULT:
      default:
        // 默认模式
        if (isReadOnly && this.config.autoApproveReadOnly) {
          return true;
        }
        
        // 检查是否需要强制确认
        if (this.config.requireConfirmationFor.includes(toolName)) {
          return await this.requestUserConfirmation(request);
        }
        
        // 检查路径规则
        if (!this.checkPathRules(request)) {
          return false;
        }
        
        // 检查命令规则 (针对 BashTool)
        if (!this.checkCommandRules(request)) {
          return false;
        }
        
        // 其他情况需要用户确认
        return await this.requestUserConfirmation(request);
    }
  }

  // 请求用户确认
  async requestUserConfirmation(request: PermissionRequest): Promise<boolean> {
    // 检查临时授权
    const cacheKey = this.getCacheKey(request);
    const expiry = this.temporaryGrants.get(cacheKey);
    if (expiry && expiry > Date.now()) {
      return true;
    }

    // TODO: 这里应该调用 UI 层显示确认对话框
    // 暂时返回 true 用于测试
    console.info(`[PermissionChecker] Requesting confirmation for: ${request.toolName}`);
    return true;
  }

  // 授予临时权限
  grantTemporary(request: PermissionRequest, durationMs: number = 60000): void {
    const cacheKey = this.getCacheKey(request);
    this.temporaryGrants.set(cacheKey, Date.now() + durationMs);
  }

  // 检查路径规则
  private checkPathRules(request: PermissionRequest): boolean {
    // 从 toolInput 中提取路径
    const input = request.toolInput as Record<string, string>;
    const path = input['path'] || input['file_path'] || input['cwd'];
    
    if (!path) {
      return true;
    }

    // 检查每条规则
    for (const rule of this.config.pathRules) {
      if (this.matchPattern(path, rule.pattern)) {
        return rule.allow;
      }
    }

    return true;
  }

  // 检查命令规则
  private checkCommandRules(request: PermissionRequest): boolean {
    if (request.toolName !== 'BashTool') {
      return true;
    }

    const input = request.toolInput as Record<string, string>;
    const command = input['command'] || '';

    // 检查禁用的命令
    for (const deniedPattern of this.config.deniedCommands) {
      if (this.matchPattern(command, deniedPattern)) {
        return false;
      }
    }

    return true;
  }

  // 模式匹配 (支持 * 通配符)
  private matchPattern(text: string, pattern: string): boolean {
    const regex = new RegExp('^' + pattern.replace(/\*/g, '.*') + '$');
    return regex.test(text);
  }

  // 生成缓存键
  private getCacheKey(request: PermissionRequest): string {
    return `${request.toolName}-${JSON.stringify(request.toolInput)}`;
  }

  // 更新配置
  updateConfig(config: Partial<PermissionConfig>): void {
    this.config = { ...this.config, ...config };
  }

  // 获取当前模式
  getMode(): PermissionMode {
    return this.config.mode;
  }

  // 设置模式
  setMode(mode: PermissionMode): void {
    this.config.mode = mode;
  }

  // 添加路径规则
  addPathRule(rule: PathRule): void {
    this.config.pathRules.push(rule);
  }

  // 添加禁用命令
  addDeniedCommand(pattern: string): void {
    this.config.deniedCommands.push(pattern);
  }
}

// 总是允许的权限检查器 (用于测试)
export class AllowAllPermissionChecker implements IPermissionChecker {
  async check(): Promise<boolean> {
    return true;
  }
}

// 总是拒绝的权限检查器
export class DenyAllPermissionChecker implements IPermissionChecker {
  async check(): Promise<boolean> {
    return false;
  }
}
