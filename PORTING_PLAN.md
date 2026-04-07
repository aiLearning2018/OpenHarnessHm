# OpenHarnessHm - HarmonyOS 原生移植方案

## 项目概述

将 OpenHarness（Python 实现的 AI Agent 基础设施）原生移植到 HarmonyOS 平台，使用 ArkTS/ArkUI 构建原生应用，保留核心架构设计理念，适配移动端/鸿蒙生态特性。

---

## 一、架构映射对比

### 1.1 核心架构对照表

| OpenHarness (Python) | OpenHarnessHm (HarmonyOS) | 说明 |
|---------------------|---------------------------|------|
| `engine/query_engine.py` | `core/QueryEngine.ets` | Agent 循环核心引擎 |
| `engine/query.py` | `core/QueryRunner.ets` | 查询执行器 |
| `engine/messages.py` | `core/model/Message.ets` | 消息模型 |
| `engine/stream_events.py` | `core/model/StreamEvent.ets` | 流事件模型 |
| `tools/base.py` | `tools/BaseTool.ets` | 工具基类 |
| `tools/*.py` (43 tools) | `tools/implementations/*.ets` | 工具实现 |
| `api/client.py` | `api/LLMClient.ets` | LLM API 客户端 |
| `api/provider.py` | `api/ProviderManager.ets` | 提供商管理 |
| `permissions/checker.py` | `security/PermissionChecker.ets` | 权限检查 |
| `memory/` | `storage/MemoryManager.ets` | 持久化内存 |
| `skills/` | `knowledge/SkillLoader.ets` | 技能加载 |
| `ui/` (React TUI) | `ui/` (ArkUI) | 用户界面 |
| `tasks/` | `background/TaskManager.ets` | 后台任务 |
| `coordinator/` | `swarm/AgentCoordinator.ets` | 多 Agent 协调 |

### 1.2 技术栈替换

| 原技术 | HarmonyOS 替代方案 |
|--------|-------------------|
| Python 3.10+ | ArkTS (TypeScript 超集) |
| Pydantic | ArkTS 装饰器 + 类型系统 |
| AsyncIO | Promise + async/await |
| Rich/Prompt-Toolkit | ArkUI 组件 |
| React Ink | ArkUI 声明式 UI |
| HTTPX | @ohos.net.http |
| WebSockets | @ohos.net.websocket |
| File I/O | @ohos.file.fs |
| SQLite | @ohos.data.relationalStore |
| LocalStorage | @ohos.data.preferences |
| Crypto | @ohos.security.cryptoFramework |
| Background Tasks | @ohos.resourceschedule.backgroundTaskManager |

---

## 二、模块详细设计

### 2.1 核心引擎层 (core/)

```
core/
├── engine/
│   ├── QueryEngine.ets          # 主引擎
│   ├── QueryRunner.ets          # 查询执行
│   ├── StreamProcessor.ets      # 流处理
│   └── CostTracker.ets          # Token/成本追踪
├── model/
│   ├── Message.ets              # 消息模型
│   ├── Conversation.ets         # 对话管理
│   ├── ToolCall.ets             # 工具调用
│   ├── ToolResult.ets           # 工具结果
│   └── StreamEvent.ets          # 流事件
├── types/
│   └── Index.ets                # 类型定义
└── utils/
    ├── EventEmitter.ets         # 事件发射器
    └── Logger.ets               # 日志工具
```

### 2.2 工具层 (tools/)

```
tools/
├── base/
│   ├── BaseTool.ets             # 工具基类
│   ├── ToolRegistry.ets         # 工具注册表
│   └── ToolContext.ets          # 工具上下文
├── implementations/             # 工具实现
│   ├── FileReadTool.ets
│   ├── FileWriteTool.ets
│   ├── FileEditTool.ets
│   ├── BashTool.ets
│   ├── GlobTool.ets
│   ├── GrepTool.ets
│   ├── WebSearchTool.ets
│   ├── WebFetchTool.ets
│   ├── SkillTool.ets
│   ├── TaskCreateTool.ets
│   ├── TaskListTool.ets
│   ├── TaskGetTool.ets
│   ├── TaskStopTool.ets
│   ├── AskUserTool.ets
│   ├── McpTool.ets
│   └── ... (其他工具)
└── index.ets                    # 导出
```

**移动端工具适配说明：**

| 原工具 | 移动端适配 |
|--------|-----------|
| BashTool | 受限 Shell 执行 + 沙箱化 |
| File I/O | 应用沙箱目录 + 用户授权访问 |
| WebSearch | 内置搜索引擎 API |
| MCP | 通过 HTTP/WebSocket 连接 |

### 2.3 API 层 (api/)

```
api/
├── base/
│   └── LLMClient.ets            # 客户端基类
├── providers/
│   ├── AnthropicProvider.ets    # Anthropic API
│   ├── OpenAIProvider.ets       # OpenAI API
│   ├── CopilotProvider.ets      # GitHub Copilot
│   ├── CodexProvider.ets        # Codex CLI
│   └── CustomProvider.ets       # 自定义兼容端点
├── auth/
│   ├── AuthManager.ets          # 认证管理
│   ├── OAuthHandler.ets         # OAuth 流程
│   └── TokenStorage.ets         # Token 存储
└── index.ets
```

### 2.4 存储层 (storage/)

```
storage/
├── MemoryManager.ets            # 内存管理
├── ConversationStore.ets        # 对话持久化
├── SkillStore.ets               # 技能缓存
├── ConfigStore.ets              # 配置存储
└── KVStorage.ets                # 键值存储封装
```

### 2.5 UI 层 (ui/)

```
ui/
├── pages/
│   ├── Index.ets                # 主页面
│   ├── ChatPage.ets             # 聊天页面
│   ├── SettingsPage.ets         # 设置页面
│   ├── ToolsPage.ets            # 工具管理
│   ├── MemoryPage.ets           # 记忆管理
│   └── TasksPage.ets            # 任务管理
├── components/
│   ├── ChatBubble.ets           # 聊天气泡
│   ├── ToolCallCard.ets         # 工具调用卡片
│   ├── PermissionDialog.ets     # 权限对话框
│   ├── SkillSelector.ets        # 技能选择器
│   ├── ModelSelector.ets        # 模型选择器
│   ├── StreamingText.ets        # 流式文本
│   └── CodeBlock.ets            # 代码块
├── viewmodels/
│   ├── ChatViewModel.ets        # 聊天 VM
│   └── SettingsViewModel.ets    # 设置 VM
└── theme/
    ├── Colors.ets               # 颜色主题
    └── Styles.ets               # 样式
```

### 2.6 安全层 (security/)

```
security/
├── PermissionChecker.ets        # 权限检查器
├── PermissionMode.ets           # 权限模式枚举
├── PathValidator.ets            # 路径验证
├── CommandValidator.ets         # 命令验证
└── Sandbox.ets                  # 沙箱管理
```

### 2.7 多 Agent 协调层 (swarm/)

```
swarm/
├── AgentCoordinator.ets         # 协调器
├── SubAgent.ets                 # 子 Agent
├── TeamRegistry.ets             # 团队注册表
├── TaskDelegator.ets            # 任务委派
└── MessageBus.ets               # 消息总线
```

### 2.8 后台任务层 (background/)

```
background/
├── TaskManager.ets              # 任务管理器
├── TaskWorker.ets               # 任务执行器
├── BackgroundRunner.ets         # 后台运行器
└── NotificationHelper.ets       # 通知辅助
```

---

## 三、核心数据结构

### 3.1 消息结构 (ArkTS)

```typescript
// core/model/Message.ets
export class ConversationMessage {
  id: string;
  role: 'user' | 'assistant' | 'system';
  content: ContentBlock[];
  timestamp: number;
  metadata?: Record<string, any>;
  
  // 工具相关
  toolUses?: ToolUseBlock[];
  toolResults?: ToolResultBlock[];
}

export type ContentBlock = 
  | TextBlock 
  | ImageBlock 
  | ToolUseBlock 
  | ToolResultBlock;

export interface TextBlock {
  type: 'text';
  text: string;
}

export interface ToolUseBlock {
  type: 'tool_use';
  id: string;
  name: string;
  input: object;
}

export interface ToolResultBlock {
  type: 'tool_result';
  tool_use_id: string;
  content: string;
  is_error?: boolean;
}
```

### 3.2 工具定义

```typescript
// tools/base/BaseTool.ets
export abstract class BaseTool<TInput extends object = object> {
  abstract readonly name: string;
  abstract readonly description: string;
  abstract readonly inputSchema: object;
  
  abstract execute(args: TInput, context: ToolContext): Promise<ToolResult>;
  
  isReadOnly(args: TInput): boolean {
    return false;
  }
  
  toAPISchema(): object {
    return {
      name: this.name,
      description: this.description,
      input_schema: this.inputSchema
    };
  }
}

export interface ToolResult {
  output: string;
  isError?: boolean;
  metadata?: Record<string, any>;
}

export interface ToolContext {
  cwd: string;
  metadata: Record<string, any>;
}
```

### 3.3 流事件

```typescript
// core/model/StreamEvent.ets
export type StreamEvent =
  | TextDeltaEvent
  | ToolUseStartEvent
  | ToolUseDeltaEvent
  | ToolUseEndEvent
  | ToolResultEvent
  | PermissionRequestEvent
  | ErrorEvent
  | DoneEvent;

export interface TextDeltaEvent {
  type: 'text_delta';
  delta: string;
}

export interface ToolUseStartEvent {
  type: 'tool_use_start';
  tool_use_id: string;
  name: string;
}

export interface ToolResultEvent {
  type: 'tool_result';
  tool_use_id: string;
  result: ToolResult;
}

// ... 其他事件类型
```

---

## 四、关键实现要点

### 4.1 Agent 循环实现

```typescript
// core/engine/QueryEngine.ets
export class QueryEngine {
  private messages: ConversationMessage[] = [];
  private costTracker: CostTracker;
  
  async submitMessage(prompt: string): AsyncIterable<StreamEvent> {
    // 1. 添加用户消息
    this.messages.push(ConversationMessage.fromUserText(prompt));
    
    // 2. 执行查询循环
    yield* this.runQueryLoop();
  }
  
  private async *runQueryLoop(): AsyncIterable<StreamEvent> {
    let turns = 0;
    
    while (turns < this.maxTurns) {
      turns++;
      
      // 调用 LLM API
      const stream = await this.apiClient.streamMessages({
        messages: this.messages,
        tools: this.toolRegistry.toAPISchema(),
        system: this.systemPrompt,
        model: this.model
      });
      
      let currentToolUse: ToolUseBlock | null = null;
      
      for await (const event of stream) {
        switch (event.type) {
          case 'text_delta':
            yield event;
            break;
            
          case 'tool_use_start':
            currentToolUse = event;
            yield event;
            break;
            
          case 'tool_use_end':
            if (currentToolUse) {
              // 权限检查
              const permitted = await this.checkPermission(currentToolUse);
              if (!permitted) {
                yield { type: 'permission_denied', tool_use_id: currentToolUse.id };
                continue;
              }
              
              // 执行工具
              const result = await this.executeTool(currentToolUse);
              yield { type: 'tool_result', tool_use_id: currentToolUse.id, result };
              
              // 添加结果到消息历史
              this.addToolResult(currentToolUse.id, result);
            }
            break;
            
          case 'done':
            return;
        }
      }
    }
  }
}
```

### 4.2 工具注册与执行

```typescript
// tools/base/ToolRegistry.ets
export class ToolRegistry {
  private tools: Map<string, BaseTool> = new Map();
  
  register(tool: BaseTool): void {
    this.tools.set(tool.name, tool);
  }
  
  get(name: string): BaseTool | undefined {
    return this.tools.get(name);
  }
  
  list(): BaseTool[] {
    return Array.from(this.tools.values());
  }
  
  toAPISchema(): object[] {
    return this.list().map(t => t.toAPISchema());
  }
  
  async execute(
    name: string, 
    args: object, 
    context: ToolContext
  ): Promise<ToolResult> {
    const tool = this.get(name);
    if (!tool) {
      return { output: `Tool ${name} not found`, isError: true };
    }
    
    try {
      // 参数验证
      const validatedArgs = this.validateArgs(tool, args);
      return await tool.execute(validatedArgs, context);
    } catch (error) {
      return { 
        output: `Error executing ${name}: ${error.message}`, 
        isError: true 
      };
    }
  }
}
```

### 4.3 LLM 客户端抽象

```typescript
// api/base/LLMClient.ets
export interface LLMClient {
  streamMessages(params: StreamParams): AsyncIterable<StreamEvent>;
  countTokens(text: string): number;
}

export interface StreamParams {
  messages: ConversationMessage[];
  tools?: object[];
  system?: string;
  model: string;
  maxTokens?: number;
}

// api/providers/AnthropicProvider.ets
export class AnthropicProvider implements LLMClient {
  private baseUrl: string;
  private apiKey: string;
  private httpClient: HttpClient;
  
  async *streamMessages(params: StreamParams): AsyncIterable<StreamEvent> {
    const response = await this.httpClient.request({
      url: `${this.baseUrl}/v1/messages`,
      method: http.RequestMethod.POST,
      header: { 'Authorization': `Bearer ${this.apiKey}` },
      extraData: JSON.stringify(this.buildRequestBody(params))
    });
    
    // 处理 SSE 流
    yield* this.parseSSEStream(response);
  }
}
```

---

## 五、项目结构

```
OpenHarnessHm/
├── entry/                       # 主入口模块
│   └── src/main/ets/
│       ├── entryability/
│       │   └── EntryAbility.ets
│       └── pages/
│           └── Index.ets
├── features/                    # 特性模块
│   ├── core/                    # 核心引擎
│   ├── tools/                   # 工具实现
│   ├── api/                     # LLM API
│   ├── storage/                 # 存储
│   ├── security/                # 安全/权限
│   ├── swarm/                   # 多 Agent
│   └── background/              # 后台任务
├── commons/                     # 公共组件
│   ├── utils/
│   ├── constants/
│   └── components/
├── resources/                   # 资源文件
│   ├── skills/                  # 技能 Markdown
│   └── prompts/                 # 系统提示词
├── docs/                        # 文档
│   ├── ARCHITECTURE.md
│   ├── API_REFERENCE.md
│   └── TOOLS_GUIDE.md
├── oh-package.json5             # 鸿蒙包配置
├── build-profile.json5          # 构建配置
└── module.json5                 # 模块配置
```

---

## 六、开发路线图

### 阶段 1: 基础架构 (2-3 周)
- [x] 项目初始化和架构设计
- [ ] 核心数据模型 (Message, Tool, Event)
- [ ] 基础工具框架
- [ ] 简单 LLM 客户端
- [ ] 基础 UI 框架

### 阶段 2: 核心功能 (3-4 周)
- [ ] Agent 循环引擎
- [ ] 工具注册表与执行
- [ ] 文件 I/O 工具 (适配沙箱)
- [ ] Web 搜索/获取工具
- [ ] 权限检查系统
- [ ] 对话历史管理

### 阶段 3: 高级功能 (2-3 周)
- [ ] 多提供商支持
- [ ] 技能系统
- [ ] MCP 协议支持
- [ ] 内存/上下文管理
- [ ] 流式 UI 渲染

### 阶段 4: 多 Agent 与扩展 (2-3 周)
- [ ] 子 Agent 委派
- [ ] 后台任务管理
- [ ] 团队协调
- [ ] 插件系统

### 阶段 5: 优化与发布 (2 周)
- [ ] 性能优化
- [ ] 测试覆盖
- [ ] 文档完善
- [ ] 应用商店上架准备

---

## 七、鸿蒙特定适配

### 7.1 权限适配

```typescript
// 文件访问权限申请
import { abilityAccessCtrl } from '@kit.AbilityKit';

async function requestFilePermissions(): Promise<boolean> {
  const atManager = abilityAccessCtrl.createAtManager();
  const result = await atManager.requestPermissionsFromUser(
    getContext(),
    ['ohos.permission.READ_MEDIA', 'ohos.permission.WRITE_MEDIA']
  );
  return result.authResults.every(r => r === 0);
}
```

### 7.2 后台任务

```typescript
import { backgroundTaskManager } from '@kit.BackgroundTasksKit';

// 注册长时任务
function startBackgroundTask(taskName: string): void {
  const wantAgentInfo: wantAgent.WantAgentInfo = {
    wants: [{ bundleName: 'com.openharness.hm', abilityName: 'EntryAbility' }],
    operationType: wantAgent.OperationType.START_ABILITY,
    requestCode: 0
  };
  
  backgroundTaskManager.startBackgroundRunning(
    getContext(),
    backgroundTaskManager.BackgroundMode.DATA_TRANSFER,
    wantAgent
  );
}
```

### 7.3 数据存储

```typescript
import { relationalStore } from '@kit.ArkData';

// 创建数据库
const config: relationalStore.StoreConfig = {
  name: 'openharness.db',
  securityLevel: relationalStore.SecurityLevel.S1
};

const store = await relationalStore.getRdbStore(getContext(), config);
```

---

## 八、与 OpenHarness 的兼容性

### 8.1 保持兼容的部分
- 技能 Markdown 格式
- 工具 JSON Schema
- 对话历史格式
- 配置文件结构

### 8.2 需要调整的部分
- 文件路径格式 (Unix vs HarmonyOS 沙箱)
- 工具权限模型
- 后台任务机制
- UI 交互方式

---

## 九、参考资源

- [HarmonyOS 开发者文档](https://developer.harmonyos.com/)
- [ArkTS 语言指南](https://developer.harmonyos.com/cn/docs/documentation/doc-guides/arkts-overview-000000163价值)
- [OpenHarness 原始项目](https://github.com/HKUDS/OpenHarness)
- [Anthropic API 文档](https://docs.anthropic.com/)
- [MCP 协议规范](https://modelcontextprotocol.io/)

---

## 十、贡献指南

欢迎贡献代码！请遵循以下规范：

1. 代码风格遵循 ArkTS 规范
2. 所有工具必须实现 BaseTool 接口
3. UI 组件使用 ArkUI 声明式语法
4. 添加单元测试和集成测试
5. 更新相关文档

---

**Oh my Harness on HarmonyOS!**
