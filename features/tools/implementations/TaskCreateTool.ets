// tools/implementations/TaskCreateTool.ets
// 后台任务创建工具

import { BaseTool, SystemTool } from '../base/BaseTool';
import { ToolContext, ToolResult } from '../base/ToolContext';
import { backgroundTaskManager } from '@kit.BackgroundTasksKit';
import { wantAgent } from '@kit.AbilityKit';
import { getContext } from '@kit.UIAbilityKit';

interface TaskCreateInput {
  name: string;
  description: string;
  command: string;
  timeout?: number;
}

interface TaskInfo {
  id: string;
  name: string;
  description: string;
  status: 'pending' | 'running' | 'completed' | 'failed';
  createdAt: number;
  startedAt?: number;
  completedAt?: number;
  result?: string;
  error?: string;
}

// 任务存储 (内存 + 持久化)
class TaskStore {
  private tasks: Map<string, TaskInfo> = new Map();

  addTask(task: TaskInfo): void {
    this.tasks.set(task.id, task);
  }

  getTask(id: string): TaskInfo | undefined {
    return this.tasks.get(id);
  }

  listTasks(): TaskInfo[] {
    return Array.from(this.tasks.values()).sort((a, b) => b.createdAt - a.createdAt);
  }

  updateTask(id: string, updates: Partial<TaskInfo>): void {
    const task = this.tasks.get(id);
    if (task) {
      Object.assign(task, updates);
    }
  }

  deleteTask(id: string): boolean {
    return this.tasks.delete(id);
  }
}

const taskStore = new TaskStore();

export class TaskCreateTool extends SystemTool<TaskCreateInput> {
  readonly name = 'task_create';
  readonly description = '创建后台任务，在后台执行长时间运行的操作';
  
  readonly inputSchema = {
    type: 'object' as const,
    properties: {
      name: {
        type: 'string',
        description: '任务名称'
      },
      description: {
        type: 'string',
        description: '任务描述'
      },
      command: {
        type: 'string',
        description: '要执行的命令或操作描述'
      },
      timeout: {
        type: 'number',
        description: '超时时间(秒)，默认300'
      }
    },
    required: ['name', 'description', 'command']
  };

  isReadOnly(): boolean {
    return false;
  }

  async execute(args: TaskCreateInput, context: ToolContext): Promise<ToolResult> {
    try {
      const taskId = `task-${Date.now()}-${Math.random().toString(36).substr(2, 9)}`;
      
      const taskInfo: TaskInfo = {
        id: taskId,
        name: args.name,
        description: args.description,
        status: 'pending',
        createdAt: Date.now()
      };

      taskStore.addTask(taskInfo);

      // 申请后台运行
      await this.requestBackgroundRunning(taskId, args);

      // 启动任务执行
      this.executeTask(taskId, args);

      return this.successResult(
        `任务已创建: ${args.name}\n任务ID: ${taskId}\n状态: pending`,
        {
          task_id: taskId,
          name: args.name,
          status: 'pending'
        }
      );

    } catch (error) {
      return this.errorResult(
        `创建任务失败: ${error instanceof Error ? error.message : String(error)}`
      );
    }
  }

  private async requestBackgroundRunning(taskId: string, args: TaskCreateInput): Promise<void> {
    try {
      const wantAgentInfo: wantAgent.WantAgentInfo = {
        wants: [
          {
            bundleName: 'com.openharness.hm',
            abilityName: 'EntryAbility',
            parameters: { taskId }
          }
        ],
        operationType: wantAgent.OperationType.START_ABILITY,
        requestCode: 0
      };

      const wantAgentObj = await wantAgent.getWantAgent(wantAgentInfo);

      await backgroundTaskManager.startBackgroundRunning(
        getContext(),
        backgroundTaskManager.BackgroundMode.DATA_TRANSFER,
        wantAgentObj
      );
    } catch (error) {
      console.error('Failed to request background running:', error);
    }
  }

  private async executeTask(taskId: string, args: TaskCreateInput): Promise<void> {
    taskStore.updateTask(taskId, { 
      status: 'running',
      startedAt: Date.now()
    });

    try {
      // 这里执行实际的任务逻辑
      // 模拟长时间运行任务
      const timeout = (args.timeout || 300) * 1000;
      
      await new Promise<void>((resolve, reject) => {
        const timer = setTimeout(() => {
          reject(new Error('Task timeout'));
        }, timeout);

        // 实际任务执行逻辑
        this.runCommand(args.command)
          .then(result => {
            clearTimeout(timer);
            resolve(result);
          })
          .catch(error => {
            clearTimeout(timer);
            reject(error);
          });
      });

      taskStore.updateTask(taskId, {
        status: 'completed',
        completedAt: Date.now(),
        result: 'Task completed successfully'
      });

    } catch (error) {
      taskStore.updateTask(taskId, {
        status: 'failed',
        completedAt: Date.now(),
        error: error instanceof Error ? error.message : String(error)
      });
    }
  }

  private async runCommand(command: string): Promise<void> {
    // 实际命令执行逻辑
    // 这里可以根据 command 内容执行不同的操作
    console.info(`Executing command: ${command}`);
    await new Promise(resolve => setTimeout(resolve, 1000));
  }
}

// 任务列表工具
interface TaskListInput {
  status?: 'pending' | 'running' | 'completed' | 'failed';
  limit?: number;
}

export class TaskListTool extends SystemTool<TaskListInput> {
  readonly name = 'task_list';
  readonly description = '列出所有后台任务';
  
  readonly inputSchema = {
    type: 'object' as const,
    properties: {
      status: {
        type: 'string',
        enum: ['pending', 'running', 'completed', 'failed'],
        description: '按状态过滤'
      },
      limit: {
        type: 'number',
        description: '最大返回数量'
      }
    }
  };

  isReadOnly(): boolean {
    return true;
  }

  async execute(args: TaskListInput, context: ToolContext): Promise<ToolResult> {
    let tasks = taskStore.listTasks();

    if (args.status) {
      tasks = tasks.filter(t => t.status === args.status);
    }

    if (args.limit) {
      tasks = tasks.slice(0, args.limit);
    }

    const output = tasks.length > 0
      ? tasks.map(t => {
          const status = t.status.toUpperCase();
          const time = new Date(t.createdAt).toLocaleString();
          return `[${status}] ${t.name} (${t.id})\n  描述: ${t.description}\n  创建: ${time}`;
        }).join('\n\n')
      : '没有任务';

    return this.successResult(output, { count: tasks.length });
  }
}

// 任务获取工具
interface TaskGetInput {
  task_id: string;
}

export class TaskGetTool extends SystemTool<TaskGetInput> {
  readonly name = 'task_get';
  readonly description = '获取任务详细信息和输出';
  
  readonly inputSchema = {
    type: 'object' as const,
    properties: {
      task_id: {
        type: 'string',
        description: '任务ID'
      }
    },
    required: ['task_id']
  };

  isReadOnly(): boolean {
    return true;
  }

  async execute(args: TaskGetInput, context: ToolContext): Promise<ToolResult> {
    const task = taskStore.getTask(args.task_id);
    
    if (!task) {
      return this.errorResult(`任务不存在: ${args.task_id}`);
    }

    const lines = [
      `任务: ${task.name}`,
      `ID: ${task.id}`,
      `描述: ${task.description}`,
      `状态: ${task.status}`,
      `创建: ${new Date(task.createdAt).toLocaleString()}`
    ];

    if (task.startedAt) {
      lines.push(`开始: ${new Date(task.startedAt).toLocaleString()}`);
    }

    if (task.completedAt) {
      lines.push(`完成: ${new Date(task.completedAt).toLocaleString()}`);
    }

    if (task.result) {
      lines.push(`结果:\n${task.result}`);
    }

    if (task.error) {
      lines.push(`错误:\n${task.error}`);
    }

    return this.successResult(lines.join('\n'), { task });
  }
}

// 任务停止工具
interface TaskStopInput {
  task_id: string;
}

export class TaskStopTool extends SystemTool<TaskStopInput> {
  readonly name = 'task_stop';
  readonly description = '停止正在运行的任务';
  
  readonly inputSchema = {
    type: 'object' as const,
    properties: {
      task_id: {
        type: 'string',
        description: '任务ID'
      }
    },
    required: ['task_id']
  };

  isReadOnly(): boolean {
    return false;
  }

  async execute(args: TaskStopInput, context: ToolContext): Promise<ToolResult> {
    const task = taskStore.getTask(args.task_id);
    
    if (!task) {
      return this.errorResult(`任务不存在: ${args.task_id}`);
    }

    if (task.status !== 'running' && task.status !== 'pending') {
      return this.errorResult(`任务状态为 ${task.status}，无法停止`);
    }

    // 停止任务逻辑
    taskStore.updateTask(args.task_id, {
      status: 'failed',
      completedAt: Date.now(),
      error: 'Task stopped by user'
    });

    return this.successResult(`任务已停止: ${args.task_id}`);
  }
}
