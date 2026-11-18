import requests
import re

def test_sitemap():
    base_url = 'https://pjsk.moe'
    
    print("=== 测试 sitemap 内容 ===")
    response = requests.get(f'{base_url}/sitemap.xml', timeout=10)
    print("sitemap.xml 内容:")
    print(response.text[:2000])
    
    print("\n\n=== 测试 sitemap-details 内容 ===")
    response = requests.get(f'{base_url}/sitemap-details.xml', timeout=10)
    print("sitemap-details.xml 内容:")
    print(response.text[:2000])
    
    print("\n\n=== 测试卡片页面 og:image ===")
    response = requests.get(f'{base_url}/cards/1/', timeout=10)
    og_image = re.search(r'<meta[^>]+property="og:image"[^>]+content="([^"]+)"', response.text, re.IGNORECASE)
    if og_image:
        print(f"og:image: {og_image.group(1)}")
        
        resource_id = re.search(r'res(\d+)_no(\d+)', og_image.group(1))
        if resource_id:
            print(f"资源ID: res{resource_id.group(1)}_no{resource_id.group(2)}")

if __name__ == '__main__':
    test_sitemap()
