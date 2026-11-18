export class VideoData {
  bvid: string;
  title: string;
  duration: number;
  songId: number;
  songTitle: string;
  songTitleEn: string;
  matchScore: number;
  is3dmv: boolean;

  constructor(
    bvid: string = '',
    title: string = '',
    duration: number = 0,
    songId: number = 0,
    songTitle: string = '',
    songTitleEn: string = '',
    matchScore: number = 0,
    is3dmv: boolean = false
  ) {
    this.bvid = bvid;
    this.title = title;
    this.duration = duration;
    this.songId = songId;
    this.songTitle = songTitle;
    this.songTitleEn = songTitleEn;
    this.matchScore = matchScore;
    this.is3dmv = is3dmv;
  }

  static fromJson(json: Record<string, Object>): VideoData {
    return new VideoData(
      json['bvid'] as string || '',
      json['title'] as string || '',
      json['duration'] as number || 0,
      json['song_id'] as number || 0,
      json['song_title'] as string || '',
      json['song_title_en'] as string || '',
      (json['match_score'] as number) || 0,
      json['is_3dmv'] as boolean || false
    );
  }

  toJson(): Record<string, Object> {
    return {
      'bvid': this.bvid,
      'title': this.title,
      'duration': this.duration,
      'song_id': this.songId,
      'song_title': this.songTitle,
      'song_title_en': this.songTitleEn,
      'match_score': this.matchScore,
      'is_3dmv': this.is3dmv
    };
  }
}
