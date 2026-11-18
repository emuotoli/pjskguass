# 🎮 Project SEKAI 猜卡面 / 猜音乐 / 猜视频 游戏合集

> 一个围绕《世界计划 缤纷舞台！feat. 初音未来》(Project SEKAI) 的同人娱乐项目合集。
> Repository: [emuotoli/pjskguass](https://github.com/emuotoli/pjskguass)

本项目包含**四个技术支线**与一套数据采集工具链，覆盖移动端、鸿蒙原生、桌面端与 Web 端，核心玩法是根据局部卡面猜角色、根据片段猜歌曲、根据线索猜 MV。

---

## 🗺️ 项目全景

| 支线 | 目录 | 平台 | 技术栈 |
|------|------|------|--------|
| 📱 Flutter 手游 | [`guess_character_game_mobile_new/`](./guess_character_game_mobile_new/) | Android / iOS | Flutter 3.x · Dart 3.x |
| 📟 鸿蒙原生 App | [`guessmusicharmony/`](./guessmusicharmony/) | HarmonyOS | ArkTS · DevEco · SDK 4.0.0(10) |
| 🖥️ B站 MV 播放器 | 根目录 `random_video_player.py` | Windows 桌面 | PyQt5 · yt-dlp · PyInstaller |
| 🌐 B站解析下载工具 | [`bilibili_tool/`](./bilibili_tool/) | Web 浏览器 | 原生 HTML/CSS/JS · Python http.server 代理 |

---

## ✨ 功能亮点

### 📱 Flutter 手游（`guess_character_game_mobile_new`）
- **🃏 猜卡面**：显示卡面局部碎片（10%–60% 可调），从 26 个角色中选出正确答案；答对展示特训前/后完整卡面并计分
- **🎵 猜音乐**：播放歌曲第 9 秒起的 5–10 秒片段，支持日文/英文/中文别名作答；可切换 Vocaloid / セカイ / Instrumental 等多个版本
- **🎬 猜视频**：基于 `video_player` 的视频线索玩法，配有 `mv_videos_matched.json` 数据
- **智能缓存**：`cached_network_image` + `flutter_cache_manager` 图片缓存，`just_audio` 音频播放，`shared_preferences` 保存设置
- **自动更新**：启动时扫描 `pjsk.moe` 站点，增量发现新卡面与新歌曲

### 📟 鸿蒙原生 App（`guessmusicharmony`）
Flutter 版的 HarmonyOS 原生移植，采用 ArkTS 编写，包含：
- `CardGamePage` / `MusicGamePage` / `VideoGamePage` 三大游戏页面
- `CardService` / `MusicService` / `VideoService` 数据服务层
- `NetUtils` 网络工具与 `Constants` 常量定义

### 🖥️ B站 MV 播放器（`random_video_player.py`）
- 基于 **PyQt5** 的桌面 GUI：随机播放、列表管理、进度条、音量控制、状态栏
- 通过 **yt-dlp** 下载 B站视频，支持断点续传与多线程进度显示
- 使用 **PyInstaller** 打包为独立 exe（`build.bat` 一键构建）

### 🌐 B站解析下载工具（`bilibili_tool/`）
- 纯前端页面解析 B站视频，获取封面、信息与下载链接
- Python `http.server` 本地代理（端口 8765）绕过 CORS，并配多级公共代理降级
- 双击 `启动.bat` 即可运行

---

## 🧰 技术栈一览

- **移动端**：Flutter 3.x、Dart 3.x、`http`、`just_audio`、`video_player`、`cached_network_image`、`shared_preferences`、`path_provider`
- **鸿蒙端**：ArkTS、HarmonyOS SDK 4.0.0(10)、DevEco Studio
- **桌面端**：Python 3、PyQt5、yt-dlp、PyInstaller
- **Web 端**：HTML5、CSS3、原生 JavaScript、Python http.server
- **数据采集**：Python `requests` 爬虫，抓取 [pjsk.moe](https://pjsk.moe) 卡面/歌曲数据，资源托管于官方 CDN `storage.exmeaning.com`

---

## 📂 目录结构

```
.
├── guess_character_game_mobile_new/   # Flutter 手游（核心项目）
│   ├── lib/                  # Dart 源码（游戏服务、界面、数据模型）
│   ├── assets/data/          # 卡面/歌曲/视频匹配 JSON 数据
│   ├── assets/photo/         # 猜卡面占位图
│   ├── android/              # Android 原生工程与构建配置
│   └── *.py                  # 数据采集与校验脚本
├── guessmusicharmony/        # HarmonyOS 原生 App（ArkTS）
│   └── entry/src/main/ets/   # 页面 / 服务 / 模型 / 工具
├── bilibili_tool/            # B站解析下载 Web 工具
├── random_video_player.py    # PyQt5 桌面播放器
├── fetch_bilibili*.py        # B站收藏夹采集与下载脚本
├── bili_config.py            # 🔐 统一凭证读取模块
└── cookies.example.json      # 🔐 Cookie 配置模板
```

---

## 🚀 快速开始

### 📱 Flutter 手游
```bash
cd guess_character_game_mobile_new
flutter pub get
flutter run              # 连接设备或模拟器
flutter build apk --release
```

### 📟 鸿蒙 App
用 DevEco Studio 打开 `guessmusicharmony/`，配置签名后运行到 HarmonyOS 设备/模拟器。

### 🖥️ 桌面播放器
```bash
pip install PyQt5 yt-dlp requests
python random_video_player.py
# 一键打包：双击 build.bat
```

### 🌐 B站解析工具
```bash
cd bilibili_tool
python proxy_server.py      # 浏览器访问 http://localhost:8765/
```

---

## 🔐 凭证配置（重要）

本项目**不在代码中硬编码任何账号 Cookie**。B站相关脚本统一通过 `bili_config.py` 读取凭证，按以下优先级：

1. **环境变量** `BILIBILI_COOKIE`（粘贴完整 Cookie 字符串）
   或 `BILIBILI_SESSDATA` / `BILIBILI_BILI_JCT` / `BILIBILI_DEDEUSERID` 三个独立变量
2. **本地文件** `cookies.local.json`（复制 `cookies.example.json` 后填入）

```bash
# 方式一：环境变量（推荐，不落盘）
export BILIBILI_COOKIE="SESSDATA=xxx; bili_jct=xxx; DedeUserID=xxx"

# 方式二：本地文件
cp cookies.example.json cookies.local.json
# 编辑 cookies.local.json 填入真实值
```

> ⚠️ `cookies.local.json` 已在 `.gitignore` 中排除，切勿将真实 Cookie 提交到仓库。

---

## 📊 数据来源

所有卡面、歌曲、MV 数据均来自公开站点 [pjsk.moe](https://pjsk.moe)，图片与音频资源托管于其官方 CDN。本项目仅用于个人娱乐与技术学习，版权归原作品方所有。

---

## 🧭 已知问题

- `fetch_bilibili_video_info.py` 为未完成的草稿文件（HTML 模板字符串未闭合），保留仅作记录，暂不可直接运行。
- 部分老卡面缺少特训后图片；部分歌曲缺少特定版本音频。
- 图片/音频依赖网络加载，建议首次在 Wi-Fi 环境下使用。

---

*本项目为粉丝同人作品，与世界计划官方 (Colorful Palette / Sega / Crypton) 无关联。*
