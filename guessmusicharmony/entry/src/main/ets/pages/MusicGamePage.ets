import router from '@ohos.router';
import audio from '@ohos.multimedia.audio';
import { MusicService } from '../service/MusicService';
import { MusicData } from '../model/MusicData';

@Entry
@Component
struct MusicGamePage {
  @State currentMusic: MusicData | null = null;
  @State userInput: string = '';
  @State feedback: string = '';
  @State isCorrect: boolean = false;
  @State isPlaying: boolean = false;
  @State showAnswer: boolean = false;
  @State isLoadingAudio: boolean = false;
  @State isDataLoaded: boolean = false;
  @State isPreviewMode: boolean = true;
  @State beginnerMode: boolean = false;
  @State showDrawer: boolean = false;
  @State selectedVersion: number = 0;
  @State clipSeconds: number = 5;
  @State pendingClipSeconds: number = 5;
  @State currentPosition: number = 0;
  @State duration: number = 0;
  @State searchQuery: string = '';

  private musicService: MusicService = MusicService.getInstance();
  private audioPlayer: audio.AudioPlayer | null = null;

  aboutToAppear(): void {
    this.initAudioPlayer();
    this.loadData();
  }

  aboutToDisappear(): void {
    if (this.audioPlayer) {
      this.audioPlayer.release();
    }
  }

  private async initAudioPlayer(): Promise<void> {
    try {
      this.audioPlayer = await audio.createAudioPlayer();
      this.audioPlayer.on('timeUpdate', (time: number) => {
        this.currentPosition = time;
        if (this.isPreviewMode && this.pendingClipSeconds > 0 && time >= this.pendingClipSeconds * 1000) {
          this.audioPlayer?.pause();
        }
      });
      this.audioPlayer.on('playFinished', () => {
        this.isPlaying = false;
      });
    } catch (e) {
      console.error('Failed to init audio player:', e);
    }
  }

  private async loadData(): Promise<void> {
    try {
      await this.musicService.loadMusicsLocalOnly();
      if (this.musicService.hasMusics) {
        await this.loadNextMusic();
      }
      this.isDataLoaded = true;
    } catch (e) {
      console.error('Error loading data:', e);
      this.isDataLoaded = true;
    }
  }

  private async loadNextMusic(): Promise<void> {
    if (this.audioPlayer) {
      this.audioPlayer.pause();
    }

    this.currentMusic = this.musicService.getRandomMusic(this.beginnerMode);

    this.selectedVersion = 0;
    this.userInput = '';
    this.feedback = '';
    this.isCorrect = false;
    this.isPlaying = false;
    this.showAnswer = false;
    this.isPreviewMode = true;
    this.currentPosition = 0;
    this.duration = 0;
    this.clipSeconds = this.pendingClipSeconds;

    if (this.currentMusic) {
      this.musicService.markMusicPlayed(this.currentMusic.id.toString());
    }
  }

  private async playMusic(): Promise<void> {
    if (!this.currentMusic || this.currentMusic.audioUrls.length === 0) {
      this.feedback = '无法加载音频';
      return;
    }

    this.isLoadingAudio = true;

    try {
      const url = this.currentMusic.audioUrls[this.selectedVersion];
      
      if (this.audioPlayer) {
        await this.audioPlayer.release();
        this.audioPlayer = await audio.createAudioPlayer();
        this.audioPlayer.on('timeUpdate', (time: number) => {
          this.currentPosition = time;
          if (this.isPreviewMode && this.pendingClipSeconds > 0 && time >= this.pendingClipSeconds * 1000) {
            this.audioPlayer?.pause();
          }
        });
        this.audioPlayer.on('playFinished', () => {
          this.isPlaying = false;
        });
      }

      await this.audioPlayer?.createAudio(url);
      await this.audioPlayer?.seek(9 * 1000);
      await this.audioPlayer?.play();
      this.isPlaying = true;
      this.isLoadingAudio = false;
    } catch (e) {
      console.error('Audio play failed:', e);
      this.isLoadingAudio = false;
      await this.loadNextMusic();
    }
  }

  private async pauseMusic(): Promise<void> {
    if (this.audioPlayer) {
      this.audioPlayer.pause();
      this.isPlaying = false;
    }
  }

  private async skipMusic(): Promise<void> {
    this.feedback = '跳过';
    this.showAnswer = true;
    this.isPreviewMode = false;
    await this.pauseMusic();
    this.playFullMusic();
  }

  private async playFullMusic(): Promise<void> {
    if (!this.currentMusic || this.currentMusic.audioUrls.length === 0) return;
    try {
      const url = this.currentMusic.audioUrls[this.selectedVersion];
      if (this.audioPlayer) {
        await this.audioPlayer.release();
        this.audioPlayer = await audio.createAudioPlayer();
        this.audioPlayer.on('timeUpdate', (time: number) => {
          this.currentPosition = time;
        });
        this.audioPlayer.on('playFinished', () => {
          this.isPlaying = false;
        });
        await this.audioPlayer.createAudio(url);
        await this.audioPlayer.seek(9 * 1000);
        await this.audioPlayer.play();
        this.isPlaying = true;
      }
    } catch (e) {
      console.error('Failed to play full music:', e);
    }
  }

  private checkAnswer(): void {
    if (!this.currentMusic) return;

    const correct = this.musicService.isCorrectTitle(this.currentMusic, this.userInput);

    this.isCorrect = correct;
    this.showAnswer = true;
    this.isPreviewMode = false;

    if (correct) {
      this.feedback = '🎉 回答正确！';
    } else {
      this.feedback = '😢 回答错误';
    }

    this.pauseMusic();
    setTimeout(() => {
      this.playFullMusic();
    }, 500);
  }

  private getDrawerMusics(): MusicData[] {
    let musics: MusicData[];
    if (this.searchQuery) {
      musics = this.musicService.searchMusics(this.searchQuery);
    } else {
      musics = [...this.musicService.allMusics];
    }
    musics.sort((a, b) => b.id - a.id);
    return musics;
  }

  private selectMusicFromDrawer(music: MusicData): void {
    this.currentMusic = music;
    this.selectedVersion = 0;
    this.userInput = '';
    this.isPreviewMode = false;
    this.isPlaying = false;
    this.showAnswer = true;
    this.feedback = '直接播放';
    this.showDrawer = false;
    this.playFullMusic();
  }

  build() {
    Column() {
      Row() {
        Button() {
          Text('←')
            .fontSize(20)
            .fontColor(Color.White)
        }
        .type(ButtonType.Circle)
        .backgroundColor('rgba(255,255,255,0.2)')
        .onClick(() => {
          router.back();
        })

        Text('🎵 猜音乐')
          .fontSize(20)
          .fontWeight(FontWeight.Bold)
          .fontColor(Color.White)
          .layoutWeight(1)
          .textAlign(TextAlign.Center)

        Button() {
          Text('📋')
            .fontSize(18)
        }
        .type(ButtonType.Circle)
        .backgroundColor('rgba(255,255,255,0.2)')
        .onClick(() => {
          this.showDrawer = !this.showDrawer;
        })

        Button() {
          Text(this.beginnerMode ? '新手' : '普通')
            .fontSize(12)
            .fontColor(Color.White)
        }
        .type(ButtonType.Circle)
        .backgroundColor(this.beginnerMode ? 'rgba(255,255,255,0.5)' : 'rgba(255,255,255,0.2)')
        .margin({ left: 4 })
        .onClick(() => {
          this.beginnerMode = !this.beginnerMode;
          this.loadNextMusic();
        })
      }
      .width('100%')
      .padding({ left: 8, right: 8, top: 40, bottom: 12 })
      .backgroundColor('#6B46C1')

      Stack() {
        if (!this.isDataLoaded) {
          Column() {
            LoadingProgress()
              .width(40)
              .height(40)
            Text('加载中...')
              .fontSize(16)
              .fontColor(Color.White)
              .margin({ top: 16 })
          }
          .width('100%')
          .height('100%')
          .justifyContent(FlexAlign.Center)
          .alignItems(HorizontalAlign.Center)
        } else if (!this.musicService.hasMusics) {
          Column() {
            Text('无法加载音乐数据')
              .fontSize(18)
              .fontColor(Color.White)
          }
          .width('100%')
          .height('100%')
          .justifyContent(FlexAlign.Center)
          .alignItems(HorizontalAlign.Center)
        } else {
          Scroll() {
            Column() {
              Column() {
                if (this.showAnswer && this.currentMusic) {
                  Image(this.currentMusic.jacketUrl)
                    .width(150)
                    .height(150)
                    .borderRadius(12)
                    .objectFit(ImageFit.Cover)
                } else {
                  Text('🎵')
                    .fontSize(80)
                    .width(150)
                    .height(150)
                    .borderRadius(12)
                    .backgroundColor('#D8B4FE')
                    .textAlign(TextAlign.Center)
                }
              }
              .margin({ bottom: 15 })

              if (this.currentMusic && this.currentMusic.audioUrls.length > 1) {
                Row() {
                  ForEach(this.currentMusic.audioUrls, (_: string, index: number) => {
                    Button() {
                      Text(this.currentMusic!.versionNames[index] || `版本${index + 1}`)
                        .fontSize(12)
                        .fontColor(this.selectedVersion === index ? Color.White : Color.Black)
                    }
                    .type(ButtonType.Capsule)
                    .backgroundColor(this.selectedVersion === index ? '#6B46C1' : 'rgba(255,255,255,0.3)')
                    .margin({ left: 4, right: 4 })
                    .onClick(() => {
                      this.selectedVersion = index;
                    })
                  })
                }
                .margin({ bottom: 15 })
              }

              Row() {
                Button() {
                  Text('🔄')
                    .fontSize(24)
                }
                .type(ButtonType.Circle)
                .backgroundColor('rgba(255,255,255,0.8)')
                .onClick(() => {
                  this.playMusic();
                })

                Button() {
                  Text(this.isPlaying ? '⏸' : '▶')
                    .fontSize(32)
                }
                .type(ButtonType.Circle)
                .backgroundColor('#6B46C1')
                .margin({ left: 20, right: 20 })
                .onClick(() => {
                  if (this.isPlaying) {
                    this.pauseMusic();
                  } else {
                    this.playMusic();
                  }
                })

                Button() {
                  Text('⏭')
                    .fontSize(24)
                }
                .type(ButtonType.Circle)
                .backgroundColor('rgba(255,255,255,0.8)')
                .onClick(() => {
                  this.loadNextMusic();
                })
              }
              .margin({ bottom: 10 })

              Text(this.isPlaying ? '正在播放...' : '点击播放按钮开始')
                .fontSize(14)
                .fontWeight(FontWeight.Bold)
                .fontColor(Color.White)

              if (this.isLoadingAudio) {
                Text('音频加载中...')
                  .fontSize(12)
                  .fontColor('#AAA')
                  .margin({ top: 5 })
              }

              if (this.showAnswer && this.duration > 0) {
                Slider({
                  value: this.currentPosition,
                  min: 0,
                  max: this.duration,
                  step: 1,
                  style: SliderStyle.InSet
                })
                .width('80%')
                .margin({ top: 15 })
              }

              Column() {
                Text(`试听时长: ${this.pendingClipSeconds}秒`)
                  .fontSize(14)
                  .fontWeight(FontWeight.Bold)
                  .fontColor(Color.White)
                  .margin({ bottom: 8 })
                Slider({
                  value: this.pendingClipSeconds,
                  min: 5,
                  max: 20,
                  step: 1,
                  style: SliderStyle.OutSet
                })
                .width('80%')
                .onChange((value: number) => {
                  this.pendingClipSeconds = Math.round(value);
                })
                Row() {
                  Text('5秒')
                    .fontSize(12)
                    .fontColor('#AAA')
                    .layoutWeight(1)
                  Text('20秒')
                    .fontSize(12)
                    .fontColor('#AAA')
                }
                .width('80%')
              }
              .margin({ top: 15, bottom: 15 })

              Column() {
                TextInput({ placeholder: '输入歌曲名称' })
                  .width('90%')
                  .backgroundColor('rgba(255,255,255,0.9)')
                  .borderRadius(8)
                  .enabled(!this.showAnswer)
                  .onChange((value: string) => {
                    this.userInput = value;
                  })
                .margin({ bottom: 10 })

                Row() {
                  Button() {
                    Text(this.showAnswer ? '下一题' : '确认答案')
                      .fontSize(16)
                      .fontColor(Color.White)
                  }
                  .type(ButtonType.Capsule)
                  .backgroundColor((this.showAnswer || this.userInput) ? '#6B46C1' : 'rgba(255,255,255,0.3)')
                  .enabled(this.showAnswer || !!this.userInput)
                  .margin({ right: 10 })
                  .onClick(() => {
                    if (this.showAnswer) {
                      this.loadNextMusic();
                    } else {
                      this.checkAnswer();
                    }
                  })

                  Button() {
                    Text(this.showAnswer ? '下一题' : '跳过')
                      .fontSize(16)
                      .fontColor(Color.White)
                  }
                  .type(ButtonType.Capsule)
                  .backgroundColor('rgba(255,255,255,0.3)')
                  .onClick(() => {
                    if (this.showAnswer) {
                      this.loadNextMusic();
                    } else {
                      this.skipMusic();
                    }
                  })
                }
              }
              .margin({ bottom: 20 })

              if (this.showAnswer && this.currentMusic) {
                Column() {
                  Text(this.feedback)
                    .fontSize(18)
                    .fontWeight(FontWeight.Bold)
                    .fontColor(this.isCorrect ? '#00AA00' : '#AA0000')
                    .margin({ bottom: 10 })

                  Text(`正确答案：${this.currentMusic.title}`)
                    .fontSize(16)
                    .fontColor(Color.Black)
                }
                .width('90%')
                .padding(16)
                .backgroundColor(Color.White)
                .borderRadius(12)
                .margin({ bottom: 20 })
              }
            }
            .width('100%')
            .padding(16)
          }
          .width('100%')
          .height('100%')
        }

        if (this.showDrawer) {
          Column() {
            TextInput({ placeholder: '搜索歌曲...' })
              .width('90%')
              .backgroundColor(Color.White)
              .borderRadius(8)
              .onChange((value: string) => {
                this.searchQuery = value;
              })
              .margin(16)

            Scroll() {
              Column() {
                ForEach(this.getDrawerMusics(), (music: MusicData) => {
                  Button() {
                    Text(music.title)
                      .fontSize(14)
                      .fontWeight(FontWeight.Bold)
                      .fontColor('#6B46C1')
                      .maxLines(2)
                      .textOverflow({ overflow: TextOverflow.Ellipsis })
                  }
                  .width('90%')
                  .backgroundColor('rgba(255,255,255,0.9)')
                  .borderRadius(8)
                  .margin({ top: 4, bottom: 4, left: 16, right: 16 })
                  .onClick(() => {
                    this.selectMusicFromDrawer(music);
                  })
                })
              }
            }
            .layoutWeight(1)
          }
          .width('80%')
          .height('100%')
          .backgroundColor('rgba(255,255,255,0.95)')
          .alignItems(HorizontalAlign.Start)
        }
      }
      .width('100%')
      .layoutWeight(1)
    }
    .width('100%')
    .height('100%')
    .linearGradient({
      angle: 180,
      colors: [['#6B46C1', 0], ['#4A3670', 1]]
    })
  }
}
