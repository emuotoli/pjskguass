import router from '@ohos.router';
import { MusicService } from '../service/MusicService';
import { CardService } from '../service/CardService';

@Entry
@Component
struct Index {
  @State updateStatus: string = '检测更新中...';
  @State isLoading: boolean = true;
  @State hasUpdate: boolean = false;
  @State scanLogs: string[] = [];
  @State showLogs: boolean = false;

  private musicService: MusicService = MusicService.getInstance();
  private cardService: CardService = CardService.getInstance();

  aboutToAppear(): void {
    this.checkUpdates();
  }

  private async checkUpdates(): Promise<void> {
    this.isLoading = true;

    try {
      this.updateStatus = '🎵 正在加载音乐数据...';
      await this.musicService.loadMusics((message: string) => {
        this.updateStatus = `🎵 ${message}`;
        this.addLog(message);
      });

      const currentMusicCount = this.musicService.musicCount;

      this.updateStatus = '🎴 正在加载卡面数据...';
      await this.cardService.loadCards();

      this.updateStatus = '🎴 正在检查卡面更新...';
      await this.cardService.checkForUpdates((message: string) => {
        this.updateStatus = `🎴 ${message}`;
        this.addLog(message);
      });

      const currentCardCount = this.cardService.cardCount;

      this.isLoading = false;
      this.hasUpdate = this.scanLogs.length > 0;

      this.updateStatus = `✅ 数据加载完成\n音乐: ${currentMusicCount} 首 | 卡牌: ${currentCardCount} 张`;
      this.addLog(`📊 最终统计 - 音乐: ${currentMusicCount} 首, 卡牌: ${currentCardCount} 张`);
    } catch (e) {
      this.isLoading = false;
      this.updateStatus = `❌ 更新检测失败: ${e}`;
      this.hasUpdate = false;
    }
  }

  private addLog(message: string): void {
    this.scanLogs.push(message);
    if (this.scanLogs.length > 50) {
      this.scanLogs.shift();
    }
  }

  private navigateTo(page: string): void {
    router.pushUrl({ url: page });
  }

  build() {
    Column() {
      Row() {
        Text('Project SEKAI')
          .fontSize(24)
          .fontWeight(FontWeight.Bold)
          .fontColor(Color.White)
          .layoutWeight(1)
          .textAlign(TextAlign.Center)
        
        Button() {
          Text(this.showLogs ? '隐藏' : '日志')
            .fontSize(14)
            .fontColor(Color.White)
        }
        .type(ButtonType.Circle)
        .backgroundColor('rgba(255,255,255,0.2)')
        .onClick(() => {
          this.showLogs = !this.showLogs;
        })
      }
      .width('100%')
      .padding({ left: 16, right: 16, top: 40, bottom: 12 })
      .backgroundColor('#6B46C1')

      Stack() {
        Column() {
          Button() {
            Column() {
              Text('🎴')
                .fontSize(36)
              Text('猜卡面')
                .fontSize(20)
                .fontWeight(FontWeight.Bold)
                .fontColor(Color.White)
                .margin({ top: 8 })
            }
          }
          .width('80%')
          .height(100)
          .backgroundColor('rgba(255,255,255,0.15)')
          .border({ width: 2, color: Color.White, radius: 16 })
          .margin({ top: 20, bottom: 10 })
          .onClick(() => {
            this.navigateTo('pages/CardGamePage');
          })

          Button() {
            Column() {
              Text('🎬')
                .fontSize(36)
              Text('猜MV')
                .fontSize(20)
                .fontWeight(FontWeight.Bold)
                .fontColor(Color.White)
                .margin({ top: 8 })
            }
          }
          .width('80%')
          .height(100)
          .backgroundColor('rgba(255,255,255,0.15)')
          .border({ width: 2, color: Color.White, radius: 16 })
          .margin({ top: 10, bottom: 10 })
          .onClick(() => {
            this.navigateTo('pages/VideoGamePage');
          })

          Button() {
            Column() {
              Text('🎵')
                .fontSize(36)
              Text('猜音乐')
                .fontSize(20)
                .fontWeight(FontWeight.Bold)
                .fontColor(Color.White)
                .margin({ top: 8 })
            }
          }
          .width('80%')
          .height(100)
          .backgroundColor('rgba(255,255,255,0.15)')
          .border({ width: 2, color: Color.White, radius: 16 })
          .margin({ top: 10, bottom: 20 })
          .onClick(() => {
            this.navigateTo('pages/MusicGamePage');
          })
        }
        .width('100%')
        .justifyContent(FlexDirection.Column)
        .alignItems(HorizontalAlign.Center)

        if (this.showLogs) {
          Column() {
            Row() {
              Text(this.isLoading ? '⏳' : 'ℹ️')
                .fontSize(16)
              Text(this.updateStatus)
                .fontSize(14)
                .fontColor(Color.White)
                .layoutWeight(1)
                .margin({ left: 8 })
            }
            .width('100%')
            .alignItems(VerticalAlign.Top)

            Text('扫描日志:')
              .fontSize(13)
              .fontColor('#AAA')
              .margin({ top: 8 })
            Scroll() {
              Column() {
                ForEach(this.scanLogs.slice(-20), (log: string) => {
                  Text(log)
                    .fontSize(11)
                    .fontColor('#CCC')
                    .width('100%')
                    .padding({ top: 1 })
                })
              }
            }
            .height(120)
            .width('100%')
          }
          .width('90%')
          .padding(16)
          .backgroundColor('rgba(0,0,0,0.85)')
          .border({ width: 1, color: 'rgba(255,255,255,0.3)', radius: 12 })
          .margin(16)
        }
      }
      .width('100%')
      .layoutWeight(1)
      .alignContent(Alignment.Top)
    }
    .width('100%')
    .height('100%')
    .linearGradient({
      angle: 180,
      colors: [['#6B46C1', 0], ['#4A3670', 1]]
    })
  }
}
