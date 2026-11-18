import router from '@ohos.router';
import { CardService } from '../service/CardService';
import { CardData } from '../model/CardData';
import { Constants } from '../common/Constants';

@Entry
@Component
struct CardGamePage {
  @State currentCard: CardData | null = null;
  @State options: string[] = [];
  @State correctAnswer: string = '';
  @State userAnswer: string = '';
  @State feedback: string = '';
  @State isCorrect: boolean = false;
  @State showAnswer: boolean = false;
  @State showAfterTraining: boolean = false;
  @State isDataLoaded: boolean = false;
  @State showAllCharacters: boolean = false;
  @State showDrawer: boolean = false;
  @State searchQuery: string = '';
  @State showRarity: boolean = true;

  private cardService: CardService = CardService.getInstance();

  aboutToAppear(): void {
    this.loadData();
  }

  private async loadData(): Promise<void> {
    try {
      await this.cardService.loadCards();
      await this.loadNextCard();
      this.isDataLoaded = true;
    } catch (e) {
      console.error('Error loading card data:', e);
      this.isDataLoaded = true;
    }
  }

  private async loadNextCard(): Promise<void> {
    const card = this.cardService.getRandomCardExcludeRarity2();
    if (!card) {
      return;
    }

    this.currentCard = card;
    this.correctAnswer = card.character;
    this.userAnswer = '';
    this.feedback = '';
    this.isCorrect = false;
    this.showAnswer = false;
    this.showAfterTraining = false;

    const allCharacters = Constants.CHARACTER_ORDER;
    const wrongOptions = allCharacters.filter(c => c !== card.character);
    
    const pickedWrong: string[] = [];
    const shuffled = wrongOptions.sort(() => Math.random() - 0.5);
    for (let i = 0; i < 3 && i < shuffled.length; i++) {
      pickedWrong.push(shuffled[i]);
    }

    this.options = [card.character, ...pickedWrong].sort(() => Math.random() - 0.5);
  }

  private selectCharacter(character: string): void {
    if (this.showAnswer) return;
    
    this.userAnswer = character;
    this.isCorrect = character === this.correctAnswer;
    this.showAnswer = true;
    
    if (this.isCorrect) {
      this.feedback = '🎉 回答正确！';
    } else {
      this.feedback = '😢 回答错误';
    }
  }

  private getFilteredCards(): CardData[] {
    let cards = [...this.cardService.getAllCards()];
    if (this.searchQuery) {
      cards = cards.filter(c => 
        c.character.includes(this.searchQuery) || 
        c.cardName.includes(this.searchQuery)
      );
    }
    return cards;
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

        Text('🎴 猜卡面')
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
          Text(this.showAllCharacters ? '全部' : '提示')
            .fontSize(12)
            .fontColor(Color.White)
        }
        .type(ButtonType.Circle)
        .backgroundColor(this.showAllCharacters ? 'rgba(255,255,255,0.5)' : 'rgba(255,255,255,0.2)')
        .margin({ left: 4 })
        .onClick(() => {
          this.showAllCharacters = !this.showAllCharacters;
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
        } else if (!this.currentCard) {
          Column() {
            Text('无法加载卡面数据')
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
                if (this.currentCard) {
                  Image(this.showAfterTraining && this.currentCard.afterUrl ? this.currentCard.afterUrl : this.currentCard.normalUrl)
                    .width(220)
                    .height(320)
                    .borderRadius(12)
                    .objectFit(ImageFit.Cover)
                    .backgroundColor('#222')
                }
              }
              .margin({ bottom: 10 })

              if (this.showRarity && this.currentCard) {
                Text(`${'★'.repeat(this.currentCard.rarity)}`)
                  .fontSize(20)
                  .fontColor('#FFD700')
                  .margin({ bottom: 10 })
              }

              if (this.showAnswer && this.currentCard) {
                Text(this.currentCard.cardName)
                  .fontSize(16)
                  .fontColor(Color.White)
                  .fontWeight(FontWeight.Bold)
                  .margin({ bottom: 10 })
              }

              Row() {
                Button() {
                  Text(this.showAfterTraining ? '特训前' : '特训后')
                    .fontSize(12)
                    .fontColor(Color.White)
                }
                .type(ButtonType.Capsule)
                .backgroundColor(this.showAfterTraining ? 'rgba(255,255,255,0.5)' : 'rgba(255,255,255,0.2)')
                .margin({ right: 10 })
                .onClick(() => {
                  this.showAfterTraining = !this.showAfterTraining;
                })
              }
              .margin({ bottom: 15 })

              Text('请选择角色：')
                .fontSize(16)
                .fontWeight(FontWeight.Bold)
                .fontColor(Color.White)
                .margin({ bottom: 10 })

              if (!this.showAllCharacters) {
                Grid() {
                  ForEach(this.options, (option: string) => {
                    Button() {
                      Text(option)
                        .fontSize(14)
                        .fontWeight(FontWeight.Bold)
                        .fontColor(this.showAnswer && option === this.correctAnswer ? Color.White : 
                                   (this.showAnswer && option === this.userAnswer && !this.isCorrect ? Color.White : Color.Black))
                    }
                    .type(ButtonType.Capsule)
                    .backgroundColor(
                      this.showAnswer && option === this.correctAnswer ? '#00AA00' :
                      (this.showAnswer && option === this.userAnswer && !this.isCorrect ? '#AA0000' : '#E0D4F5')
                    )
                    .width('90%')
                    .margin(4)
                    .onClick(() => {
                      this.selectCharacter(option);
                    })
                  })
                }
                .columnsTemplate('1fr 1fr')
                .rowsGap(8)
                .columnsGap(8)
                .width('100%')
              } else {
                Flex({ wrap: FlexWrap.Wrap }) {
                  ForEach(Constants.CHARACTER_ORDER, (character: string) => {
                    Button() {
                      Text(character)
                        .fontSize(12)
                        .fontColor(this.showAnswer && character === this.correctAnswer ? Color.White : Color.Black)
                    }
                    .type(ButtonType.Capsule)
                    .backgroundColor(
                      this.showAnswer && character === this.correctAnswer ? '#00AA00' :
                      (this.showAnswer && character === this.userAnswer && !this.isCorrect ? '#AA0000' : 'rgba(255,255,255,0.8)')
                    )
                    .margin(3)
                    .onClick(() => {
                      this.selectCharacter(character);
                    })
                  })
                }
                .width('100%')
              }

              if (this.showAnswer) {
                Column() {
                  Text(this.feedback)
                    .fontSize(18)
                    .fontWeight(FontWeight.Bold)
                    .fontColor(this.isCorrect ? '#00FF00' : '#FF6666')
                    .margin({ bottom: 8 })

                  Text(`答案：${this.correctAnswer}`)
                    .fontSize(14)
                    .fontColor(Color.White)
                }
                .width('100%')
                .alignItems(HorizontalAlign.Center)
                .margin({ top: 15, bottom: 15 })
              }

              if (this.showAnswer) {
                Button() {
                  Text('下一题')
                    .fontSize(16)
                    .fontColor(Color.White)
                }
                .type(ButtonType.Capsule)
                .backgroundColor('#6B46C1')
                .width('80%')
                .height(45)
                .onClick(() => {
                  this.loadNextCard();
                })
                .margin({ top: 10 })
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
            TextInput({ placeholder: '搜索角色或卡名...' })
              .width('90%')
              .backgroundColor(Color.White)
              .borderRadius(8)
              .onChange((value: string) => {
                this.searchQuery = value;
              })
              .margin(16)

            Scroll() {
              Column() {
                ForEach(this.getFilteredCards(), (card: CardData) => {
                  Button() {
                    Text(`${card.character} - ${card.cardName}`)
                      .fontSize(13)
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
                    this.currentCard = card;
                    this.correctAnswer = card.character;
                    this.userAnswer = '';
                    this.feedback = '';
                    this.isCorrect = false;
                    this.showAnswer = true;
                    this.showDrawer = false;
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
