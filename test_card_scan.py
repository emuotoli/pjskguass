import requests
import re
import json

def test_website_pages():
    base_url = 'https://pjsk.moe'
    
    print("=== 测试不同语言版本 ===")
    
    languages = ['ja-JP', 'zh-CN', 'zh-TW', 'en-US', 'ko-KR']
    
    for lang in languages:
        url = f'{base_url}/{lang}/cards/'
        try:
            response = requests.get(url, timeout=10)
            print(f"\n{url}:")
            print(f"  状态码: {response.status_code}")
            
            if response.status_code == 200:
                html = response.text
                title_match = re.search(r'<title[^>]*>([^<]+)</title>', html, re.IGNORECASE)
                page_title = title_match.group(1) if title_match else ''
                print(f"  标题: {page_title}")
                
                card_count = len(re.findall(r'/cards/(\d+)/', html))
                print(f"  找到卡牌链接数: {card_count}")
                
                if card_count > 0:
                    card_matches = re.findall(r'/cards/(\d+)/', html)
                    card_ids = sorted(set(map(int, card_matches)))
                    print(f"  卡牌ID范围: {card_ids[0]} - {card_ids[-1]}")
                    print(f"  前10个ID: {card_ids[:10]}")
                    
        except Exception as e:
            print(f"\n{url}: 错误 - {e}")

def test_jp_cards_directly():
    print("\n=== 直接测试日服卡牌ID ===")
    
    base_url = 'https://pjsk.moe'
    
    headers = {
        'Accept': 'text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8',
        'Accept-Language': 'ja-JP,ja;q=0.9,en;q=0.8',
        'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
    }
    
    test_ids = [1421, 1422, 1423, 1424, 1425, 1426, 1427, 1428, 1429, 1430, 1431, 1432, 1433]
    
    for card_id in test_ids:
        url = f'{base_url}/ja-JP/cards/{card_id}/'
        try:
            response = requests.get(url, headers=headers, timeout=10)
            print(f"\nID {card_id}:")
            print(f"  URL: {url}")
            print(f"  状态码: {response.status_code}")
            
            if response.status_code == 200:
                html = response.text
                title_match = re.search(r'<title[^>]*>([^<]+)</title>', html, re.IGNORECASE)
                page_title = title_match.group(1) if title_match else ''
                print(f"  标题: {page_title}")
                
                if page_title != '卡牌详情 | Moesekai' and page_title != 'カード詳細 | Moesekai':
                    og_image = re.search(r'<meta[^>]+property="og:image"[^>]+content="([^"]+)"', html, re.IGNORECASE)
                    og_url = og_image.group(1) if og_image else ''
                    print(f"  og:image: {og_url[:80]}")
                    
                    res_no_match = re.search(r'res(\d+)_no(\d+)', og_url)
                    if res_no_match:
                        print(f"  资源ID: res{res_no_match.group(1)}_no{res_no_match.group(2)}")
                        print(f"  ✅ 有效卡牌!")
                else:
                    print(f"  ❌ 无效卡牌")
                    
        except Exception as e:
            print(f"\nID {card_id}: 错误 - {e}")

def test_zh_tw():
    print("\n=== 测试繁体中文版本 ===")
    
    base_url = 'https://pjsk.moe'
    
    headers = {
        'Accept': 'text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8',
        'Accept-Language': 'zh-TW,zh;q=0.9,en;q=0.8',
        'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
    }
    
    test_ids = [1421, 1422, 1423, 1424, 1425, 1426, 1427, 1428, 1429, 1430, 1431, 1432, 1433]
    
    for card_id in test_ids:
        url = f'{base_url}/zh-TW/cards/{card_id}/'
        try:
            response = requests.get(url, headers=headers, timeout=10)
            if response.status_code == 200:
                html = response.text
                title_match = re.search(r'<title[^>]*>([^<]+)</title>', html, re.IGNORECASE)
                page_title = title_match.group(1) if title_match else ''
                
                if page_title != '卡牌详情 | Moesekai':
                    og_image = re.search(r'<meta[^>]+property="og:image"[^>]+content="([^"]+)"', html, re.IGNORECASE)
                    og_url = og_image.group(1) if og_image else ''
                    
                    res_no_match = re.search(r'res(\d+)_no(\d+)', og_url)
                    if res_no_match:
                        print(f"ID {card_id}: ✅ 有效 - {page_title[:30]} - res{res_no_match.group(1)}_no{res_no_match.group(2)}")
        except:
            pass

if __name__ == '__main__':
    test_website_pages()
    test_jp_cards_directly()
    test_zh_tw()
