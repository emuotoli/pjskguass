const String PJSK_MOE_BASE_URL = 'https://pjsk.moe';
const String PJSK_API_BASE_URL = 'https://storage.exmeaning.com/sekai-jp-assets';
const String CARD_IMAGE_BASE_URL = PJSK_API_BASE_URL;

const List<String> CARD_IMAGE_BASE_URLS = [
  'https://storage.exmeaning.com/sekai-jp-assets',
];

const List<String> CHARACTER_IMAGE_PATHS = [
  '/character/member/res{resNum}_no{noNum}/card_normal.webp',
  '/character/member/res{resNum}/card_normal/res{resNum}_no{noNum}.webp',
];

const String MUSIC_LIST_URL = '$PJSK_MOE_BASE_URL/music/';
const String CARD_LIST_URL = '$PJSK_MOE_BASE_URL/cards/';

const Map<String, String> MUSIC_CATEGORIES = {
  'vocaloid': 'Vocaloid',
  'light_music_club': 'Leo/need',
  'idol': 'MORE MORE JUMP!',
  'street': 'Vivid BAD SQUAD',
  'theme_park': 'Wonderlands×Showtime',
  'school_refusal': 'Nightcord at 25:00',
  'other': '其他',
};

const List<String> CHARACTER_ORDER = [
  '星乃一歌', '天马咲希', '望月穗波', '日野森志步', '花里实乃理', '桐谷遥',
  '桃井爱莉', '日野森雫', '小豆泽心羽', '白石杏', '东云彰人', '青柳冬弥',
  '天马司', '凤笑梦', '草薙宁宁', '神代类', '宵崎奏', '朝比奈真冬',
  '东云绘名', '晓山瑞希', '初音未来', '镜音铃', '镜音连', '巡音流歌',
  'MEIKO', 'KAITO'
];
