// entry/entryability/EntryAbility.ets
// 应用入口 Ability

import { AbilityConstant, UIAbility, Want } from '@kit.AbilityKit';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { window } from '@kit.ArkUI';
import { getConversationStore } from '../../../features/storage/ConversationStore';

const TAG = 'EntryAbility';

export default class EntryAbility extends UIAbility {
  onCreate(want: Want, launchParam: AbilityConstant.LaunchParam): void {
    hilog.info(0x0000, TAG, 'Ability onCreate');
    
    // 初始化存储
    this.initializeStorage();
  }

  onDestroy(): void {
    hilog.info(0x0000, TAG, 'Ability onDestroy');
    
    // 清理资源
    getConversationStore().close();
  }

  onWindowStageCreate(windowStage: window.WindowStage): void {
    hilog.info(0x0000, TAG, 'WindowStage onWindowStageCreate');

    // 加载主页面
    windowStage.loadContent('pages/Index', (err) => {
      if (err.code) {
        hilog.error(0x0000, TAG, 'Failed to load content: %{public}s', JSON.stringify(err));
        return;
      }
      hilog.info(0x0000, TAG, 'Succeeded in loading content');
    });
  }

  onWindowStageDestroy(): void {
    hilog.info(0x0000, TAG, 'WindowStage onWindowStageDestroy');
  }

  onForeground(): void {
    hilog.info(0x0000, TAG, 'Ability onForeground');
  }

  onBackground(): void {
    hilog.info(0x0000, TAG, 'Ability onBackground');
  }

  private async initializeStorage(): Promise<void> {
    try {
      const store = getConversationStore();
      await store.initialize(this.context);
      hilog.info(0x0000, TAG, 'Storage initialized successfully');
    } catch (error) {
      hilog.error(0x0000, TAG, 'Failed to initialize storage: %{public}s', String(error));
    }
  }
}
