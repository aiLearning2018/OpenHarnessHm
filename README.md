# OpenHarnessHm

OpenHarness 的 HarmonyOS 原生移植版本 - 使用 ArkTS/ArkUI 构建的 AI Agent 基础设施。

## 项目概述

本项目将 OpenHarness（Python 实现的 AI Agent 框架）原生移植到 HarmonyOS 平台，保留核心架构设计理念，同时适配移动端特性。

### 核心特性

- 🔄 **Agent 循环引擎**: 流式工具调用循环，支持多轮对话
- 🔧 **工具系统**: 43+ 工具 (文件、Shell、搜索、Web、MCP 等)
- 🧠 **上下文管理**: 对话历史、技能加载、记忆持久化
- 🛡️ **权限控制**: 多级权限模式，路径/命令规则
- 🤝 **多 Agent 协调**: 子 Agent 委派、团队协作
- 📱 **原生 UI**: ArkUI 声明式界面，流式渲染

## 技术栈

| 层级 | 技术 |
|-----|------|
| 语言 | ArkTS (TypeScript 超集) |
| UI | ArkUI 声明式 UI |
| 网络 | @ohos.net.http, @ohos.net.websocket |
| 存储 | @ohos.data.relationalStore (SQLite) |
| 文件 | @ohos.file.fs |
| 后台 | @ohos.resourceschedule.backgroundTaskManager |

## 项目结构

```
OpenHarnessHm/
├── entry/                    # 应用入口模块
│   └── src/main/ets/
│       ├── entryability/     # EntryAbility
│       └── pages/            # 页面
├── features/                 # 特性模块
│   ├── core/                 # 核心引擎
│   │   ├── model/            # 数据模型
│   │   └── engine/           # 查询引擎
│   ├── tools/                # 工具系统
│   │   ├── base/             # 工具基类
│   │   └── implementations/  # 工具实现
│   ├── api/                  # LLM API 客户端
│   ├── storage/              # 数据持久化
│   └── security/             # 权限安全
├── docs/                     # 文档
│   ├── ARCHITECTURE.md       # 架构文档
│   └── PORTING_PLAN.md       # 移植方案
└── resources/                # 资源文件
```

## 快速开始

### 环境要求

- DevEco Studio 5.0+
- HarmonyOS SDK 5.0.0+
- Node.js 18+

### 安装步骤

1. 克隆仓库
```bash
git clone https://github.com/HKUDS/OpenHarnessHm.git
cd OpenHarnessHm
```

2. 使用 DevEco Studio 打开项目

3. 同步依赖并构建

4. 运行到模拟器或真机

### 配置 API

在应用设置中配置 LLM API：

1. 打开设置页面
2. 选择 Provider (Anthropic/OpenAI/自定义)
3. 输入 API Key
4. 选择模型

## 架构映射

| OpenHarness (Python) | OpenHarnessHm (HarmonyOS) |
|---------------------|---------------------------|
| `engine/query_engine.py` | `core/engine/QueryEngine.ets` |
| `tools/base.py` | `tools/base/BaseTool.ets` |
| `api/client.py` | `api/base/LLMClient.ets` |
| `permissions/checker.py` | `security/PermissionChecker.ets` |
| `memory/` | `storage/MemoryManager.ets` |
| `ui/` (React) | `ui/` (ArkUI) |

## 开发路线图

- [x] 项目架构设计
- [x] 核心数据模型
- [x] 工具基类框架
- [x] 查询引擎核心
- [ ] 完整工具实现 (43+)
- [ ] 多 Provider 支持
- [ ] 技能系统
- [ ] MCP 协议支持
- [ ] 多 Agent 协调
- [ ] 后台任务管理
- [ ] 应用商店上架

## 贡献指南

欢迎贡献代码！请遵循以下规范：

1. 代码风格遵循 ArkTS 规范
2. 所有工具必须实现 BaseTool 接口
3. UI 组件使用 ArkUI 声明式语法
4. 添加单元测试
5. 更新相关文档

## 许可证

MIT - 详见 [LICENSE](../LICENSE)

---

**Oh my Harness on HarmonyOS!**
