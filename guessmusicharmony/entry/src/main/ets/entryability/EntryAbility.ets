import UIAbility from '@ohos.app.ability.UIAbility';
import window from '@ohos.window';
import hilog from '@ohos.hilog';

export default class EntryAbility extends UIAbility {
  onCreate(): void {
    hilog.info(0x0000, 'sekaigame', 'EntryAbility onCreate');
  }

  onDestroy(): void {
    hilog.info(0x0000, 'sekaigame', 'EntryAbility onDestroy');
  }

  onWindowStageCreate(windowStage: window.WindowStage): void {
    hilog.info(0x0000, 'sekaigame', 'onWindowStageCreate');
    windowStage.loadContent('pages/Index', (err) => {
      if (err.code) {
        hilog.error(0x0000, 'sekaigame', 'Failed to load content: %{public}s',
          JSON.stringify(err));
        return;
      }
      hilog.info(0x0000, 'sekaigame', 'Succeeded in loading content.');
    });
  }

  onWindowStageDestroy(): void {
    hilog.info(0x0000, 'sekaigame', 'onWindowStageDestroy');
  }

  onForeground(): void {
    hilog.info(0x0000, 'sekaigame', 'onForeground');
  }

  onBackground(): void {
    hilog.info(0x0000, 'sekaigame', 'onBackground');
  }
}
