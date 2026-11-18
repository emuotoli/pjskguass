import json
import os
from typing import List, Dict, Optional

from bili_config import get_cookie_string

COOKIES = get_cookie_string()
HEADERS = {
    'Cookie': COOKIES,
    'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
    'Referer': 'https://www.bilibili.com/'
}


def get_video_detail(bvid: str) -> Dict:
    """
    获取单个视频的详细信息
    
    API: https://api.bilibili.com/x/web-interface/view?bvid={bvid}
    
    返回字段说明:
    - bvid: 视频ID
    - title: 标题
    - cover: 封面图URL
    - duration: 时长（秒）
    - view: 播放量
    - danmaku: 弹幕数
    - reply: 评论数
    - favorite: 收藏数
    - coin: 投币数
    - share: 分享数
    - like: 点赞数
    - owner: UP主信息（mid, name, face）
    - description: 视频简介
    - tags: 标签列表
    - pages: 分P信息列表
    - pubdate: 发布时间（时间戳）
    - cid: 第一个分P的cid
    """
    import requests
    url = f'https://api.bilibili.com/x/web-interface/view?bvid={bvid}'
    response = requests.get(url, headers=HEADERS, timeout=30)
    data = response.json()
    
    if data.get('code') == 0:
        v = data['data']
        return {
            'bvid': v.get('bvid'),
            'title': v.get('title'),
            'cover': v.get('pic'),
            'duration': v.get('duration'),
            'view': v.get('stat', {}).get('view'),
            'danmaku': v.get('stat', {}).get('danmaku'),
            'reply': v.get('stat', {}).get('reply'),
            'favorite': v.get('stat', {}).get('favorite'),
            'coin': v.get('stat', {}).get('coin'),
            'share': v.get('stat', {}).get('share'),
            'like': v.get('stat', {}).get('like'),
            'owner': {
                'mid': v.get('owner', {}).get('mid'),
                'name': v.get('owner', {}).get('name'),
                'face': v.get('owner', {}).get('face')
            },
            'description': v.get('desc'),
            'tags': [tag.get('tag') for tag in v.get('tags', [])],
            'pages': [
                {
                    'cid': page.get('cid'),
                    'part': page.get('part'),
                    'duration': page.get('duration'),
                    'page': page.get('page')
                }
                for page in v.get('pages', [])
            ],
            'pubdate': v.get('pubdate'),
            'cid': v.get('cid'),
            'aid': v.get('aid')
        }
    else:
        print(f'Error getting detail for {bvid}: {data.get("message")}')
        return {}


def get_video_play_url(bvid: str, cid: int, qn: int = 80) -> Optional[Dict]:
    """
    获取视频播放地址（用于播放器加载或下载）
    
    API: https://api.bilibili.com/x/player/playurl?bvid={bvid}&cid={cid}&qn={qn}&fnval=4048
    
    参数:
    - bvid: 视频ID
    - cid: 分P的cid
    - qn: 清晰度（32=360P, 64=480P, 80=720P, 112=1080P, 120=1080P+）
    
    返回: DASH格式的音视频流URL
    """
    import requests
    url = f'https://api.bilibili.com/x/player/playurl?bvid={bvid}&cid={cid}&qn={qn}&fnval=4048'
    response = requests.get(url, headers=HEADERS, timeout=30)
    data = response.json()
    
    if data.get('code') == 0:
        dash = data['data'].get('dash', {})
        return {
            'video_streams': [
                {
                    'quality': stream.get('quality'),
                    'width': stream.get('width'),
                    'height': stream.get('height'),
                    'baseUrl': stream.get('baseUrl'),
                    'mimeType': stream.get('mimeType')
                }
                for stream in dash.get('video', [])
            ],
            'audio_streams': [
                {
                    'quality': stream.get('quality'),
                    'baseUrl': stream.get('baseUrl'),
                    'mimeType': stream.get('mimeType')
                }
                for stream in dash.get('audio', [])
            ]
        }
    else:
        print(f'Error getting play url for {bvid} cid={cid}: {data.get("message")}')
        return None


def batch_get_video_details(json_file: str, output_file: str = 'bilibili_video_details.json', limit: int = None) -> List[Dict]:
    """
    批量获取 bilibili_mv_videos.json 中所有视频的详细信息
    
    参数:
    - json_file: 包含视频列表的JSON文件路径
    - output_file: 输出文件路径
    - limit: 限制获取数量（可选，用于测试）
    """
    import time
    
    with open(json_file, 'r', encoding='utf-8') as f:
        videos = json.load(f)
    
    print(f'共 {len(videos)} 个视频待获取信息')
    
    if limit:
        videos = videos[:limit]
        print(f'测试模式，只获取前 {limit} 个')
    
    all_details = []
    
    for i, video in enumerate(videos, 1):
        bvid = video.get('bvid')
        if not bvid:
            continue
        
        print(f'\n进度: {i}/{len(videos)}')
        print(f'获取视频信息: {bvid}')
        
        detail = get_video_detail(bvid)
        if detail:
            all_details.append(detail)
            title = detail.get('title', '')[:30] + '...' if len(detail.get('title', '')) > 30 else detail.get('title', '')
            print(f'  标题: {title}')
            print(f'  播放量: {detail.get("view")}')
            print(f'  弹幕: {detail.get("danmaku")}')
            print(f'  收藏: {detail.get("favorite")}')
        else:
            print(f'  获取失败')
        
        time.sleep(0.5)
    
    with open(output_file, 'w', encoding='utf-8') as f:
        json.dump(all_details, f, ensure_ascii=False, indent=2)
    
    print(f'\n=== 完成 ===')
    print(f'成功获取 {len(all_details)} 个视频的详细信息')
    print(f'保存到: {output_file}')
    
    return all_details


def generate_video_html(details_file: str, output_html: str = 'video_player.html') -> None:
    """
    根据视频详情生成一个HTML播放器页面（示例功能）
    
    生成一个简单的网页，可以浏览所有视频、查看封面和标题、点击播放
    """
    with open(details_file, 'r', encoding='utf-8') as f:
        details = json.load(f)
    
    html = f'''<!DOCTYPE html>
<html lang="zh-CN">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Bilibili MV合集播放器</title>
    <style>
        * {{ margin: 0; padding: 0; box-sizing: border-box; }}
        body {{ font-family: 'Microsoft YaHei', sans-serif; background: #1a1a2e; color: #fff; padding: 20px; }}
        .header {{ text-align: center; margin-bottom: 30px; }}
        .header h1 {{ font-size: 28px; color: #00d4ff; }}
        .header p {{ color: #888; margin-top: 10px; }}
        .video-grid {{ display: grid; grid-template-columns: repeat(auto-fill, minmax(280px, 1fr)); gap: 20px; }}
        .video-card {{ background: #16213e; border-radius: 12px; overflow: hidden; cursor: pointer; transition: transform 0.3s; }}
        .video-card:hover {{ transform: scale(1.02); }}
        .video-cover {{ width: 100%; height: 160px; object-fit: cover; }}
        .video-info {{ padding: 15px; }}
        .video-title {{ font-size: 14px; font-weight: bold; margin-bottom: 8px; display: -webkit-box; -webkit-line-clamp: 2; -webkit-box-orient: vertical; overflow: hidden; }}
        .video-stats {{ font-size: 12px; color: #888; display: flex; gap: 15px; }}
        .player-modal {{ display: none; position: fixed; top: 0; left: 0; width: 100%; height: 100%; background: rgba(0,0,0,0.8); z-index: 1000; }}
        .player-modal.active {{ display: flex; align-items: center; justify-content: center; }}
        .player-container {{ width: 90%; max-width: 1200px; position: relative; }}
        .player-close {{ position: absolute; top: -40px; right: 0; color: #fff; font-size: 24px; cursor: pointer; }}
        .player-info {{ margin-top: 15px; }}
        .player-title {{ font-size: 18px; font-weight: bold; }}
        .player-stats {{ font-size: 14px; color: #888; margin-top: 5px; }}
    </style>
</head>
<body>
    <div class="header">
        <h1>🎵 Project SEKAI 官方MV合集</h1>
        <p>共 {len(details)} 个视频</p>
    </div>
    
    <div class="video-grid">
'''
    
    for video in details:
        html += f'''        <div class="video-card" onclick="openPlayer('{video['bvid']}', '{video['title']}', {video.get('view', 0)}, {video.get('danmaku', 0)})">
            <img src="{video.get('cover', '')}" class="video-cover" alt="{video.get('title', '')}">
            <div class="video-info">
                <div class="video-title">{video.get('title', '')}</div>
                <div class="video-stats">
                    <span>👁️ {video.get('view', 0):,}</span>
                    <span>💬 {video.get('danmaku', 0):,}</span>
                    <span>⭐ {video.get('favorite', 0):,}</span>
                </div>
            </div>
        </div>
'''
    
    html += '''    </div>
    
    <div class="player-modal" id="playerModal">
        <div class="player-container">
            <div class="player-close" onclick="closePlayer()">✕</div>
            <iframe id="bilibiliPlayer" width="100%" height="600" src="" frameborder="0" allowfullscreen></iframe>
            <div class="player-info">
                <div class="player-title" id="playerTitle"></div>
                <div class="player-stats" id="playerStats"></div>
            </div>
        </div>
    </div>
    
    <script>
        function openPlayer(bvid, title, view, danmaku) {
            const player = document.getElementById('bilibiliPlayer');
            player.src = `https://player.bilibili.com/player.html?bvid=${bvid}&page=1