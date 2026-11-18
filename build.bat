@echo off
cd /d "%~dp0"
echo 正在打包...
pyinstaller --onedir --windowed --add-data "bilibili_mv_videos.json;." --name "MV随机播放器" random_video_player.py
echo 打包完成！
pause