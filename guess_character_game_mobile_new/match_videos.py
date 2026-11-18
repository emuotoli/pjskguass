import json
import re

def load_json(filepath):
    with open(filepath, 'r', encoding='utf-8') as f:
        return json.load(f)

def save_json(data, filepath):
    with open(filepath, 'w', encoding='utf-8') as f:
        json.dump(data, f, ensure_ascii=False, indent=2)

def extract_potential_titles(title):
    titles = []
    
    bracket_patterns = [
        r'【([^【】]+?)】',
        r'「([^「」]+?)」',
        r'『([^『』]+?)』',
        r'\(([^()]+?)\)',
        r'（([^（）]+?)）',
    ]
    
    for pattern in bracket_patterns:
        matches = re.findall(pattern, title)
        for match in matches:
            if len(match) >= 1 and len(match) <= 60:
                titles.append(match)
    
    prefixes_to_remove = [
        '中文CC字幕', '中文字幕', '中文', '字幕', '动画MV', '2DMV', '3DMV',
        '世界计划', '多彩舞台', '收录曲', '主题原创曲', 'SEKAI ver.', '虚拟歌手ver.',
        '初音ミク', '镜音铃', '镜音连', '镜音リン', '镜音レン', '巡音流歌', '巡音ルカ',
        'MEIKO', 'KAITO', 'Project SEKAI', '游戏主题曲', '一周年纪念曲', '二周年纪念曲',
        '三周年纪念曲', '四周年纪念曲', '国际服', 'feat.初音ミク', '联动翻唱曲',
        '联动曲', '限定', '愚人节限定', '宝矿力水特联动曲', '东南亚区', '特效字幕',
        'PJS字幕组', '八王子P', 'DECO*27', 'いよわ', 'ゆよゆっぺ', 'OSTER project',
        '伊東健人', 'CircusP', '动画', '动画MV', 'MV', '原创曲'
    ]
    
    cleaned = []
    for t in titles:
        is_valid = True
        for prefix in prefixes_to_remove:
            if t == prefix or t.startswith(prefix):
                is_valid = False
                break
        if is_valid:
            cleaned.append(t)
    
    parts = re.split(r'[【】「」『』()（）]', title)
    for part in parts:
        part = part.strip()
        if len(part) >= 1 and len(part) <= 60:
            is_valid = True
            for prefix in prefixes_to_remove:
                if part == prefix or part.startswith(prefix):
                    is_valid = False
                    break
            if is_valid and part not in cleaned:
                cleaned.append(part)
    
    return cleaned

def normalize_text(text):
    text = text.strip()
    text = re.sub(r'\s+', '', text)
    text = text.replace('（', '(').replace('）', ')')
    text = text.replace('「', '[').replace('」', ']')
    text = text.replace('『', '<').replace('』', '>')
    text = text.replace('×', '')
    text = text.replace('×', '')
    text = text.replace('／', '/')
    text = text.replace('、', ',')
    return text

def find_best_match(video_title, songs):
    candidates = extract_potential_titles(video_title)
    normalized_video_title = normalize_text(video_title)
    
    best_match = None
    best_score = 0
    
    for song in songs:
        song_titles = [song['title'], song['titleEn']] + song.get('aliases', [])
        
        for candidate in candidates:
            normalized_candidate = normalize_text(candidate)
            
            for song_title in song_titles:
                normalized_song_title = normalize_text(song_title)
                
                if normalized_candidate == normalized_song_title:
                    return song, 100
                
                if normalized_candidate in normalized_song_title and len(normalized_candidate) >= len(normalized_song_title) * 0.7:
                    score = len(normalized_candidate) / len(normalized_song_title) * 100
                    if score > best_score:
                        best_score = score
                        best_match = song
                
                if normalized_song_title in normalized_candidate and len(normalized_song_title) >= 2:
                    score = len(normalized_song_title) / len(normalized_candidate) * 100
                    if score > best_score:
                        best_score = score
                        best_match = song
                
                if song_title in video_title or video_title in song_title:
                    score = min(len(song_title), len(video_title)) / max(len(song_title), len(video_title)) * 100
                    if score > best_score and score >= 30:
                        best_score = score
                        best_match = song
    
    if best_match and best_score >= 30:
        return best_match, best_score
    
    return None, 0

def main():
    videos_path = '../bilibili_mv_videos.json'
    songs_path = 'assets/data/musics_full.json'
    output_path = 'assets/data/mv_videos_matched.json'
    
    videos = load_json(videos_path)
    songs = load_json(songs_path)
    
    print(f"原始视频数量: {len(videos)}")
    print(f"歌曲数量: {len(songs)}")
    
    filtered_videos = []
    excluded_3dmv = []
    
    for video in videos:
        if '3DMV' in video['title']:
            excluded_3dmv.append(video)
        else:
            filtered_videos.append(video)
    
    print(f"\n2DMV视频数量: {len(filtered_videos)}")
    print(f"3DMV视频数量: {len(excluded_3dmv)}")
    
    all_videos = filtered_videos + excluded_3dmv
    
    matched_videos = []
    unmatched_videos = []
    
    videos_sorted = sorted(all_videos, key=lambda v: len(v['title']))
    
    for video in videos_sorted:
        song, score = find_best_match(video['title'], songs)
        
        if song:
            matched_videos.append({
                'bvid': video['bvid'],
                'title': video['title'],
                'duration': video['duration'],
                'song_id': song['id'],
                'song_title': song['title'],
                'song_title_en': song['titleEn'],
                'match_score': score,
                'is_3dmv': '3DMV' in video['title'],
            })
        else:
            unmatched_videos.append(video)
    
    print(f"\n成功匹配的视频数量: {len(matched_videos)}")
    print(f"未匹配的视频数量: {len(unmatched_videos)}")
    
    save_json(matched_videos, output_path)
    
    print(f"\n匹配结果已保存到: {output_path}")
    
    print("\n=== 部分匹配结果 ===")
    for i, mv in enumerate(matched_videos[:30], 1):
        print(f"{i}. [{mv['song_title']}] ({mv['match_score']:.1f}%) {mv['title'][:70]}...")
    
    print("\n=== 未匹配的视频 ===")
    for i, mv in enumerate(unmatched_videos[:30], 1):
        print(f"{i}. {mv['title']}")

if __name__ == '__main__':
    main()