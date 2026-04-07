// storage/ConversationStore.ets
// 对话持久化存储

import { Conversation, ConversationMessage } from '../core/model/Message';
import { relationalStore, ValuesBucket } from '@kit.ArkData';
import { Context } from '@kit.AbilityKit';

// 对话表结构
interface ConversationRecord extends ValuesBucket {
  id: string;
  title: string;
  model: string;
  system_prompt?: string;
  created_at: number;
  updated_at: number;
  metadata?: string; // JSON string
}

// 消息表结构
interface MessageRecord extends ValuesBucket {
  id: string;
  conversation_id: string;
  role: string;
  content: string; // JSON string
  timestamp: number;
  metadata?: string; // JSON string
}

export class ConversationStore {
  private store: relationalStore.RdbStore | null = null;
  private readonly DB_NAME = 'openharness.db';
  private readonly DB_VERSION = 1;

  // 初始化数据库
  async initialize(context: Context): Promise<void> {
    const config: relationalStore.StoreConfig = {
      name: this.DB_NAME,
      securityLevel: relationalStore.SecurityLevel.S1
    };

    this.store = await relationalStore.getRdbStore(context, config);
    await this.createTables();
  }

  // 创建表
  private async createTables(): Promise<void> {
    if (!this.store) return;

    // 对话表
    const createConversationTable = `
      CREATE TABLE IF NOT EXISTS conversations (
        id TEXT PRIMARY KEY,
        title TEXT NOT NULL,
        model TEXT NOT NULL,
        system_prompt TEXT,
        created_at INTEGER NOT NULL,
        updated_at INTEGER NOT NULL,
        metadata TEXT
      )
    `;

    // 消息表
    const createMessageTable = `
      CREATE TABLE IF NOT EXISTS messages (
        id TEXT PRIMARY KEY,
        conversation_id TEXT NOT NULL,
        role TEXT NOT NULL,
        content TEXT NOT NULL,
        timestamp INTEGER NOT NULL,
        metadata TEXT,
        FOREIGN KEY (conversation_id) REFERENCES conversations(id) ON DELETE CASCADE
      )
    `;

    // 索引
    const createIndex = `
      CREATE INDEX IF NOT EXISTS idx_messages_conv_id ON messages(conversation_id)
    `;

    await this.store.executeSql(createConversationTable);
    await this.store.executeSql(createMessageTable);
    await this.store.executeSql(createIndex);
  }

  // 保存对话
  async saveConversation(conversation: Conversation): Promise<void> {
    if (!this.store) throw new Error('Store not initialized');

    const record: ConversationRecord = {
      id: conversation.id,
      title: conversation.title,
      model: conversation.model,
      system_prompt: conversation.systemPrompt,
      created_at: conversation.createdAt,
      updated_at: conversation.updatedAt,
      metadata: conversation.metadata ? JSON.stringify(conversation.metadata) : undefined
    };

    // 插入或更新对话
    await this.store.insert('conversations', record, relationalStore.ConflictResolution.ON_CONFLICT_REPLACE);

    // 删除旧消息
    const predicates = new relationalStore.RdbPredicates('messages');
    predicates.equalTo('conversation_id', conversation.id);
    await this.store.delete(predicates);

    // 保存新消息
    for (const msg of conversation.messages) {
      await this.saveMessage(conversation.id, msg);
    }
  }

  // 保存单条消息
  private async saveMessage(conversationId: string, message: ConversationMessage): Promise<void> {
    if (!this.store) throw new Error('Store not initialized');

    const record: MessageRecord = {
      id: message.id,
      conversation_id: conversationId,
      role: message.role,
      content: JSON.stringify(message.content),
      timestamp: message.timestamp,
      metadata: message.metadata ? JSON.stringify(message.metadata) : undefined
    };

    await this.store.insert('messages', record);
  }

  // 加载对话
  async loadConversation(id: string): Promise<Conversation | null> {
    if (!this.store) throw new Error('Store not initialized');

    // 加载对话记录
    const predicates = new relationalStore.RdbPredicates('conversations');
    predicates.equalTo('id', id);
    const resultSet = await this.store.query(predicates);

    if (!resultSet.goToNextRow()) {
      resultSet.close();
      return null;
    }

    const conversation = this.parseConversation(resultSet);
    resultSet.close();

    // 加载消息
    conversation.messages = await this.loadMessages(id);

    return conversation;
  }

  // 加载所有对话列表
  async listConversations(limit: number = 50, offset: number = 0): Promise<Conversation[]> {
    if (!this.store) throw new Error('Store not initialized');

    const predicates = new relationalStore.RdbPredicates('conversations');
    predicates.orderByDesc('updated_at');
    predicates.limit(limit);
    predicates.offset(offset);

    const resultSet = await this.store.query(predicates);
    const conversations: Conversation[] = [];

    while (resultSet.goToNextRow()) {
      conversations.push(this.parseConversation(resultSet));
    }

    resultSet.close();
    return conversations;
  }

  // 加载消息
  private async loadMessages(conversationId: string): Promise<ConversationMessage[]> {
    if (!this.store) throw new Error('Store not initialized');

    const predicates = new relationalStore.RdbPredicates('messages');
    predicates.equalTo('conversation_id', conversationId);
    predicates.orderByAsc('timestamp');

    const resultSet = await this.store.query(predicates);
    const messages: ConversationMessage[] = [];

    while (resultSet.goToNextRow()) {
      messages.push(this.parseMessage(resultSet));
    }

    resultSet.close();
    return messages;
  }

  // 删除对话
  async deleteConversation(id: string): Promise<void> {
    if (!this.store) throw new Error('Store not initialized');

    const predicates = new relationalStore.RdbPredicates('conversations');
    predicates.equalTo('id', id);
    await this.store.delete(predicates);
  }

  // 搜索对话
  async searchConversations(query: string): Promise<Conversation[]> {
    if (!this.store) throw new Error('Store not initialized');

    const predicates = new relationalStore.RdbPredicates('conversations');
    predicates.contains('title', query);
    predicates.orderByDesc('updated_at');

    const resultSet = await this.store.query(predicates);
    const conversations: Conversation[] = [];

    while (resultSet.goToNextRow()) {
      conversations.push(this.parseConversation(resultSet));
    }

    resultSet.close();
    return conversations;
  }

  // 解析对话记录
  private parseConversation(resultSet: relationalStore.ResultSet): Conversation {
    const conversation = new Conversation(
      resultSet.getString(resultSet.getColumnIndex('model')),
      resultSet.getString(resultSet.getColumnIndex('system_prompt'))
    );
    
    conversation.id = resultSet.getString(resultSet.getColumnIndex('id'));
    conversation.title = resultSet.getString(resultSet.getColumnIndex('title'));
    conversation.createdAt = resultSet.getLong(resultSet.getColumnIndex('created_at'));
    conversation.updatedAt = resultSet.getLong(resultSet.getColumnIndex('updated_at'));
    
    const metadataStr = resultSet.getString(resultSet.getColumnIndex('metadata'));
    if (metadataStr) {
      conversation.metadata = JSON.parse(metadataStr);
    }

    return conversation;
  }

  // 解析消息记录
  private parseMessage(resultSet: relationalStore.ResultSet): ConversationMessage {
    const role = resultSet.getString(resultSet.getColumnIndex('role'));
    const contentStr = resultSet.getString(resultSet.getColumnIndex('content'));
    const content = JSON.parse(contentStr);
    
    const message = new ConversationMessage(role as any, content);
    message.id = resultSet.getString(resultSet.getColumnIndex('id'));
    message.timestamp = resultSet.getLong(resultSet.getColumnIndex('timestamp'));
    
    const metadataStr = resultSet.getString(resultSet.getColumnIndex('metadata'));
    if (metadataStr) {
      message.metadata = JSON.parse(metadataStr);
    }

    return message;
  }

  // 关闭数据库
  async close(): Promise<void> {
    if (this.store) {
      await this.store.close();
      this.store = null;
    }
  }
}

// 单例实例
let instance: ConversationStore | null = null;

export function getConversationStore(): ConversationStore {
  if (!instance) {
    instance = new ConversationStore();
  }
  return instance;
}
