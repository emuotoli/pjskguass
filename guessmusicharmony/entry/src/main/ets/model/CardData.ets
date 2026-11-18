export class CardData {
  id: string;
  character: string;
  rarity: number;
  normalUrl: string;
  afterUrl: string;
  cardName: string;

  constructor(
    id: string = '',
    character: string = '',
    rarity: number = 0,
    normalUrl: string = '',
    afterUrl: string = '',
    cardName: string = ''
  ) {
    this.id = id;
    this.character = character;
    this.rarity = rarity;
    this.normalUrl = normalUrl;
    this.afterUrl = afterUrl;
    this.cardName = cardName;
  }

  static fromJson(json: Record<string, Object>): CardData {
    return new CardData(
      json['id'] as string || '',
      json['character'] as string || '',
      json['rarity'] as number || 3,
      json['normalUrl'] as string || '',
      json['afterUrl'] as string || '',
      json['cardName'] as string || ''
    );
  }

  toJson(): Record<string, Object> {
    return {
      'id': this.id,
      'character': this.character,
      'rarity': this.rarity,
      'normalUrl': this.normalUrl,
      'afterUrl': this.afterUrl,
      'cardName': this.cardName
    };
  }
}
