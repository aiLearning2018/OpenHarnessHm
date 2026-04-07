# OpenHarnessHm 项目结构

## 完整目录树

```
OpenHarnessHm/
├── README.md                          # 项目说明
├── PORTING_PLAN.md                    # 移植方案规划
├── ARCHITECTURE.md                    # 架构文档
├── PROJECT_STRUCTURE.md               # 本文档
├── oh-package.json5                   # 鸿蒙包配置
├── build-profile.json5                # 构建配置
├── module.json5                       # 模块配置
│
├── entry/                             # 应用入口模块
│   ├── oh-package.json5               # Entry 模块配置
│   └── src/main/
│       ├── ets/
│       │   ├── entryability/
│       │   │   └── EntryAbility.ets   # 入口 Ability
│       │   └── pages/
│       │       └── Index.ets          # 主页面 (聊天界面)
│       └── resources/
│           ├── base/                  # 默认资源
│           │   ├── element/
│           │   │   └── string.json    # 字符串资源
│           │   └── profile/
│           │       └── main_pages.json # 页面配置
│           ├── zh_CN/                 # 中文资源
│           │   └── element/string.json
│           └── en_US/                 # 英文资源
│               └── element/string.json
│
├── features/                          # 特性模块
│   │
│   ├── core/                          # 核心引擎模块
│   │   ├── index.ets                  # 模块导出
│   │   ├── model/                     # 数据模型
│   │   │   ├── Message.ets            # 消息模型
│   │   │   └── StreamEvent.ets        # 流事件模型
│   │   ├── engine/                    # 引擎实现
│   │   │   ├── QueryEngine.ets        # 查询引擎
│   │   │   └── (其他引擎组件)
│   │   ├── types/                     # 类型定义
│   │   └── utils/                     # 工具函数
│   │
│   ├── tools/                         # 工具系统模块
│   │   ├── index.ets                  # 模块导出
│   │   ├── base/                      # 工具基类
│   │   │   ├── BaseTool.ets           # 工具基类
│   │   │   ├── ToolContext.ets        # 工具上下文
│   │   │   └── ToolRegistry.ets       # 工具注册表
│   │   └── implementations/           # 工具实现
│   │       ├── FileReadTool.ets       # 文件读取
│   │       ├── FileWriteTool.ets      # 文件写入
│   │       ├── GlobTool.ets           # 文件匹配
│   │       ├── GrepTool.ets           # 文本搜索
│   │       ├── WebSearchTool.ets      # 网页搜索
│   │       └── TaskCreateTool.ets     # 任务管理
│   │
│   ├── api/                           # API 客户端模块
│   │   ├── index.ets                  # 模块导出
│   │   ├── base/                      # 客户端基类
│   │   │   └── LLMClient.ets          # LLM 客户端接口
│   │   ├── providers/                 # 提供商实现
│   │   │   └── AnthropicProvider.ets  # Anthropic API
│   │   └── auth/                      # 认证管理
│   │
│   ├── storage/                       # 数据存储模块
│   │   ├── index.ets                  # 模块导出
│   │   ├── ConversationStore.ets      # 对话存储
│   │   └── (其他存储组件)
│   │
│   ├── security/                      # 安全权限模块
│   │   ├── index.ets                  # 模块导出
│   │   └── PermissionChecker.ets      # 权限检查器
│   │
│   ├── swarm/                         # 多 Agent 协调模块
│   │   └── (多 Agent 实现)
│   │
│   └── background/                    # 后台任务模块
│       └── (后台任务实现)
│
├── commons/                           # 公共组件
│   ├── utils/                         # 通用工具
│   ├── constants/                     # 常量定义
│   └── components/                    # 共享 UI 组件
│
├── resources/                         # 资源文件
│   ├── skills/                        # 技能 Markdown
│   └── prompts/                       # 系统提示词
│
└── docs/                              # 项目文档
    ├── ARCHITECTURE.md                # 架构设计
    ├── API_REFERENCE.md               # API 参考
    └── TOOLS_GUIDE.md                 # 工具指南
```

## 核心模块说明

### 1. Core 模块 (features/core/)

**职责**: Agent 循环引擎核心

| 文件 | 说明 |
|-----|------|
| `model/Message.ets` | 对话消息模型，支持文本/图片/工具调用/工具结果 |
| `model/StreamEvent.ets` | 流事件定义，支持增量更新 |
| `engine/QueryEngine.ets` | 核心查询引擎，实现 Agent 循环 |

### 2. Tools 模块 (features/tools/)

**职责**: 工具系统实现

| 文件 | 说明 |
|-----|------|
| `base/BaseTool.ets` | 工具抽象基类 |
| `base/ToolRegistry.ets` | 工具注册表，管理所有工具 |
| `implementations/*.ets` | 具体工具实现 |

**已实现工具**:
- `FileReadTool` - 文件读取 (只读)
- `FileWriteTool` - 文件写入/创建
- `GlobTool` - 文件模式匹配
- `GrepTool` - 文本搜索
- `WebSearchTool` - 网页搜索
- `TaskCreateTool` - 创建后台任务
- `TaskListTool` - 列出任务
- `TaskGetTool` - 获取任务详情
- `TaskStopTool` - 停止任务

### 3. API 模块 (features/api/)

**职责**: LLM API 客户端

| 文件 | 说明 |
|-----|------|
| `base/LLMClient.ets` | LLM 客户端接口 |
| `providers/AnthropicProvider.ets` | Anthropic API 实现 |

**支持的 Provider**:
- Anthropic (Claude)
- OpenAI (GPT)
- GitHub Copilot
- 自定义兼容端点

### 4. Storage 模块 (features/storage/)

**职责**: 数据持久化

| 文件 | 说明 |
|-----|------|
| `ConversationStore.ets` | 对话 SQLite 存储 |

**存储内容**:
- 对话历史
- 消息记录
- 用户配置
- 技能缓存

### 5. Security 模块 (features/security/)

**职责**: 权限与安全

| 文件 | 说明 |
|-----|------|
| `PermissionChecker.ets` | 权限检查器 |

**权限模式**:
- `DEFAULT` - 写操作需确认
- `AUTO` - 自动允许所有
- `PLAN` - 禁止写操作
- `STRICT` - 所有操作需确认

## 数据流

```
用户输入
    │
    ▼
┌─────────────────────────────────────┐
│  UI (Index.ets)                     │
│  - 用户界面渲染                      │
│  - 事件处理                          │
└─────────────────────────────────────┘
    │
    ▼
┌─────────────────────────────────────┐
│  QueryEngine                        │
│  - 构建消息历史                      │
│  - 调用 LLM API                      │
│  - 处理流式响应                      │
└─────────────────────────────────────┘
    │
    ├── 文本增量 ─────> UI 更新
    │
    ├── 工具调用 ─────> PermissionChecker
    │                        │
    │                        ▼ (允许)
    │              ┌─────────────────────┐
    │              │  ToolRegistry       │
    │              │  - 查找工具         │
    │              │  - 执行工具         │
    │              └─────────────────────┘
    │                        │
    │                        ▼
    │              ┌─────────────────────┐
    │              │  Tool.execute()     │
    │              │  - 文件操作         │
    │              │  - 网络请求         │
    │              │  - 后台任务         │
    │              └─────────────────────┘
    │                        │
    └────────────────────────┘
               │
               ▼
    ┌─────────────────────┐
    │  Tool Result        │
    │  添加回对话历史      │
    └─────────────────────┘
               │
               ▼
    ┌─────────────────────┐
    │  ConversationStore  │
    │  持久化到 SQLite     │
    └─────────────────────┘
```

## 构建流程

1. **编译**: DevEco Studio 编译 ArkTS -> JS
2. **打包**: 打包为 HAP (HarmonyOS Ability Package)
3. **签名**: 应用数字签名
4. **安装**: 部署到设备或模拟器

## 运行环境

- **最低系统版本**: HarmonyOS 5.0.0
- **设备类型**: Phone, Tablet, 2in1
- **权限要求**: 
  - Internet (连接 LLM API)
  - Storage (保存对话历史)
  - Background Running (后台任务)
