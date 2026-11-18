@echo off
chcp 65001 >nul
cd /d "%~dp0"
title B站视频解析下载工具 - 本地代理

echo ========================================
echo   B站视频解析下载工具 - 启动中...
echo ========================================
echo.

where python >nul 2>nul
if %errorlevel%==0 (
    start "" python proxy_server.py
    exit /b
)

where py >nul 2>nul
if %errorlevel%==0 (
    start "" py proxy_server.py
    exit /b
)

echo [错误] 未找到 Python 环境，请先安装 Python 3.x
echo 下载地址：https://www.python.org/downloads/
echo.
pause
