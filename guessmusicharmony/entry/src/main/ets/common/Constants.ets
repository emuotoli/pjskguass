export class Constants {
  static readonly PJSK_MOE_BASE_URL: string = 'https://pjsk.moe';
  static readonly PJSK_API_BASE_URL: string = 'https://storage.exmeaning.com/sekai-jp-assets';
  static readonly MUSIC_LIST_URL: string = 'https://pjsk.moe/ja-jp/music/';
  static readonly CARD_LIST_URL: string = 'https://pjsk.moe/ja-JP/cards/';
  static readonly AUDIO_BASE_URL: string = 'https://storage.exmeaning.com/sekai-jp-assets/music/long';
  static readonly JACKET_BASE_URL: string = 'https://storage.exmeaning.com/sekai-jp-assets/music/jacket';
  static readonly CARD_BASE_URL: string = 'https://storage.exmeaning.com/sekai-jp-assets/character/member';
  static readonly SITEMAP_URL: string = 'https://pjsk.moe/sitemap.xml';
  static readonly BILI_API_URL: string = 'https://api.bilibili.com';

  static readonly PREFS_KEY_LAST_CARD_ID: string = 'last_card_id';
  static readonly PREFS_KEY_NEW_CARDS: string = 'new_cards_data';
  static readonly PREFS_KEY_LAST_MUSIC_ID: string = 'last_saved_music_id';
  static readonly DEFAULT_LAST_CARD_ID: number = 1421;
  static readonly DEFAULT_LAST_MUSIC_ID: number = 754;

  static readonly CHARACTER_ORDER: string[] = [
    '星乃一歌', '天马咲希', '望月穗波', '日野森志步', '花里实乃理', '桐谷遥',
    '桃井爱莉', '日野森雫', '小豆泽心羽', '白石杏', '东云彰人', '青柳冬弥',
    '天马司', '凤笑梦', '草薙宁宁', '神代类', '宵崎奏', '朝比奈真冬',
    '东云绘名', '晓山瑞希', '初音未来', '镜音铃', '镜音连', '巡音流歌',
    'MEIKO', 'KAITO'
  ];

  static readonly RES_TO_CHARACTER: Record<string, string> = {
    '001': '星乃一歌', '002': '天马咲希', '003': '望月穗波',
    '004': '日野森志步', '005': '花里实乃理', '006': '桐谷遥',
    '007': '桃井爱莉', '008': '日野森雫', '009': '小豆泽心羽',
    '010': '白石杏', '011': '东云彰人', '012': '青柳冬弥',
    '013': '天马司', '014': '凤笑梦', '015': '草薙宁宁',
    '016': '神代类', '017': '宵崎奏', '018': '朝比奈真冬',
    '019': '东云绘名', '020': '晓山瑞希', '021': '初音未来',
    '022': '镜音铃', '023': '镜音连', '024': '巡音流歌',
    '025': 'MEIKO', '026': 'KAITO'
  };
}
