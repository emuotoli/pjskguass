import json

from bili_config import get_cookie_string

season_id = 1547037
mid = 13148307

def extract_videos():
    import requests
    headers = {
        'Cookie': get_cookie_string(),
        'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
        'Referer': 'https://space.bilibili.com/13148307/lists/1547037'
    }
    
    videos = []
    page = 1
    page_size = 50
    total_found = 0
    
    while True:
        url = f'https://api.bilibili.com/x/polymer/web-space/seasons_archives_list?mid={mid}&season_id={season_id}&sort_reverse=false&page_size={page_size}&page_num={page}&web_location=333.1387'
        try:
            response = requests.get(url, headers=headers, timeout=30)
            print(f'\nPage {page}: Status={response.status_code}')
            
            if 'json' in response.headers.get('content-type', ''):
                data = response.json()
                code = data.get('code')
                print(f'  Code: {code}, Message: {data.get("message")}')
                
                if code == 0 and data.get('data'):
                    items = data['data'].get('archives', [])
                    if isinstance(items, list):
                        page_count = len(items)
                        for item in items:
                            if isinstance(item, dict):
                                video = {
                                    'bvid': item.get('bvid'),
                                    'title': item.get('title'),
                                    'duration': item.get('duration'),
                                    'view': item.get('view'),
                                    'aid': item.get('aid'),
                                    'cid': item.get('cid')
                                }
                                videos.append(video)
                        total_found += page_count
                        print(f'  Found {page_count} items, total so far: {total_found}')
                        
                        if page_count < page_size:
                            print('  No more pages')
                            break
                    else:
                        print(f'  No items found in page {page}')
                        break
                else:
                    if page == 1:
                        print(f'  API error: {data.get("message")}')
                        break
                    else:
                        print('  End of pagination')
                        break
            else:
                print(f'  Not JSON response')
                print(f'  Response (first 200 chars): {response.text[:200]}')
                break
        except Exception as e:
            print(f'  Error: {e}')
            break
        page += 1
        if page > 20:
            print('  Reached max pages (20)')
            break
    
    return videos

videos = extract_videos()
print(f'\n=== Total videos found: {len(videos)} ===')

if videos:
    unique_bvids = set(v['bvid'] for v in videos if v['bvid'])
    print(f'Unique BVIDs: {len(unique_bvids)}')
    
    with open('bilibili_mv_videos.json', 'w', encoding='utf-8') as f:
        json.dump(videos, f, ensure_ascii=False, indent=2)
    print('Saved to bilibili_mv_videos.json')
    
    print('\nSample data:')
    for i, v in enumerate(videos[:3], 1):
        print(f'{i}. BVID: {v["bvid"]}, Title: {v["title"][:50]}...')