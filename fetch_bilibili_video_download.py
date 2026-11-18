import json
import os
import re
import subprocess
from typing import List, Dict, Optional

from bili_config import get_cookie_string

COOKIES = get_cookie_string()
HEADERS = {
    'Cookie': COOKIES,
    'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
    'Referer': 'https://www.bilibili.com/'
}


def get_video_info(bvid: str) -> Dict:
    """
    Step 1: 获取视频基本信息（cid、标题、分P信息等）
    API: https://api.bilibili.com/x/web-interface/view?bvid={bvid}
    返回: 包含 title, cid, pages 等字段
    pages: 多分P视频的各个分P信息，每个包含 cid 和 part (分P标题)
    """
    import requests
    url = f'https://api.bilibili.com/x/web-interface/view?bvid={bvid}'
    response = requests.get(url, headers=HEADERS, timeout=30)
    data = response.json()
    
    if data.get('code') == 0:
        video_data = data['data']
        return {
            'bvid': video_data.get('bvid'),
            'title': video_data.get('title'),
            'cid': video_data.get('cid'),           # 第一个分P的cid
            'pages': video_data.get('pages', []),   # 所有分P的列表
            'duration': video_data.get('duration'),
            'owner': video_data.get('owner', {}).get('name', '')
        }
    else:
        print(f'Error getting video info for {bvid}: {data.get("message")}')
        return {}


def get_play_url(bvid: str, cid: int, qn: int = 80) -> Optional[Dict]:
    """
    Step 2: 获取视频播放地址（音视频流URL）
    API: https://api.bilibili.com/x/player/playurl?bvid={bvid}&cid={cid}&qn={qn}&fnval=4048
    
    参数说明:
    - bvid: 视频ID
    - cid: 分P的cid（从view接口获取）
    - qn: 清晰度码率（32=360P, 64=480P, 80=720P, 112=1080P, 120=1080P+）
    - fnval=4048: 请求DASH格式（音视频分离）
    
    返回: DASH格式的音视频流列表，包含 baseUrl (下载地址)
    """
    import requests
    url = f'https://api.bilibili.com/x/player/playurl?bvid={bvid}&cid={cid}&qn={qn}&fnval=4048'
    response = requests.get(url, headers=HEADERS, timeout=30)
    data = response.json()
    
    if data.get('code') == 0:
        dash = data['data'].get('dash', {})
        video_streams = dash.get('video', [])
        audio_streams = dash.get('audio', [])
        
        if video_streams and audio_streams:
            return {
                'video_url': video_streams[0].get('baseUrl'),
                'audio_url': audio_streams[0].get('baseUrl'),
                'video_format': video_streams[0].get('mimeType', ''),
                'audio_format': audio_streams[0].get('mimeType', '')
            }
    else:
        print(f'Error getting play url for {bvid} cid={cid}: {data.get("message")}')
    return None


def download_stream(url: str, save_path: str, timeout: int = 300) -> bool:
    """
    Step 3: 下载音视频流文件
    使用requests流式下载，支持大文件
    """
    import requests
    try:
        response = requests.get(url, headers=HEADERS, stream=True, timeout=timeout)
        response.raise_for_status()
        
        with open(save_path, 'wb') as f:
            for chunk in response.iter_content(chunk_size=8192):
                if chunk:
                    f.write(chunk)
        return True
    except Exception as e:
        print(f'Download failed for {url}: {e}')
        return False


def merge_with_ffmpeg(video_path: str, audio_path: str, output_path: str) -> bool:
    """
    Step 4: 使用FFmpeg合并音视频
    需要先安装FFmpeg并添加到系统PATH
    
    命令: ffmpeg -i video.mp4 -i audio.m4a -c copy output.mp4
    """
    try:
        cmd = [
            'ffmpeg',
            '-i', video_path,
            '-i', audio_path,
            '-c', 'copy',
            '-y',
            output_path
        ]
        result = subprocess.run(cmd, capture_output=True, text=True)
        
        if result.returncode == 0:
            print(f'Merged successfully: {output_path}')
            return True
        else:
            print(f'FFmpeg error: {result.stderr}')
            return False
    except FileNotFoundError:
        print('Error: FFmpeg not found. Please install FFmpeg and add to PATH.')
        return False
    except Exception as e:
        print(f'Merge failed: {e}')
        return False


def sanitize_filename(filename: str) -> str:
    """清理文件名，移除非法字符"""
    return re.sub(r'[\\/:*?"<>|]', '', filename)


def download_single_video(bvid: str, save_dir: str = 'downloads', qn: int = 80) -> None:
    """
    下载单个视频的完整流程
    """
    print(f'\n=== 开始处理: {bvid} ===')
    
    video_info = get_video_info(bvid)
    if not video_info:
        print(f'获取视频信息失败: {bvid}')
        return
    
    title = sanitize_filename(video_info['title'])
    pages = video_info.get('pages', [])
    
    if len(pages) == 0:
        pages = [{'cid': video_info['cid'], 'part': ''}]
    
    for idx, page in enumerate(pages, 1):
        cid = page['cid']
        part_title = page.get('part', '')
        
        if len(pages) > 1:
            full_title = f'{title} - P{idx} {part_title}'
        else:
            full_title = title
        
        print(f'\n处理分P {idx}/{len(pages)}: {full_title}')
        
        play_url = get_play_url(bvid, cid, qn)
        if not play_url:
            print(f'获取播放地址失败')
            continue
        
        os.makedirs(save_dir, exist_ok=True)
        
        video_path = os.path.join(save_dir, f'{full_title}_video.mp4')
        audio_path = os.path.join(save_dir, f'{full_title}_audio.m4a')
        output_path = os.path.join(save_dir, f'{full_title}.mp4')
        
        print(f'下载视频流...')
        if not download_stream(play_url['video_url'], video_path):
            continue
        
        print(f'下载音频流...')
        if not download_stream(play_url['audio_url'], audio_path):
            continue
        
        print(f'合并音视频...')
        if merge_with_ffmpeg(video_path, audio_path, output_path):
            os.remove(video_path)
            os.remove(audio_path)
            print(f'已完成: {output_path}')
        else:
            print(f'合并失败，保留临时文件')


def batch_download_from_json(json_file: str, save_dir: str = 'downloads', qn: int = 80, limit: int = None) -> None:
    """
    批量下载 bilibili_mv_videos.json 中的所有视频
    
    参数:
    - json_file: 包含视频列表的JSON文件路径
    - save_dir: 保存目录
    - qn: 清晰度（32/64/80/112/120）
    - limit: 限制下载数量（可选，用于测试）
    """
    with open(json_file, 'r', encoding='utf-8') as f:
        videos = json.load(f)
    
    print(f'共 {len(videos)} 个视频待下载')
    
    if limit:
        videos = videos[:limit]
        print(f'测试模式，只下载前 {limit} 个')
    
    for i, video in enumerate(videos, 1):
        bvid = video.get('bvid')
        if not bvid:
            continue
        
        print(f'\n{"="*50}')
        print(f'进度: {i}/{len(videos)}')
        download_single_video(bvid, save_dir, qn)


if __name__ == '__main__':
    print('='*60)
    print('Bilibili视频下载工具 - 使用说明')
    print('='*60)
    print()
    print('使用方式:')
    print('1. 下载单个视频:')
    print('   download_single_video("BV1234567890", save_dir="downloads", qn=80)')
    print()
    print('2. 批量下载合集视频:')
    print('   batch_download_from_json("bilibili_mv_videos.json", save_dir="downloads", qn=80)')
    print()
    print('3. 测试下载前N个:')
    print('   batch_download_from_json("bilibili_mv_videos.json", save_dir="downloads", qn=80, limit=5)')
    print()
    print('参数说明:')
    print('   qn (清晰度): 32=360P, 64=480P, 80=720P, 112=1080P, 120=1080P+')
    print('   save_dir: 视频保存目录，默认 "downloads"')
    print()
    print('注意事项:')
    print('   1. 需要安装 requests 库: pip install requests')
    print('   2. 需要安装 FFmpeg 并添加到系统 PATH')
    print('   3. 当前Cookie有效期至2027年，过期后需更新COOKIES变量')
    print('   4. 大批量下载请注意速率限制，建议添加延时')
    print('='*60)
    print()
    print('当前脚本仅作说明用途，未自动执行下载。')
    print('请取消下方注释后运行:')
    
    # 取消注释以下代码来执行下载
    # batch_download_from_json('bilibili_mv_videos.json', save_dir='downloads', qn=80, limit=1)