// entry/pages/Index.ets
// 主页面 - 聊天界面

import { Conversation, ConversationMessage, MessageRole, ContentType } from '../../../features/core/model/Message';
import { StreamEvent, EventType } from '../../../features/core/model/StreamEvent';
import { QueryEngine } from '../../../features/core/engine/QueryEngine';
import { ToolRegistry } from '../../../features/tools/base/ToolRegistry';
import { FileReadTool } from '../../../features/tools/implementations/FileReadTool';
import { FileWriteTool } from '../../../features/tools/implementations/FileWriteTool';
import { PermissionChecker, PermissionMode } from '../../../features/security/PermissionChecker';
import { getConversationStore } from '../../../features/storage/ConversationStore';

@Entry
@Component
struct ChatPage {
  @State conversation: Conversation = new Conversation('kimi-k2.5');
  @State isProcessing: boolean = false;
  @State inputText: string = '';
  @State currentStreamingText: string = '';
  @State messages: ConversationMessage[] = [];
  @State scrollToEnd: boolean = false;
  
  private queryEngine: QueryEngine | null = null;
  private listScroller: ListScroller = new ListScroller();

  aboutToAppear() {
    // 初始化 QueryEngine
    this.initializeQueryEngine();
    
    // 加载历史对话或创建新对话
    this.loadConversation();
  }

  initializeQueryEngine() {
    // 创建工具注册表
    const toolRegistry = new ToolRegistry();
    toolRegistry.register(new FileReadTool());
    toolRegistry.register(new FileWriteTool());
    
    // 创建权限检查器
    const permissionChecker = new PermissionChecker({
      mode: PermissionMode.DEFAULT,
      autoApproveReadOnly: true
    });

    // TODO: 初始化实际的 LLM 客户端
    // 这里使用模拟客户端
    const mockClient = {
      async *streamMessages(params: any) {
        // 模拟响应
        yield { type: EventType.TEXT_DELTA, delta: '这是一个模拟响应。' };
        yield { type: EventType.DONE };
      }
    };

    // 创建 QueryEngine
    this.queryEngine = new QueryEngine(
      {
        apiClient: mockClient as any,
        toolRegistry: toolRegistry,
        permissionChecker: permissionChecker,
        cwd: getContext().filesDir,
        model: 'kimi-k2.5',
        systemPrompt: '你是一个 helpful 的 AI 助手。',
        toolContext: {
          cwd: getContext().filesDir,
          metadata: {},
          getAppFilePath: (p) => `${getContext().filesDir}/${p}`,
          getTempDir: () => getContext().tempDir,
          getCacheDir: () => getContext().cacheDir
        }
      },
      this.conversation
    );
  }

  async loadConversation() {
    // 尝试加载最近的对话
    const store = getConversationStore();
    const conversations = await store.listConversations(1);
    if (conversations.length > 0) {
      const loaded = await store.loadConversation(conversations[0].id);
      if (loaded) {
        this.conversation = loaded;
        this.messages = loaded.messages;
      }
    }
  }

  async sendMessage() {
    if (!this.inputText.trim() || this.isProcessing || !this.queryEngine) {
      return;
    }

    const userText = this.inputText;
    this.inputText = '';
    this.isProcessing = true;
    this.currentStreamingText = '';

    try {
      // 提交消息到 QueryEngine
      for await (const event of this.queryEngine.submitMessage(userText)) {
        this.handleStreamEvent(event);
      }

      // 保存对话
      await getConversationStore().saveConversation(this.conversation);
      
    } catch (error) {
      console.error('Error sending message:', error);
    } finally {
      this.isProcessing = false;
      this.currentStreamingText = '';
      this.messages = this.conversation.messages;
      this.scrollToBottom();
    }
  }

  handleStreamEvent(event: StreamEvent) {
    switch (event.type) {
      case EventType.TEXT_DELTA:
        this.currentStreamingText += event.delta;
        break;
        
      case EventType.TOOL_USE_START:
        console.info(`Tool use: ${event.name}`);
        break;
        
      case EventType.TOOL_RESULT:
        console.info(`Tool result: ${event.result.output.slice(0, 100)}`);
        break;
        
      case EventType.DONE:
        this.messages = this.conversation.messages;
        break;
        
      case EventType.ERROR:
        console.error('Stream error:', event.error);
        break;
    }
  }

  scrollToBottom() {
    this.scrollToEnd = true;
  }

  build() {
    Column() {
      // 顶部标题栏
      Row() {
        Text(this.conversation.title || 'OpenHarness')
          .fontSize(20)
          .fontWeight(FontWeight.Bold)
          .layoutWeight(1)
        
        if (this.isProcessing) {
          LoadingProgress()
            .width(24)
            .height(24)
            .color(Color.Blue)
        }
      }
      .width('100%')
      .padding(16)
      .backgroundColor('#F5F5F5')

      // 消息列表
      List({ scroller: this.listScroller }) {
        ForEach(this.messages, (msg: ConversationMessage, index: number) => {
          ListItem() {
            this.MessageBubble(msg)
          }
        }, (msg: ConversationMessage) => msg.id)

        // 流式显示当前响应
        if (this.currentStreamingText) {
          ListItem() {
            this.StreamingBubble(this.currentStreamingText)
          }
        }
      }
      .width('100%')
      .layoutWeight(1)
      .padding(8)
      .scrollBar(BarState.Auto)

      // 输入区域
      Row() {
        TextInput({ text: $$this.inputText, placeholder: '输入消息...' })
          .width('80%')
          .height(48)
          .onSubmit(() => this.sendMessage())
        
        Button('发送')
          .width('18%')
          .height(48)
          .enabled(!this.isProcessing && this.inputText.trim().length > 0)
          .onClick(() => this.sendMessage())
      }
      .width('100%')
      .padding(12)
      .backgroundColor('#FFFFFF')
      .shadow({ radius: 8, color: '#CCCCCC', offsetY: -2 })
    }
    .width('100%')
    .height('100%')
    .backgroundColor('#F0F0F0')
  }

  @Builder
  MessageBubble(msg: ConversationMessage) {
    Column() {
      if (msg.role === MessageRole.USER) {
        // 用户消息 - 右对齐
        Row() {
          Text(msg.getTextContent())
            .fontSize(14)
            .fontColor(Color.White)
            .padding(12)
            .backgroundColor('#007AFF')
            .borderRadius(16)
            .constraintModifier({ maxWidth: '70%' })
        }
        .width('100%')
        .justifyContent(FlexAlign.End)
      } else if (msg.role === MessageRole.ASSISTANT) {
        // 助手消息 - 左对齐
        Row() {
          if (msg.hasToolUses()) {
            // 显示工具调用
            Column() {
              ForEach(msg.getToolUses(), (toolUse) => {
                Row() {
                  Image($r('app.media.ic_tool'))
                    .width(16)
                    .height(16)
                  Text(`使用工具: ${toolUse.name}`)
                    .fontSize(12)
                    .fontColor('#666666')
                    .margin({ left: 4 })
                }
                .padding(8)
                .backgroundColor('#F0F0F0')
                .borderRadius(8)
              })
            }
          } else {
            Text(msg.getTextContent())
              .fontSize(14)
              .fontColor(Color.Black)
              .padding(12)
              .backgroundColor('#FFFFFF')
              .borderRadius(16)
              .constraintModifier({ maxWidth: '70%' })
          }
        }
        .width('100%')
        .justifyContent(FlexAlign.Start)
      }
    }
    .width('100%')
    .padding({ vertical: 4 })
  }

  @Builder
  StreamingBubble(text: string) {
    Row() {
      Column() {
        Text(text)
          .fontSize(14)
          .fontColor(Color.Black)
        
        // 闪烁光标
        Row() {
          Text('▋')
            .fontSize(14)
            .fontColor('#007AFF')
        }
        .width('100%')
      }
      .padding(12)
      .backgroundColor('#FFFFFF')
      .borderRadius(16)
      .constraintModifier({ maxWidth: '70%' })
    }
    .width('100%')
    .justifyContent(FlexAlign.Start)
    .padding({ vertical: 4 })
  }
}
