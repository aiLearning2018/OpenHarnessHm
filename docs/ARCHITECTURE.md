# OpenHarnessHm 架构文档

## 系统架构图

```
┌─────────────────────────────────────────────────────────────────┐
│                        UI 层 (ArkUI)                             │
│  ┌─────────────┐ ┌─────────────┐ ┌─────────────┐ ┌────────────┐ │
│  │  ChatPage   │ │ ToolsPage   │ │ MemoryPage  │ │ Settings   │ │
│  └─────────────┘ └─────────────┘ └─────────────┘ └────────────┘ │
└─────────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────────┐
│                      ViewModel 层                                │
│  ┌─────────────┐ ┌─────────────┐ ┌─────────────┐ ┌────────────┐ │
│  │ ChatVM      │ │ ToolVM      │ │ MemoryVM    │ │ ConfigVM   │ │
│  └─────────────┘ └─────────────┘ └─────────────┘ └────────────┘ │
└─────────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────────┐
│                      核心引擎层                                   │
│  ┌──────────────────────────────────────────────────────────┐   │
│  │                   QueryEngine                             │   │
│  │  ┌──────────┐  ┌──────────┐  ┌──────────┐  ┌──────────┐  │   │
│  │  │  Query   │──│  Stream  │──│ ToolExec │──│  Result  │  │   │
│  │  │  Runner  │  │ Processor│  │  Engine  │  │  Handler │  │   │
│  │  └──────────┘  └──────────┘  └──────────┘  └──────────┘  │   │
│  └──────────────────────────────────────────────────────────┘   │
└─────────────────────────────────────────────────────────────────┘
                              │
              ┌───────────────┼───────────────┐
              ▼               ▼               ▼
┌─────────────────┐ ┌─────────────────┐ ┌─────────────────┐
│    工具层        │ │    API 层       │ │    存储层       │
│  ┌───────────┐  │ │  ┌───────────┐  │ │  ┌───────────┐  │
│  │ Tool      │  │ │  │ Anthropic │  │ │  │ Preference│  │
│  │ Registry  │  │ │  │ Provider  │  │ │  │  Store    │  │
│  ├───────────┤  │ │  ├───────────┤  │ │  ├───────────┤  │
│  │ FileTools │  │ │  │ OpenAI    │  │ │  │  RDB      │  │
│  │ WebTools  │  │ │  │ Provider  │  │ │  │  Store    │  │
│  │ TaskTools │  │ │  ├───────────┤  │ │  ├───────────┤  │
│  │ MCPTools  │  │ │  │ Copilot   │  │ │  │  File     │  │
│  └───────────┘  │ │  │ Provider  │  │ │  │  System   │  │
└─────────────────┘ │  └───────────┘  │ │  └───────────┘  │
                    └─────────────────┘ └─────────────────┘
                              │
              ┌───────────────┴───────────────┐
              ▼                               ▼
    ┌─────────────────┐           ┌─────────────────┐
    │    安全层        │           │    扩展层       │
    │  ┌───────────┐  │           │  ┌───────────┐  │
    │  │Permission │  │           │  │   Skill   │  │
    │  │ Checker   │  │           │  │  Loader   │  │
    │  ├───────────┤  │           │  ├───────────┤  │
    │  │  Sandbox  │  │           │  │  Plugin   │  │
    │  │ Validator │  │           │  │  Manager  │  │
    │  └───────────┘  │           │  ├───────────┤  │
    └─────────────────┘           │  │  Swarm    │  │
                                  │  │ Coordinator│ │
                                  │  └───────────┘  │
                                  └─────────────────┘
```

## 核心流程

### 1. 消息处理流程

```
用户输入
    │
    ▼
┌────────────────┐
│   ChatViewModel │
└────────────────┘
    │
    ▼
┌──────────────────────────────────────────┐
│           QueryEngine                     │
│  1. 构建消息历史                          │
│  2. 调用 LLM API (streaming)             │
│  3. 解析响应流                            │
└──────────────────────────────────────────┘
    │
    ├─── 文本增量 ───> UI 流式显示
    │
    ├─── 工具调用 ───> 权限检查
    │                       │
    │                       ▼
    │              ┌────────────────┐
    │              │ PermissionChecker
    │              │ 1. 验证权限模式  │
    │              │ 2. 路径/命令验证 │
    │              │ 3. 用户确认对话框│
    │              └────────────────┘
    │                       │
    │                       ▼ (permitted)
    │              ┌────────────────┐
    └─────────────>│ ToolRegistry   │
                   │ execute()      │
                   └────────────────┘
                          │
            ┌─────────────┼─────────────┐
            ▼             ▼             ▼
       ┌─────────┐  ┌─────────┐  ┌─────────┐
       │FileTool │  │WebTool  │  │TaskTool │
       └─────────┘  └─────────┘  └─────────┘
            │             │             │
            ▼             ▼             ▼
       工具结果 ───────────────────────────>
            │
            ▼
    添加结果到消息历史
            │
            ▼
    继续 Agent 循环 (如果有更多工具调用)
```

### 2. 工具执行流程

```
┌─────────────────────────────────────────────────────────┐
│                     Tool Execution Flow                  │
├─────────────────────────────────────────────────────────┤
│                                                          │
│  Input: tool_name, tool_args, context                   │
│                                                          │
│  1. Lookup ToolRegistry.get(tool_name)                  │
│     └─> Not found? Return error result                  │
│                                                          │
│  2. Validate input against JSON Schema                  │
│     └─> Invalid? Return validation error                │
│                                                          │
│  3. Check isReadOnly()                                  │
│     └─> Read-only? Skip permission check                │
│                                                          │
│  4. Permission Check                                    │
│     └─> Denied? Return permission error                 │
│                                                          │
│  5. Pre-Tool Hook Execution                             │
│     └─> Hook can modify args or block                   │
│                                                          │
│  6. Execute Tool                                        │
│     └─> try/catch for error handling                    │
│                                                          │
│  7. Post-Tool Hook Execution                            │
│     └─> Hook can modify result                          │
│                                                          │
│  8. Return ToolResult                                   │
│                                                          │
└─────────────────────────────────────────────────────────┘
```

## 状态管理

### 应用状态

```typescript
// AppState.ets - 全局状态管理
export class AppState {
  // 会话状态
  currentConversation: Conversation | null = null;
  conversationHistory: Conversation[] = [];
  
  // 配置状态
  activeProvider: ProviderConfig;
  permissionMode: PermissionMode = PermissionMode.DEFAULT;
  
  // 运行时状态
  isProcessing: boolean = false;
  currentToolExecutions: Map<string, ToolExecution> = new Map();
  
  // 后台任务
  backgroundTasks: BackgroundTask[] = [];
  
  // 记忆
  persistentMemory: MemoryStore;
}
```

### 对话状态流转

```
┌──────────┐    submit     ┌──────────┐
│  IDLE    │──────────────>│ PENDING  │
└──────────┘               └──────────┘
                               │
              ┌────────────────┼────────────────┐
              │                │                │
              ▼                ▼                ▼
         ┌─────────┐     ┌─────────┐     ┌─────────┐
         │STREAMING│     │TOOL_USE │     │  ERROR  │
         │  TEXT   │     │         │     │         │
         └─────────┘     └────┬────┘     └─────────┘
              │               │
              │          ┌────┴────┐
              │          │         │
              │          ▼         ▼
              │    ┌─────────┐ ┌──────────┐
              │    │CHECKING │ │EXECUTING │
              │    │  PERM   │ │  TOOL    │
              │    └────┬────┘ └────┬─────┘
              │         └───────────┘
              │                │
              │                ▼
              │           ┌─────────┐
              │           │COMPLETED│
              │           └────┬────┘
              │                │
              └────────────────┘
                               │
                               ▼
                          ┌─────────┐
                          │  DONE   │
                          └─────────┘
```

## 模块依赖关系

```
core/
  ├── 依赖: api/, tools/, storage/, security/
  ├── 被依赖: ui/viewmodels/

tools/
  ├── 依赖: storage/, security/
  ├── 被依赖: core/

api/
  ├── 依赖: storage/ (for auth tokens)
  ├── 被依赖: core/

storage/
  ├── 依赖: 无 (底层)
  ├── 被依赖: core/, tools/, api/, security/

security/
  ├── 依赖: storage/ (for settings)
  ├── 被依赖: core/, tools/

ui/
  ├── 依赖: core/, storage/
  ├── 被依赖: entry/
```

## 关键设计决策

### 1. 响应式架构
- 使用 ArkUI 的 `@State` 和 `@Observed` 进行状态绑定
- ViewModel 层使用 `@ObservedV2` 管理复杂状态
- 引擎层使用 EventEmitter 模式处理异步流

### 2. 错误处理
- 工具执行错误包装为 ToolResult (isError: true)
- API 错误分类：网络/认证/限流/内容过滤
- UI 层统一错误提示和恢复机制

### 3. 性能优化
- 大消息列表使用 List + 虚拟滚动
- 流式响应使用增量更新
- 工具执行使用异步并行
- 图片/文件懒加载

### 4. 安全设计
- 所有文件操作限制在应用沙箱
- 外部路径需要用户明确授权
- 命令执行使用白名单机制
- 敏感数据加密存储
