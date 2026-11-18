import requests
import re

headers = {'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36'}

# Check the ja-jp sitemap for music URLs
print('--- Checking ja-jp sitemap for music entries ---')
r = requests.get('https://pjsk.moe/sitemap-details/ja-jp.xml', headers=headers, timeout=10)
music_matches = re.findall(r'<loc>https://pjsk\.moe/ja-jp/music/(\d+)/</loc>', r.text)
print(f'Total music entries in sitemap: {len(music_matches)}')
if music_matches:
    ids = [int(x) for x in music_matches]
    print(f'Min ID: {min(ids)}, Max ID: {max(ids)}')
    print(f'Last 10 IDs: {ids[-10:]}')

# Also check zh-cn sitemap for comparison
print('\n--- Checking zh-cn sitemap for music entries ---')
r2 = requests.get('https://pjsk.moe/sitemap-details/zh-cn.xml', headers=headers, timeout=10)
music_matches2 = re.findall(r'<loc>https://pjsk\.moe/zh-cn/music/(\d+)/</loc>', r2.text)
print(f'Total music entries in zh-cn: {len(music_matches2)}')
if music_matches2:
    ids2 = [int(x) for x in music_matches2]
    print(f'Min ID: {min(ids2)}, Max ID: {max(ids2)}')

# Check specific new IDs from ja-jp
print('\n--- Checking specific new IDs ---')
for music_id in [770, 771, 772, 773, 774, 775, 776, 777, 778, 779, 780]:
    music_url = f'https://pjsk.moe/ja-jp/music/{music_id}/'
    r3 = requests.get(music_url, headers=headers, timeout=10)
    if r3.status_code == 200:
        og_match = re.search(r'<meta property="og:title" content="([^"]+)"', r3.text)
        title = og_match.group(1) if og_match else 'N/A'
        
        j_url = f'https://storage.exmeaning.com/sekai-jp-assets/music/jacket/jacket_s_{music_id}/jacket_s_{music_id}.webp'
        r4 = requests.head(j_url, headers=headers, timeout=10)
        jacket_ok = r4.status_code == 200
        
        print(f'ID {music_id}: title="{title}", jacket={jacket_ok}')
    else:
        print(f'ID {music_id}: Status={r3.status_code}')