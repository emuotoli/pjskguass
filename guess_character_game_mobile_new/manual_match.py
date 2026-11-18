import json

def load_json(filepath):
    with open(filepath, 'r', encoding='utf-8') as f:
        return json.load(f)

def save_json(data, filepath):
    with open(filepath, 'w', encoding='utf-8') as f:
        json.dump(data, f, ensure_ascii=False, indent=2)

def main():
    videos_path = '../bilibili_mv_videos.json'
    songs_path = 'assets/data/musics_full.json'
    matched_path = 'assets/data/mv_videos_matched.json'
    
    videos = load_json(videos_path)
    songs = load_json(songs_path)
    matched = load_json(matched_path)
    
    song_id_map = {s['id']: s for s in songs}
    
    matched_bvids = {v['bvid'] for v in matched}
    unmatched = [v for v in videos if v['bvid'] not in matched_bvids]
    
    print(f'当前未匹配视频数量: {len(unmatched)}')
    print()
    
    manual_mappings = {
        'ラズベリー*モンスター': 705,
        'スマイル＊シンフォニー': 577,
        'Jackpot Sad Girl': 62,
        'Bad Apple!!': 501,
        'More！Jump！More！': 99,
        'Cyberpunk Dead Boy': 452,
        'Positive☆Dance Time': 122,
        'どんな結末がお望みだい？': '独立',
        'Telecaster-B-boy': 134,
        '威风堂堂': 95,
    }
    
    new_matches = []
    still_unmatched = []
    
    for video in unmatched:
        title = video['title']
        matched_song = None
        matched_id = None
        
        for song_name, song_id in manual_mappings.items():
            if song_name in title:
                matched_song = song_name
                matched_id = song_id
                break
        
        if matched_id is not None:
            if matched_id == '独立':
                print(f'✓ {title[:50]}... -> 独立选项 (答案: 结末)')
                new_matches.append({
                    'bvid': video['bvid'],
                    'title': video['title'],
                    'duration': video['duration'],
                    'song_id': 0,
                    'song_title': '结末',
                    'song_title_en': '结末',
                    'match_score': 100,
                    'is_3dmv': '3DMV' in video['title'],
                })
            elif matched_id in song_id_map:
                song = song_id_map[matched_id]
                print(f'✓ {title[:50]}... -> [{song["title"]}] (ID: {matched_id})')
                new_matches.append({
                    'bvid': video['bvid'],
                    'title': video['title'],
                    'duration': video['duration'],
                    'song_id': song['id'],
                    'song_title': song['title'],
                    'song_title_en': song.get('titleEn', ''),
                    'match_score': 100,
                    'is_3dmv': '3DMV' in video['title'],
                })
            else:
                print(f'✗ {title[:50]}... -> 歌曲编号 {matched_id} 不存在')
                still_unmatched.append(video)
        else:
            print(f'✗ {title[:50]}... -> 未找到匹配')
            still_unmatched.append(video)
    
    print(f'\n新增匹配: {len(new_matches)}')
    print(f'仍未匹配: {len(still_unmatched)}')
    
    matched.extend(new_matches)
    save_json(matched, matched_path)
    
    print(f'\n更新完成！总匹配数: {len(matched)}')

if __name__ == '__main__':
    main()
