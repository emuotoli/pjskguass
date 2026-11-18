import json

with open('assets/data/musics_full.json', 'r', encoding='utf-8') as f:
    songs = json.load(f)

song_titles = {s['title'].strip() for s in songs}
song_titles_en = {s['titleEn'].strip() for s in songs if s.get('titleEn')}

all_aliases = set()
for s in songs:
    for a in s.get('aliases', []):
        all_aliases.add(a.strip())

print('歌曲库统计:')
print('  总数:', len(songs))
print('  日文歌名:', len(song_titles))
print('  英文歌名:', len(song_titles_en))
print('  别名:', len(all_aliases))
print()

unmatched_songs = [
    'New Worlds', 'Chu！Future☆Express', 'Positive☆Dance Time', 'Bad Apple!!',
    'Fire◎Flower', '琪露诺的完美算术学园', 'スマイル＊シンフォニー', '1',
    'ラズベリー*モンスター', 'More！Jump！More！', 'Gimme more！', '威风堂堂',
    'Doctor＝FunkBeat', '街', '世界还没有开始', 'どんな結末がお望みだい？',
    'Telecaster-B-boy', 'Cyberpunk Dead Boy', 'Jackpot Sad Girl', '光'
]

for song in unmatched_songs:
    found = False
    if song in song_titles:
        found = True
        print('✓ ' + song + ' (日文歌名)')
    elif song in song_titles_en:
        found = True
        print('✓ ' + song + ' (英文歌名)')
    elif song in all_aliases:
        found = True
        print('✓ ' + song + ' (别名)')
    
    if not found:
        for s in songs:
            titles = [s['title'], s.get('titleEn', '')] + s.get('aliases', [])
            for t in titles:
                if song in t or t in song:
                    print('~ ' + song + ' (部分匹配: ' + s['title'] + ')')
                    found = True
                    break
            if found:
                break
    
    if not found:
        print('✗ ' + song)
