import { MusicData } from '../model/MusicData';
import { Constants } from '../common/Constants';
import { NetUtils } from '../utils/NetUtils';
import preferences from '@ohos.data.preferences';

export class MusicService {
  private static instance: MusicService | null = null;
  private musics: MusicData[] = [];
  private loadError: string | null = null;
  private recentPlayedIds: Set<string> = new Set();
  private maxRecentPlayed: number = 50;
  private prefStore: preferences.Preferences | null = null;

  static getInstance(): MusicService {
    if (!MusicService.instance) {
      MusicService.instance = new MusicService();
    }
    return MusicService.instance;
  }

  get isLoaded(): boolean {
    return this.musics.length > 0;
  }

  get musicCount(): number {
    return this.musics.length;
  }

  get allMusics(): MusicData[] {
    return this.musics;
  }

  get hasMusics(): boolean {
    return this.musics.length > 0;
  }

  get error(): string | null {
    return this.loadError;
  }

  async initPreferences(): Promise<void> {
    if (!this.prefStore) {
      const context = getContext(this);
      this.prefStore = await preferences.getPreferences(context, 'music_prefs');
    }
  }

  async loadMusics(onProgress?: (msg: string) => void): Promise<void> {
    this.loadError = null;
    this.musics = [];
    await this.loadMusicsLocalOnly(onProgress);
    
    if (this.musics.length > 0) {
      await this.assignCategories(onProgress);
      await this.checkForUpdates(onProgress);
    } else {
      onProgress?.('🎵 本地无数据，无法自动加载新歌');
    }
  }

  async loadMusicsLocalOnly(onProgress?: (msg: string) => void): Promise<void> {
    try {
      await this.initPreferences();
      this.musics = [];
      
      const jsonStr = await this.prefStore!.get('musics_full_data', '') as string;
      if (jsonStr && jsonStr.length > 0) {
        const parsed = JSON.parse(jsonStr);
        if (Array.isArray(parsed)) {
          for (const item of parsed) {
            try {
              this.musics.push(MusicData.fromJsonFull(item as Record<string, Object>));
            } catch (e) {
              // skip invalid items
            }
          }
        }
        onProgress?.(`🎵 从本地加载: ${this.musics.length} 首`);
      } else {
        onProgress?.('🎵 本地无音乐数据');
      }
      
      this.musics = this.musics.filter(m => m.id > 0 && m.title.length > 0);
      onProgress?.(`🎵 加载完成: ${this.musics.length} 首`);
    } catch (e) {
      this.loadError = `加载音乐数据失败: ${e}`;
      onProgress?.(`🎵 ${this.loadError}`);
    }
  }

  async saveMusicsToLocal(onProgress?: (msg: string) => void): Promise<void> {
    try {
      await this.initPreferences();
      const jsonList = this.musics.map(m => m.toJson());
      await this.prefStore!.put('musics_full_data', JSON.stringify(jsonList));
      await this.prefStore!.flush();
      onProgress?.(`🎵 已保存 ${this.musics.length} 首到本地`);
    } catch (e) {
      onProgress?.(`🎵 保存失败: ${e}`);
    }
  }

  private async checkForUpdates(onProgress?: (msg: string) => void): Promise<void> {
    try {
      onProgress?.('获取网站地图...');
      
      const sitemapResponse = await NetUtils.get(Constants.SITEMAP_URL);
      if (sitemapResponse.statusCode !== 200) {
        onProgress?.(`获取sitemap失败 (${sitemapResponse.statusCode})`);
        return;
      }

      const sitemapXml = sitemapResponse.body;
      
      const jpDetailsRegex = /<loc>(https:\/\/pjsk\.moe\/sitemap-details\/ja-jp\.xml)<\/loc>/;
      const jpMatch = sitemapXml.match(jpDetailsRegex);
      const detailsUrl = jpMatch ? jpMatch[1] : 'https://pjsk.moe/sitemap-details/ja-jp.xml';
      
      onProgress?.(`获取详细地图: ${detailsUrl}`);
      const detailsResponse = await NetUtils.get(detailsUrl);
      
      if (detailsResponse.statusCode !== 200) {
        onProgress?.(`获取sitemap-details失败`);
        return;
      }

      const detailsXml = detailsResponse.body;
      onProgress?.(`详细地图大小: ${detailsXml.length} 字节`);

      const locRegex = /<loc>https:\/\/pjsk\.moe\/(?:ja-jp\/)?music\/(\d+)\/<\/loc>/g;
      const siteIds: number[] = [];
      let match: RegExpExecArray | null;
      
      while ((match = locRegex.exec(detailsXml)) !== null) {
        const id = parseInt(match[1]);
        if (id > 0) {
          siteIds.push(id);
        }
      }

      siteIds.sort((a, b) => b - a);

      const existingIds = new Set(this.musics.map(m => m.id));
      onProgress?.(`网站共有 ${siteIds.length} 首歌 (最大ID: ${siteIds[0] || 'N/A'})`);

      await this.initPreferences();
      let lastSavedId = parseInt(await this.prefStore!.get(Constants.PREFS_KEY_LAST_MUSIC_ID, '754') as string);
      
      if (!lastSavedId || lastSavedId <= 0) {
        lastSavedId = Constants.DEFAULT_LAST_MUSIC_ID;
        await this.prefStore!.put(Constants.PREFS_KEY_LAST_MUSIC_ID, '754');
        onProgress?.(`首次扫描, 默认停止ID: 754`);
      }

      onProgress?.(`上次保存ID: ${lastSavedId}`);

      const newMusics: MusicData[] = [];
      let scannedCount = 0;

      for (let i = 0; i < siteIds.length; i++) {
        const currentId = siteIds[i];
        
        if (currentId === lastSavedId) {
          onProgress?.(`✓ ID ${currentId} - 达到上次保存位置, 停止扫描 (共扫描${scannedCount}个)`);
          break;
        }

        if (existingIds.has(currentId)) {
          scannedCount++;
          continue;
        }

        scannedCount++;
        onProgress?.(`🔍 扫描 ID ${currentId} (第${scannedCount}个)...`);
        
        const music = await this.fetchMusicData(currentId, '');
        if (music) {
          newMusics.push(music);
          existingIds.add(currentId);
          onProgress?.(`✅ ID ${currentId} - 发现新歌: ${music.title}`);
        } else {
          onProgress?.(`❌ ID ${currentId} - 获取失败`);
        }

        await this.delay(100);
      }

      if (newMusics.length > 0) {
        this.musics.push(...newMusics);
        this.musics.sort((a, b) => b.id - a.id);

        await this.saveMusicsToLocal(onProgress);
        
        if (siteIds.length > 0) {
          await this.prefStore!.put(Constants.PREFS_KEY_LAST_MUSIC_ID, siteIds[0].toString());
        }

        onProgress?.(`🎉 成功添加 ${newMusics.length} 首新歌!`);
        onProgress?.(`当前总数: ${this.musics.length} 首`);
      } else {
        onProgress?.('完成: 本地数据已是最新');
        if (siteIds.length > 0) {
          await this.prefStore!.put(Constants.PREFS_KEY_LAST_MUSIC_ID, siteIds[0].toString());
        }
      }
    } catch (e) {
      onProgress?.(`音乐更新错误: ${e}`);
    }
  }

  private async fetchMusicData(id: number, category: string): Promise<MusicData | null> {
    try {
      const paddedId4 = id.toString().padStart(4, '0');
      const jacketUrl = `${Constants.JACKET_BASE_URL}/jacket_s_${id}/jacket_s_${id}.webp`;

      const jacketExists = await NetUtils.head(jacketUrl);
      if (!jacketExists) {
        return null;
      }

      const url = `${Constants.MUSIC_LIST_URL}${id}/`;
      const response = await NetUtils.get(url);

      if (response.statusCode !== 200) {
        return null;
      }

      const html = response.body;

      let title = '';
      const ogTitleMatch = html.match(/<meta property="og:title" content="([^"]+)"/);
      if (ogTitleMatch) {
        title = ogTitleMatch[1].trim();
      }

      if (!title) {
        const titleMatch = html.match(/<title>([^<]+)<\/title>/);
        if (titleMatch) {
          title = titleMatch[1].trim().replace(' | Moesekai', '');
        }
      }

      if (!title) {
        return null;
      }

      const audioUrls: string[] = [];
      const versionNames: string[] = [];

      const audioPatterns = [
        { prefix: 'vs', name: 'バーチャル・シンガーver.' },
        { prefix: 'se', name: 'セカイver.' }
      ];

      for (const pattern of audioPatterns) {
        const suffixStr = '01';
        const audioUrl = `${Constants.AUDIO_BASE_URL}/${pattern.prefix}_${paddedId4}_${suffixStr}/${pattern.prefix}_${paddedId4}_${suffixStr}.mp3`;
        if (await NetUtils.head(audioUrl)) {
          audioUrls.push(audioUrl);
          versionNames.push(pattern.name);
        }
      }

      if (audioUrls.length === 0) {
        return null;
      }

      const aliases: string[] = [title, title.toLowerCase()];
      const finalCategory = category || 'other';

      return new MusicData(
        id, title, '', '', '', '', 0,
        aliases, audioUrls, versionNames, jacketUrl, finalCategory
      );
    } catch (e) {
      return null;
    }
  }

  private async assignCategories(onProgress?: (msg: string) => void): Promise<void> {
    try {
      await this.initPreferences();
      const categoriesJson = await this.prefStore!.get('music_categories', '') as string;
      if (!categoriesJson) {
        onProgress?.('🎵 无分类数据');
        return;
      }

      const parsed = JSON.parse(categoriesJson);
      const categoryMap = parsed.categoryMap || parsed;
      
      for (const music of this.musics) {
        const category = categoryMap[music.id.toString()] || categoryMap[music.title];
        if (category && typeof category === 'string') {
          music.category = category;
        }
        if (!music.category) {
          music.category = 'other';
        }
      }
      onProgress?.('🎵 已分配分类');
    } catch (e) {
      onProgress?.(`🎵 分配分类失败: ${e}`);
    }
  }

  searchMusics(query: string): MusicData[] {
    if (!query) return this.musics;
    const lowerQuery = query.toLowerCase();
    return this.musics.filter(m =>
      m.title.toLowerCase().includes(lowerQuery) ||
      m.titleEn.toLowerCase().includes(lowerQuery) ||
      m.aliases.some(a => a.toLowerCase().includes(lowerQuery))
    );
  }

  getRandomMusic(beginnerMode: boolean = false): MusicData | null {
    if (this.musics.length === 0) return null;
    
    let candidates = this.musics;
    if (beginnerMode) {
      candidates = this.musics.filter(m => m.audioUrls.length > 0);
    }
    if (candidates.length === 0) {
      candidates = this.musics;
    }
    
    const index = Math.floor(Math.random() * candidates.length);
    return candidates[index];
  }

  isCorrectTitle(music: MusicData, userInput: string): boolean {
    if (!userInput) return false;
    const lowerInput = userInput.toLowerCase();
    
    if (music.title.toLowerCase().includes(lowerInput)) return true;
    if (music.titleEn.toLowerCase().includes(lowerInput)) return true;
    for (const alias of music.aliases) {
      if (alias.toLowerCase().includes(lowerInput)) return true;
    }
    return false;
  }

  markMusicPlayed(musicId: string): void {
    this.recentPlayedIds.add(musicId);
    if (this.recentPlayedIds.size > this.maxRecentPlayed) {
      const first = this.recentPlayedIds.values().next().value;
      this.recentPlayedIds.delete(first);
    }
  }

  hasRecentPlayed(musicId: string): boolean {
    return this.recentPlayedIds.has(musicId);
  }

  getMusicById(id: number): MusicData | null {
    return this.musics.find(m => m.id === id) || null;
  }

  private delay(ms: number): Promise<void> {
    return new Promise(resolve => setTimeout(resolve, ms));
  }
}
