import router from '@ohos.router';
import media from '@ohos.multimedia.media';
import { VideoService } from '../service/VideoService';
import { VideoData } from '../model/VideoData';
import { MusicData } from '../model/MusicData';

@Entry
@Component
struct VideoGamePage {
  @State currentVideo: VideoData | null = null;
  @State currentSong: MusicData | null = null;
  @State userInput: string = '';
  @State feedback: string = '';
  @State isCorrect: boolean = false;
  @State showAnswer: boolean = false;
  @State isPlaying: boolean = false;
  @State isDataLoaded: boolean = false;
  @State isDownloading: boolean = false;
  @State downloadProgress: number = 0;
  @State pendingClipSeconds: number = 5;
  @State currentPosition: number = 0;
  @State duration: number = 0;
  @State isPreviewMode: boolean = true;
  @State fadeOut: boolean = false;
  @State fadeIn: boolean = false;
  @State videoFilePath: string = '';
  @State showDrawer: boolean = false;
  @State videoCount: number = 0;

  private videoService: VideoService = VideoService.getInstance();
  private player: media.AVPlayer | null = null;
  private loopTimer: number | null = null;

  aboutToAppear(): void {
    this.loadData();
  }

  aboutToDisappear(): void {
    this.cleanup();
  }

  private cleanup(): void {
    if (this.loopTimer !== null) {
      clearTimeout(this.loopTimer);
      this.loopTimer = null;
    }
    if (this.player) {
      this.player.release();
      this.player = null;
    }
  }

  private async loadData(): Promise<void> {
    try {
      await this.videoService.loadData();
      this.videoCount = this.videoService.getVideoCount();
      await this.loadNextVideo();
      this.isDataLoaded = true;
    } catch (e) {
      console.error('Error loading video data:', e);
      this.isDataLoaded = true;
    }
  }

  private async loadNextVideo(): Promise<void> {
    this.cleanup();

    const video = this.videoService.getRandomVideo();
    if (!video) {
      return;
    }

    this.currentVideo = video;
    this.currentSong = this.videoService.getSongForVideo(video);
    this.userInput = '';
    this.feedback = '';
    this.isCorrect = false;
    this.showAnswer = false;
    this.isPreviewMode = true;
    this.videoFilePath = '';
    this.currentPosition = 0;
    this.duration = 0;
    this.fadeOut = false;
    this.fadeIn = false;

    this.isDownloading = true;
    this.downloadProgress = 0;

    try {
      const filePath = await this.videoService.downloadVideo(
        video.bvid, video.title, (progress: number) => {
          this.downloadProgress = progress;
        }
      );

      if (filePath) {
        this.videoFilePath = filePath;
        this.initPlayer();
      } else {
        this.isDownloading = false;
        this.feedback = '视频下载失败，无法播放';
      }
    } catch (e) {
      console.error('Video download failed:', e);
      this.isDownloading = false;
      this.feedback = '视频加载失败';
    }
  }

  private initPlayer(): void {
    if (!this.videoFilePath) return;

    try {
      media.createAVPlayer().then((player) => {
        this.player = player;
        
        player.on('timeUpdate', (time: number) => {
          this.currentPosition = time;
          
          if (this.isPreviewMode && this.pendingClipSeconds > 0 && 
              time >= this.pendingClipSeconds * 1000 && !this.fadeOut) {
            this.loopClip();
          }
        });

        player.on('loaded', () => {
          this.isDownloading = false;
          this.duration = player.duration;
        });

        player.on('playComplete', () => {
          if (this.isPreviewMode && !this.showAnswer) {
            this.loopClip();
          } else {
            this.isPlaying = false;
          }
        });

        player.on('error', (error: Error) => {
          console.error('Player error:', error);
          this.isDownloading = false;
          this.isPlaying = false;
        });

        player.fdSrc(this.videoFilePath).then(() => {
          this.duration = player.duration;
        });
      });
    } catch (e) {
      console.error('Player init failed:', e);
      this.isDownloading = false;
    }
  }

  private async playClip(): Promise<void> {
    if (!this.player) return;
    try {
      await this.player.seek(0);
      await this.player.play();
      this.isPlaying = true;
    } catch (e) {
      console.error('Play failed:', e);
    }
  }

  private async pausePlayer(): Promise<void> {
    if (this.player) {
      this.player.pause();
      this.isPlaying = false;
    }
  }

  private async loopClip(): Promise<void> {
    if (this.showAnswer) return;

    this.fadeOut = true;
    await this.delay(300);
    this.fadeOut = false;

    await this.pausePlayer();
    await this.delay(600);

    if (!this.showAnswer && this.currentVideo) {
      await this.player?.seek(0);
      this.fadeIn = true;
      await this.delay(300);
      this.fadeIn = false;

      await this.player?.play();
      this.isPlaying = true;
    }
  }

  private async playFullVideo(): Promise<void> {
    if (!this.player) return;
    try {
      this.isPreviewMode = false;
      await this.player.seek(0);
      await this.player.play();
      this.isPlaying = true;
    } catch (e) {
      console.error('Play full video failed:', e);
    }
  }

  private async skipVideo(): Promise<void> {
    this.showAnswer = true;
    this.isPreviewMode = false;
    this.feedback = '跳过';
    await this.pausePlayer();
    this.playFullVideo();
  }

  private checkAnswer(): void {
    if (!this.currentVideo) return;

    const correct = this.videoService.isCorrectTitle(this.currentVideo, this.userInput);

    this.isCorrect = correct;
    this.showAnswer = true;
    this.isPreviewMode = false;

    if (correct) {
      this.feedback = '🎉 回答正确！';
    } else {
      this.feedback = '😢 回答错误';
    }

    this.pausePlayer();
    setTimeout(() => {
      this.playFullVideo();
    }, 500);
  }

  private delay(ms: number): Promise<void> {
    return new Promise(resolve => setTimeout(resolve, ms));
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

        Text('🎬 猜MV')
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
        } else if (this.videoCount === 0) {
          Column() {
            Text('暂无MV数据')
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
              Stack() {
                if (this.videoFilePath && !this.isDownloading) {
                  Video({ src: this.videoFilePath })
                    .width('100%')
                    .height(220)
                    .objectFit(VideoFit.Contain)
                    .controls(false)
                    .autoPlay(false)
                } else {
                  Column() {
                    if (this.isDownloading) {
                      LoadingProgress()
                        .width(40)
                        .height(40)
                      Text(`下载中 ${this.downloadProgress}%`)
                        .fontSize(14)
                        .fontColor(Color.White)
                        .margin({ top: 8 })
                    } else {
                      Text('🎬')
                        .fontSize(48)
                    }
                  }
                  .width('100%')
                  .height(220)
                  .justifyContent(FlexAlign.Center)
                  .alignItems(HorizontalAlign.Center)
                  .backgroundColor('#222')
                }

                if (this.fadeOut) {
                  Column()
                    .width('100%')
                    .height(220)
                    .backgroundColor('rgba(0,0,0,0.9)')
                }
                if (this.fadeIn) {
                  Column()
                    .width('100%')
                    .height(220)
                    .backgroundColor('rgba(0,0,0,0.5)')
                }
              }
              .width('100%')
              .margin({ bottom: 15 })

              if (this.showAnswer && this.currentSong) {
                Column() {
                  if (this.currentSong.jacketUrl) {
                    Image(this.currentSong.jacketUrl)
                      .width(80)
                      .height(80)
                      .borderRadius(8)
                      .objectFit(ImageFit.Cover)
                      .margin({ bottom: 8 })
                  }
                  Text(this.currentSong.title)
                    .fontSize(16)
                    .fontWeight(FontWeight.Bold)
                    .fontColor(Color.White)
                }
                .width('100%')
                .padding(12)
                .backgroundColor('rgba(255,255,255,0.1)')
                .borderRadius(8)
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
                  this.playClip();
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
                    this.pausePlayer();
                  } else {
                    if (this.showAnswer) {
                      this.playFullVideo();
                    } else {
                      this.playClip();
                    }
                  }
                })

                Button() {
                  Text('⏭')
                    .fontSize(24)
                }
                .type(ButtonType.Circle)
                .backgroundColor('rgba(255,255,255,0.8)')
                .onClick(() => {
                  this.loadNextVideo();
                })
              }
              .margin({ bottom: 10 })

              Text(this.isPlaying ? '正在播放...' : '点击播放按钮开始')
                .fontSize(14)
                .fontWeight(FontWeight.Bold)
                .fontColor(Color.White)

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
                Text(`片段时长: ${this.pendingClipSeconds}秒`)
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
                      this.loadNextVideo();
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
                      this.loadNextVideo();
                    } else {
                      this.skipVideo();
                    }
                  })
                }
              }
              .margin({ bottom: 20 })

              if (this.showAnswer && this.currentSong) {
                Column() {
                  Text(this.feedback)
                    .fontSize(18)
                    .fontWeight(FontWeight.Bold)
                    .fontColor(this.isCorrect ? '#00FF00' : '#FF6666')
                    .margin({ bottom: 10 })

                  Text(`正确答案：${this.currentSong.title}`)
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
          Scroll() {
            Column() {
              ForEach(this.videoService.allVideos.slice(0, 50), (video: VideoData) => {
                Button() {
                  Text(video.title || video.bvid)
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
                  this.showDrawer = false;
                  this.cleanup();
                  this.currentVideo = video;
                  this.currentSong = this.videoService.getSongForVideo(video);
                  this.userInput = '';
                  this.feedback = '';
                  this.isCorrect = false;
                  this.showAnswer = true;
                  this.isPreviewMode = false;
                  this.videoFilePath = '';
                  this.downloadAndPlay(video);
                })
              })
            }
          }
          .width('80%')
          .height('100%')
          .backgroundColor('rgba(255,255,255,0.95)')
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

  private async downloadAndPlay(video: VideoData): Promise<void> {
    this.isDownloading = true;
    try {
      const filePath = await this.videoService.downloadVideo(video.bvid, video.title);
      if (filePath) {
        this.videoFilePath = filePath;
        this.initPlayer();
        setTimeout(() => {
          this.playFullVideo();
        }, 1000);
      } else {
        this.isDownloading = false;
        this.feedback = '视频下载失败';
      }
    } catch (e) {
      this.isDownloading = false;
    }
  }
}
