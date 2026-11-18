import requests
import re

headers = {'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36'}

# Check IDs 770-790 for Astronomicals and other new songs
print('--- Checking more song IDs (770-790) ---')
for music_id in range(770, 791):
    music_url = f'https://pjsk.moe/ja-jp/music/{music_id}/'
    r = requests.get(music_url, headers=headers, timeout=10)
    if r.status_code == 200:
        t_match = re.search(r'<title>([^<]+)</title>', r.text)
        og_match = re.search(r'<meta property="og:title" content="([^"]+)"', r.text)
        title = og_match.group(1) if og_match else (t_match.group(1) if t_match else 'N/A')
        
        # Check jacket
        j_url = f'https://storage.exmeaning.com/sekai-jp-assets/music/jacket/jacket_s_{music_id}/jacket_s_{music_id}.webp'
        r2 = requests.head(j_url, headers=headers, timeout=10)
        jacket_ok = r2.status_code == 200
        
        if jacket_ok and title != '楽曲詳細':
            print(f'ID {music_id}: {title} (jacket: OK)')
        elif title == '楽曲詳細':
            print(f'ID {music_id}: PLACEHOLDER (楽曲詳細), jacket: {jacket_ok}')
        else:
            print(f'ID {music_id}: {title}, jacket: {jacket_ok}')
    else:
        print(f'ID {music_id}: Status={r.status_code}')