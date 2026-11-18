export class MusicData {
  id: number;
  title: string;
  titleEn: string;
  composer: string;
  lyricist: string;
  arranger: string;
  fillerSec: number;
  aliases: string[];
  audioUrls: string[];
  versionNames: string[];
  jacketUrl: string;
  category: string;

  constructor(
    id: number = 0,
    title: string = '',
    titleEn: string = '',
    composer: string = '',
    lyricist: string = '',
    arranger: string = '',
    fillerSec: number = 0,
    aliases: string[] = [],
    audioUrls: string[] = [],
    versionNames: string[] = [],
    jacketUrl: string = '',
    category: string = ''
  ) {
    this.id = id;
    this.title = title;
    this.titleEn = titleEn;
    this.composer = composer;
    this.lyricist = lyricist;
    this.arranger = arranger;
    this.fillerSec = fillerSec;
    this.aliases = aliases;
    this.audioUrls = audioUrls;
    this.versionNames = versionNames;
    this.jacketUrl = jacketUrl;
    this.category = category;
  }

  static fromJson(json: Record<string, Object>): MusicData {
    return new MusicData(
      json['id'] as number || 0,
      json['title'] as string || '',
      (json['titleEn'] || json['title_en']) as string || '',
      json['composer'] as string || '',
      json['lyricist'] as string || '',
      json['arranger'] as string || '',
      (json['fillerSec'] as number) || 9.0,
      [],
      [],
      [],
      '',
      ''
    );
  }

  static fromJsonFull(json: Record<string, Object>): MusicData {
    const aliases = json['aliases'] as string[] || [];
    const audioUrls = json['audioUrls'] as string[] || [];
    const versionNames = json['versionNames'] as string[] || [];
    return new MusicData(
      json['id'] as number || 0,
      json['title'] as string || '',
      json['titleEn'] as string || '',
      '', '', '', 0,
      aliases, audioUrls, versionNames,
      json['jacketUrl'] as string || '',
      json['category'] as string || ''
    );
  }

  toJson(): Record<string, Object> {
    return {
      'id': this.id,
      'title': this.title,
      'titleEn': this.titleEn,
      'composer': this.composer,
      'lyricist': this.lyricist,
      'arranger': this.arranger,
      'fillerSec': this.fillerSec,
      'audioUrls': this.audioUrls,
      'versionNames': this.versionNames,
      'jacketUrl': this.jacketUrl,
      'aliases': this.aliases,
      'category': this.category
    };
  }
}
