import { VideoData } from '../model/VideoData';
import { MusicData } from '../model/MusicData';
import { Constants } from '../common/Constants';
import { NetUtils } from '../utils/NetUtils';
import preferences from '@ohos.data.preferences';
import fileIo from '@ohos.file.fs';

export class VideoService {
  private static instance: VideoService | null = null;
  private videos: VideoData[] = [];
  private songs: MusicData[] = [];
  private isLoaded: boolean = false;
  private prefStore: preferences.Preferences | null = null;

  static getInstance(): VideoService {
    if (!VideoService.instance) {
      VideoService.instance = new VideoService();
    }
    return VideoService.instance;
  }

  get allVideos(): VideoData[] {
    return this.videos;
  }

  get loaded(): boolean {
    return this.isLoaded;
  }

  async initPreferences(): Promise<void> {
    if (!this.prefStore) {
      const context = getContext(this);
      this.prefStore = await preferences.getPreferences(context, 'video_prefs');
    }
  }

  async loadData(): Promise<void> {
    await this.loadVideos();
    await this.loadSongs();
    this.isLoaded = true;
  }

  private async loadVideos(): Promise<void> {
    try {
      await this.initPreferences();
      const jsonStr = await this.prefStore!.get('mv_videos_matched', '') as string;
      if (jsonStr && jsonStr.length > 0) {
        const parsed = JSON.parse(jsonStr);
        if (Array.isArray(parsed)) {
          this.videos = parsed.map(item => VideoData.fromJson(item as Record<string, Object>));
        }
      }
    } catch (e) {
      this.videos = [];
    }
  }

  private async loadSongs(): Promise<void> {
    try {
      const jsonStr = await this.prefStore!.get('musics_full_data', '') as string;
      if (jsonStr && jsonStr.length > 0) {
        const parsed = JSON.parse(jsonStr);
        if (Array.isArray(parsed)) {
          this.songs = parsed.map(item => MusicData.fromJsonFull(item as Record<string, Object>));
        }
      }
    } catch (e) {
      this.songs = [];
    }
  }

  getRandomVideo(): VideoData | null {
    if (this.videos.length === 0) return null;
    const index = Math.floor(Math.random() * this.videos.length);
    return this.videos[index];
  }

  getSongForVideo(video: VideoData): MusicData | null {
    return this.songs.find(s => s.id === video.songId) || null;
  }

  isCorrectTitle(video: VideoData, userInput: string): boolean {
    const song = this.getSongForVideo(video);
    if (!song) return false;

    const normalizedInput = this.normalizeText(userInput);
    const allTitles = [song.title, song.titleEn, ...song.aliases];
    
    for (const title of allTitles) {
      if (this.normalizeText(title) === normalizedInput) {
        return true;
      }
    }
    return false;
  }

  private normalizeText(text: string): string {
    return text
      .trim()
      .toLowerCase()
      .replace(/\s+/g, '')
      .replace(/[（）「」『』()，、。！?？]/g, '');
  }

  getVideoCount(): number {
    return this.videos.length;
  }

  async downloadVideo(bvid: string, title: string, onProgress?: (progress: number) => void): Promise<string | null> {
    try {
      const context = getContext(this);
      const dirPath = `${context.filesDir}/mv_videos`;
      const safeTitle = title.replace(/[\\/:*?"<>|]/g, '_');
      const fileName = `${bvid}_${safeTitle}.mp4`;
      const filePath = `${dirPath}/${fileName}`;

      try {
        const stat = fileIo.statSync(filePath);
        if (stat) {
          return filePath;
        }
      } catch (e) {
        // file doesn't exist, continue download
      }

      // For HarmonyOS, we just try to use the remote URL directly
      // The actual video download from Bilibili requires API calls
      // For now, return null to indicate not available
      return null;
    } catch (e) {
      return null;
    }
  }

  async deleteVideoFile(filePath: string): Promise<void> {
    try {
      fileIo.unlinkSync(filePath);
    } catch (e) {
      // ignore
    }
  }
}
