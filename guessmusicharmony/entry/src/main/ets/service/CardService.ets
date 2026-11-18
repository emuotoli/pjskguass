import { CardData } from '../model/CardData';
import { Constants } from '../common/Constants';
import { NetUtils } from '../utils/NetUtils';
import preferences from '@ohos.data.preferences';

export class CardService {
  private static instance: CardService | null = null;
  private allCards: CardData[] = [];
  private validCards: CardData[] = [];
  private isLoaded: boolean = false;
  private prefStore: preferences.Preferences | null = null;

  static getInstance(): CardService {
    if (!CardService.instance) {
      CardService.instance = new CardService();
    }
    return CardService.instance;
  }

  get cardCount(): number {
    return this.allCards.length;
  }

  getValidCards(): CardData[] {
    return this.validCards;
  }

  getAllCards(): CardData[] {
    return this.allCards;
  }

  async initPreferences(): Promise<void> {
    if (!this.prefStore) {
      const context = getContext(this);
      this.prefStore = await preferences.getPreferences(context, 'card_prefs');
    }
  }

  async loadCards(): Promise<boolean> {
    if (this.isLoaded) {
      return this.validCards.length > 0;
    }

    this.allCards = [];
    this.validCards = [];

    try {
      await this.loadCardsFromLocal();
      await this.loadNewCardsFromPrefs();
      
      this.allCards.sort((a, b) => {
        const aNum = parseInt(a.id.replace(/[^0-9]/g, '')) || 0;
        const bNum = parseInt(b.id.replace(/[^0-9]/g, '')) || 0;
        return aNum - bNum;
      });

      this.isLoaded = true;
      return this.validCards.length > 0;
    } catch (e) {
      return false;
    }
  }

  private async loadCardsFromLocal(): Promise<void> {
    try {
      await this.initPreferences();
      const jsonStr = await this.prefStore!.get('cards_data', '') as string;
      if (jsonStr && jsonStr.length > 0) {
        const parsed = JSON.parse(jsonStr);
        if (Array.isArray(parsed)) {
          for (const item of parsed) {
            const card = CardData.fromJson(item as Record<string, Object>);
            this.addCard(card);
          }
        }
      }
    } catch (e) {
      // fallback
    }
  }

  private async loadNewCardsFromPrefs(): Promise<void> {
    try {
      await this.initPreferences();
      const jsonStr = await this.prefStore!.get(Constants.PREFS_KEY_NEW_CARDS, '') as string;
      if (jsonStr && jsonStr.length > 0) {
        const parsed = JSON.parse(jsonStr);
        if (Array.isArray(parsed)) {
          for (const item of parsed) {
            const card = CardData.fromJson(item as Record<string, Object>);
            if (card.id && !this.allCards.find(c => c.id === card.id)) {
              this.addCard(card);
            }
          }
        }
      }
    } catch (e) {
      // skip
    }
  }

  private addCard(card: CardData): void {
    this.allCards.push(card);
    if (card.character && (card.rarity >= 3 || card.rarity === 0)) {
      this.validCards.push(card);
    }
  }

  async checkForUpdates(onProgress?: (msg: string) => void): Promise<void> {
    onProgress?.('🔍 开始检查卡面更新...');

    try {
      await this.initPreferences();
      
      const savedIdStr = await this.prefStore!.get(Constants.PREFS_KEY_LAST_CARD_ID, '1421') as string;
      let lastCardId = parseInt(savedIdStr) || Constants.DEFAULT_LAST_CARD_ID;
      
      onProgress?.(`📦 上次保存的最后卡牌ID: ${lastCardId}`);

      const currentLocalIds = new Set<number>();
      for (const card of this.allCards) {
        const match = card.id.match(/(\d+)/);
        if (match) {
          currentLocalIds.add(parseInt(match[1]));
        }
      }

      let maxLocalId = 0;
      for (const id of currentLocalIds) {
        if (id > maxLocalId) maxLocalId = id;
      }
      onProgress?.(`📦 本地最大卡牌ID: ${maxLocalId}`);

      const newCards: CardData[] = [];
      let consecutiveFailures = 0;
      const maxConsecutiveFailures = 5;

      onProgress?.(`🔍 从ID ${lastCardId + 1} 开始检查...`);

      for (let id = lastCardId + 1; ; id++) {
        if (currentLocalIds.has(id)) {
          onProgress?.(`⏭️ ID ${id} 已存在本地`);
          lastCardId = id;
          continue;
        }

        onProgress?.(`🔍 检查卡 ID ${id}...`);
        const cardData = await this.fetchCardData(id.toString());
        
        if (cardData) {
          if (!this.allCards.find(c => c.id === cardData.id)) {
            this.addCard(cardData);
            newCards.push(cardData);
            onProgress?.(`🎉 添加新卡: ${cardData.character} ${cardData.cardName}`);
          }
          lastCardId = id;
          consecutiveFailures = 0;
        } else {
          consecutiveFailures++;
          onProgress?.(`❌ ID ${id} 获取失败 (连续失败: ${consecutiveFailures}/${maxConsecutiveFailures})`);
          
          if (consecutiveFailures >= maxConsecutiveFailures) {
            onProgress?.(`🛑 连续 ${maxConsecutiveFailures} 个ID无效，停止扫描`);
            break;
          }
        }

        await this.delay(500);
      }

      onProgress?.('✅ 扫描完成');

      if (newCards.length > 0) {
        this.validCards.sort((a, b) => {
          const aNum = parseInt(a.id.replace(/[^0-9]/g, '')) || 0;
          const bNum = parseInt(b.id.replace(/[^0-9]/g, '')) || 0;
          return aNum - bNum;
        });
        
        this.allCards.sort((a, b) => {
          const aNum = parseInt(a.id.replace(/[^0-9]/g, '')) || 0;
          const bNum = parseInt(b.id.replace(/[^0-9]/g, '')) || 0;
          return aNum - bNum;
        });

        onProgress?.(`🎉 成功添加 ${newCards.length} 张新卡!`);
        
        await this.saveNewCardsToPrefs();
        await this.prefStore!.put(Constants.PREFS_KEY_LAST_CARD_ID, lastCardId.toString());
        onProgress?.(`📝 已保存最后卡牌ID: ${lastCardId}`);
      } else {
        onProgress?.('✅ 完成: 本地数据已是最新');
      }
    } catch (e) {
      onProgress?.(`❌ 更新失败: ${e}`);
    }
  }

  private async fetchCardData(id: string): Promise<CardData | null> {
    try {
      const response = await NetUtils.get(`${Constants.CARD_LIST_URL}${id}/`);
      
      if (response.statusCode !== 200) {
        return null;
      }

      const html = response.body;
      
      const titleMatch = html.match(/<title[^>]*>([^<]+)<\/title>/i);
      const pageTitle = titleMatch ? titleMatch[1] : '';
      
      if (pageTitle === '卡牌详情 | Moesekai' || pageTitle === 'カード詳細 | Moesekai') {
        return null;
      }

      const ogImageMatch = html.match(/<meta[^>]+property="og:image"[^>]+content="([^"]+)"/i);
      const ogImageUrl = ogImageMatch ? ogImageMatch[1] : '';
      
      if (ogImageUrl.includes('pjsk.moe/data/icon/icon.jpg')) {
        return null;
      }

      let character = '';
      let normalUrl = '';
      let afterUrl = '';
      let resourceId = id;
      let cardName = '';

      if (ogImageMatch) {
        const resourceIdMatch = ogImageUrl.match(/res(\d+)_no(\d+)/);
        if (resourceIdMatch) {
          const resNum = resourceIdMatch[1].padStart(3, '0');
          const noNum = resourceIdMatch[2].padStart(3, '0');
          resourceId = `res${resNum}_no${noNum}`;
          character = Constants.RES_TO_CHARACTER[resNum] || '';
          
          normalUrl = `${Constants.CARD_BASE_URL}/${resourceId}/card_normal.webp`;
          afterUrl = `${Constants.CARD_BASE_URL}/${resourceId}/card_after_training.webp`;
        }
      }

      if (resourceId.length < 12) {
        const internalAssetMatch = html.match(/Internal Asset Name\s*([^\n<]+)/i);
        if (internalAssetMatch) {
          const assetName = internalAssetMatch[1].trim();
          const resMatch = assetName.match(/res(\d+)_no(\d+)/);
          if (resMatch) {
            const resNum = resMatch[1].padStart(3, '0');
            const noNum = resMatch[2].padStart(3, '0');
            resourceId = `res${resNum}_no${noNum}`;
            character = Constants.RES_TO_CHARACTER[resNum] || '';
            normalUrl = `${Constants.CARD_BASE_URL}/${resourceId}/card_normal.webp`;
            afterUrl = `${Constants.CARD_BASE_URL}/${resourceId}/card_after_training.webp`;
          }
        }
      }

      if (!normalUrl) {
        const resMatch = resourceId.match(/res(\d+)_no(\d+)/);
        if (resMatch) {
          const resNum = resMatch[1].padStart(3, '0');
          const noNum = resMatch[2].padStart(3, '0');
          normalUrl = `${Constants.CARD_BASE_URL}/res${resNum}_no${noNum}/card_normal.webp`;
          afterUrl = `${Constants.CARD_BASE_URL}/res${resNum}_no${noNum}/card_after_training.webp`;
        }
      }

      if (!normalUrl) {
        return null;
      }

      let rarity = -1;
      const starMatch = html.match(/(\d+)★/);
      const cnStarMatch = html.match(/(\d+)星/);
      const raritySpanMatch = html.match(/rarity-(\d)/);
      
      if (starMatch) {
        rarity = parseInt(starMatch[1]) || -1;
      } else if (cnStarMatch) {
        rarity = parseInt(cnStarMatch[1]) || -1;
      } else if (raritySpanMatch) {
        rarity = parseInt(raritySpanMatch[1]) || -1;
      }

      if (rarity === -1) {
        const birthdayMatch = html.match(/birthday/i);
        if (birthdayMatch) {
          rarity = 4;
        }
      }

      if (rarity === -1) {
        rarity = 3;
      }

      if (!cardName && titleMatch) {
        const title = titleMatch[1].trim();
        const parts = title.split(' - ');
        if (parts.length >= 3) {
          cardName = parts[1].trim();
        } else if (parts.length === 2) {
          cardName = parts[1].trim();
        }
      }

      const isBirthdayCard = cardName.toLowerCase().includes('birthday') || html.toLowerCase().includes('birthday');
      let displayName = '';
      
      if (cardName) {
        if (isBirthdayCard) {
          displayName = `生日 ${cardName}`;
        } else {
          displayName = `${rarity}星 ${cardName}`;
        }
      } else {
        displayName = `${rarity}星`;
      }

      return new CardData(resourceId, character, rarity, normalUrl, afterUrl || normalUrl, displayName);
    } catch (e) {
      return null;
    }
  }

  private async saveNewCardsToPrefs(): Promise<void> {
    try {
      await this.initPreferences();
      const cardsJson = this.allCards.map(c => c.toJson());
      await this.prefStore!.put(Constants.PREFS_KEY_NEW_CARDS, JSON.stringify(cardsJson));
    } catch (e) {
      // ignore
    }
  }

  getRandomCard(): CardData | null {
    if (this.validCards.length === 0) return null;
    const index = Math.floor(Math.random() * this.validCards.length);
    return this.validCards[index];
  }

  getRandomCardExcludeRarity2(): CardData | null {
    const filtered = this.validCards.filter(c => c.rarity !== 2);
    if (filtered.length === 0) return this.getRandomCard();
    const index = Math.floor(Math.random() * filtered.length);
    return filtered[index];
  }

  isCorrectCharacter(card: CardData, character: string): boolean {
    return card.character === character;
  }

  get allCharacters(): string[] {
    return Constants.CHARACTER_ORDER;
  }

  private delay(ms: number): Promise<void> {
    return new Promise(resolve => setTimeout(resolve, ms));
  }
}
