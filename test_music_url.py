import requests
import re

# Test music page URL
url = 'https://pjsk.moe/ja-jp/music/758/'
headers = {'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36'}
r = requests.get(url, headers=headers, timeout=10)
print(f'Status: {r.status_code}')

# Find title
title_match = re.search(r'<title>([^<]+)</title>', r.text)
print(f'Title: {title_match.group(1) if title_match else "N/A"}')

# Find og:title
og_match = re.search(r'<meta property="og:title" content="([^"]+)"', r.text)
print(f'og:title: {og_match.group(1) if og_match else "N/A"}')

# Check jacket URL
jacket_url = 'https://storage.exmeaning.com/sekai-jp-assets/music/jacket/jacket_s_758/jacket_s_758.webp'
r2 = requests.head(jacket_url, headers=headers, timeout=10)
print(f'Jacket exists: {r2.status_code == 200}')

# Check new song IDs (759, 760, 761, etc.)
print('\n--- Checking new song IDs ---')
for music_id in range(759, 770):
    music_url = f'https://pjsk.moe/ja-jp/music/{music_id}/'
    r3 = requests.get(music_url, headers=headers, timeout=10)
    if r3.status_code == 200:
        t_match = re.search(r'<title>([^<]+)</title>', r3.text)
        title = t_match.group(1) if t_match else 'N/A'
        print(f'ID {music_id}: Status=200, Title={title}')
        
        # Check jacket
        j_url = f'https://storage.exmeaning.com/sekai-jp-assets/music/jacket/jacket_s_{music_id}/jacket_s_{music_id}.webp'
        r4 = requests.head(j_url, headers=headers, timeout=10)
        print(f'  Jacket: {r4.status_code == 200}')
    else:
        print(f'ID {music_id}: Status={r3.status_code}')