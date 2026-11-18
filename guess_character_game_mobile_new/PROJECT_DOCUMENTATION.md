# Project SEKAI 猜卡面/猜音乐游戏 - 项目文档

## 一、项目概述

### 1.1 项目名称
guess_character_game_mobile_new

### 1.2 项目类型
Flutter 移动端应用（Android/iOS）

### 1.3 项目功能
一款基于 Project SEKAI（世界计划 缤纷舞台！feat. 初音未来）的娱乐小游戏，包含两个主要游戏模式：
- **猜卡面**：根据卡牌局部图片猜角色名称
- **猜音乐**：根据音乐片段猜歌曲名称

### 1.4 核心技术栈
- **框架**: Flutter 3.x
- **语言**: Dart
- **网络请求**: http 包
- **图片缓存**: cached_network_image + flutter_cache_manager
- **音频播放**: just_audio
- **本地存储**: shared_preferences, path_provider

---

## 二、目录结构

```
guess_character_game_mobile_new/
├── android/                    # Android 原生代码和构建配置
│   ├── app/src/main/           # Android 主代码
│   ├── build.gradle.kts        # Gradle 构建配置
│   └── gradle/                 # Gradle 包装器
├── assets/                     # 静态资源目录
│   ├── data/                   # 数据文件（JSON格式）
│   │   ├── cards.json          # 卡面数据（含图片URL）
│   │   ├── extra_cards.json    # 额外卡面数据
│   │   ├── musics.json         # 音乐基础数据
│   │   ├── musics_full.json    # 音乐完整数据（含音频URL）
│   │   ├── music_categories.json # 音乐分类映射
│   │   └── valid_music_ids.json  # 有效音乐ID列表
│   ├── photo/                  # 猜音乐界面占位图片
│   ├── bg_game.png             # 猜卡面背景图
│   ├── bg_home.jpeg            # 首页背景图
│   ├── bg_music.png            # 猜音乐背景图
│   ├── sd.jpg                  # 默认图片
│   ├── kamian.png              # 猜卡面按钮图标
│   └── yinyue.png              # 猜音乐按钮图标
├── build/                      # 构建输出目录（自动生成）
├── lib/                        # Dart 源代码
│   ├── main.dart               # 应用入口
│   ├── constants.dart          # 全局常量定义
│   ├── cache_settings.dart     # 缓存设置管理
│   ├── card_info_map.dart      # 卡面信息映射表（备用数据）
│   ├── card_names.dart         # 卡面名称映射表
│   ├── cards_data.dart         # 卡面ID和角色映射表
│   ├── game_service.dart       # 猜卡面游戏服务（核心逻辑）
│   ├── game_screen.dart        # 猜卡面界面
│   ├── music_game_service.dart # 猜音乐游戏服务（核心逻辑）
│   └── music_game_screen.dart  # 猜音乐界面
├── test/                       # 测试代码
├── pubspec.yaml                # Flutter 依赖配置
└── 若干Python脚本              # 数据爬取和处理工具
```

---

## 三、核心文件详解

### 3.1 lib/main.dart
**功能**: 应用入口，首页界面

**主要内容**:
- `MyApp`: MaterialApp 根组件
- `HomeScreen`: 首页，包含两个游戏入口按钮
  - 「🎴 猜卡面」按钮 → 跳转 `GameScreen`
  - 「🎵 猜音乐」按钮 → 跳转 `MusicGameScreen`
- 更新检测逻辑：启动时自动检测卡面和音乐更新
- 设置对话框：缓存过期时间和最大缓存大小设置

### 3.2 lib/constants.dart
**功能**: 全局常量定义

**关键常量**:
| 常量名 | 值 | 说明 |
|--------|-----|------|
| `PJSK_MOE_BASE_URL` | `https://pjsk.moe` | 数据来源网站基础URL |
| `PJSK_API_BASE_URL` | `https://storage.exmeaning.com/sekai-jp-assets` | 图片/音频CDN基础URL |
| `CARD_IMAGE_BASE_URL` | 同上 | 卡面图片基础URL |
| `CARD_LIST_URL` | `https://pjsk.moe/cards/` | 卡面列表页面URL |
| `MUSIC_LIST_URL` | `https://pjsk.moe/music/` | 音乐列表页面URL |
| `CHARACTER_ORDER` | 26个角色名数组 | 角色显示顺序 |
| `MUSIC_CATEGORIES` | 分类映射 | 音乐分类（Vocaloid/Leo/need等） |

### 3.3 lib/game_service.dart
**功能**: 猜卡面游戏核心服务

**核心类**:
- `CardData`: 卡面数据模型
  - `id`: 卡面ID（格式: res{resNum}_no{noNum}）
  - `character`: 角色名
  - `rarity`: 星级（1-4星）
  - `normalUrl`: 特训前图片URL
  - `afterUrl`: 特训后图片URL
  - `cardName`: 卡面名称

- `GameService`: 卡面服务（单例模式）
  - `loadCards()`: 加载卡面数据
  - `getRandomCard()`: 获取随机卡面
  - `checkForCardUpdatesInBackground()`: 后台检测卡面更新
  - `getCardsForCharacter()`: 获取指定角色的卡面

**数据加载流程**:
1. 优先从 `assets/data/cards.json` 加载
2. 从 `assets/data/extra_cards.json` 加载额外卡面
3. 从 SharedPreferences 加载之前保存的新卡面
4. 通过网络扫描 `pjsk.moe/sitemap.xml` 检测更新

**图片URL格式**:
```
https://storage.exmeaning.com/sekai-jp-assets/character/member/res{resNum}_no{noNum}/card_normal.webp
https://storage.exmeaning.com/sekai-jp-assets/character/member/res{resNum}_no{noNum}/card_after_training.webp
```

### 3.4 lib/game_screen.dart
**功能**: 猜卡面游戏界面

**核心功能**:
- **碎片显示**: 通过缩放和偏移显示卡面局部
- **角色选择**: 26个角色按钮供选择
- **图片预加载**: 提前加载下一张卡的图片（优化切换速度）
- **抽屉功能**: 可浏览所有卡面并直接选择
- **图片下载**: 可下载特训前/后图片到本地

**预加载机制**:
- `_nextCard`: 预加载的下一张卡
- `_nextUseNormalImage`: 预加载卡的图片类型
- `_pickNextCard()`: 随机选卡并调用 `downloadFile()` 缓存图片

### 3.5 lib/music_game_service.dart
**功能**: 猜音乐游戏核心服务

**核心类**:
- `MusicData`: 音乐数据模型
  - `id`: 音乐ID
  - `title`: 日文标题
  - `titleEn`: 英文标题
  - `audioUrls`: 音频URL列表（不同版本）
  - `versionNames`: 版本名称（Vocaloid ver./セカイ ver.等）
  - `jacketUrl`: 封面图片URL
  - `category`: 分类

- `MusicGameService`: 音乐服务
  - `loadMusics()`: 加载音乐数据
  - `getRandomMusic()`: 获取随机音乐
  - `checkForUpdatesInBackground()`: 后台检测音乐更新
  - `isCorrectTitle()`: 验证答案是否正确

**音频URL格式**:
```
https://storage.exmeaning.com/sekai-jp-assets/music/long/{prefix}_{4-digit ID}_01/{prefix}_{4-digit ID}_01.mp3
```
其中 prefix 为: vs(バーチャルver.), se(セカイver.), in(インストver.), an(アナザーver.), so(ソロver.)

**封面图片URL格式**:
```
https://storage.exmeaning.com/sekai-jp-assets/music/jacket/jacket_s_{ID}/jacket_s_{ID}.webp
```

### 3.6 lib/music_game_screen.dart
**功能**: 猜音乐游戏界面

**核心功能**:
- **音频播放**: 使用 just_audio 播放音乐片段
- **试听模式**: 从第9秒开始，截取5-10秒片段
- **完整播放**: 答题后从第9秒开始完整播放
- **版本切换**: 可切换不同版本（Vocaloid/セカイ等）
- **新手模式**: 简化难度
- **抽屉功能**: 可浏览所有歌曲并直接选择

### 3.7 lib/cache_settings.dart
**功能**: 缓存设置管理

**设置项**:
- 缓存过期时间（1天/7天/30天/永不过期）
- 最大缓存大小（10MB/100MB/1GB/无限制）
- 一键清除所有缓存

### 3.8 lib/card_names.dart
**功能**: 卡面名称映射表

将卡面ID（如 res001_no001）映射到卡面名称（如 クールだけど友達想い）

### 3.9 lib/cards_data.dart
**功能**: 卡面基础数据

- `CHARACTER_MAP`: res编号到角色名的映射（001=星乃一歌, 002=天马咲希等）
- `BIRTHDAY_CARD_IDS`: 生日卡ID集合
- `ALL_CARDS`: 所有卡面ID和星级列表

---

## 四、数据获取机制

### 4.1 卡面数据来源

**主数据源**: `https://pjsk.moe/cards/`

**数据获取流程**:
1. 通过 `pjsk.moe/sitemap.xml` 获取所有卡面URL
2. 提取卡面ID（数字ID）
3. 访问每个卡面页面（如 `https://pjsk.moe/cards/1/`）
4. 从页面中提取：
   - `og:image` meta标签获取图片URL
   - `Internal Asset Name` 获取资源ID
   - 页面标题获取卡面名称
   - 星级标识（如 "3★"）

**图片来源**: `storage.exmeaning.com`（pjsk.moe 官方CDN）

### 4.2 音乐数据来源

**主数据源**: `https://pjsk.moe/music/`

**数据获取流程**:
1. 通过 sitemap 获取所有音乐URL
2. 提取音乐ID（数字ID）
3. 访问每个音乐页面获取标题
4. 构造音频URL并验证是否存在
5. 支持的版本类型：
   - `vs_`: バーチャル・シンガーver.
   - `se_`: セカイver.
   - `in_`: インストゥルメンタルver.
   - `an_`: アナザーボーカルver.
   - `so_`: ソロver.

### 4.3 更新机制

**卡面更新**:
- 从网站最大ID扫描到上次保存的停止ID
- 默认起始停止ID: 1421
- 新卡面自动保存到 SharedPreferences

**音乐更新**:
- 从网站最大ID扫描到上次保存的停止ID
- 默认起始停止ID: 754
- 新音乐自动保存到应用文档目录

---

## 五、游戏规则

### 5.1 猜卡面规则

1. 显示一张卡面的局部区域（可调节碎片大小：10%-60%）
2. 用户从26个角色中选择正确的角色
3. 答对：显示完整卡面（特训前+特训后），分数+1
4. 答错：提示"答错了！继续尝试"，可继续选择
5. 可随时查看完整原图或抽取新卡

**预加载机制**:
- 当前卡面加载后，立即预加载下一张卡的图片
- 切换卡面时使用已缓存的图片，实现无缝切换

### 5.2 猜音乐规则

1. 播放一段音乐片段（从第9秒开始，可调节时长5-10秒）
2. 用户输入歌曲名称（支持日文/英文/中文别名）
3. 答对：显示封面图片和正确答案，播放完整音乐
4. 答错：提示错误，播放完整音乐
5. 支持跳过当前题目

**音频截取规则**:
- 截取位置：从第9秒开始（跳过前奏）
- 截取时长：5-10秒（用户可调节）
- 完整播放：从第9秒开始播放完整歌曲

---

## 六、关键要求与约束

### 6.1 数据来源约束
- **仅使用 `pjsk.moe` 网站数据**
- 图片和音频实际存储于 `storage.exmeaning.com`（pjsk.moe 官方CDN）
- 禁止使用其他第三方数据源

### 6.2 卡面相关约束
- 猜卡时排除一二星卡牌（仅显示3星及以上）
- 目录中显示所有卡牌（包括一二星）
- 卡面图片URL格式固定
- 角色名通过 `RES_TO_CHARACTER` 映射表获取

### 6.3 音乐相关约束
- 音乐片段从第9秒开始截取
- 支持多版本音频（Vocaloid/セカイ/Instrumental等）
- 封面图片使用格式 `jacket_s_{ID}`

### 6.4 技术约束
- 图片使用 `CachedNetworkImage` 缓存
- 音频使用 `just_audio` 播放
- 本地数据使用 `shared_preferences` 和文件存储

---

## 七、项目运行

### 7.1 环境要求
- Flutter SDK 3.x
- Dart SDK 3.x
- Android Studio 或 VS Code

### 7.2 依赖安装
```bash
flutter pub get
```

### 7.3 运行项目
```bash
# 运行在连接的设备或模拟器
flutter run

# 构建APK
flutter build apk

# 构建release版本
flutter build apk --release
```

### 7.4 首次运行
- 应用启动时会自动加载本地数据
- 同时后台检测更新
- 更新信息显示在首页右上角菜单中

---

## 八、注意事项

### 8.1 网络依赖
- 游戏需要网络连接加载图片和音频
- 首次运行需要下载大量图片和音频，建议在Wi-Fi环境下使用
- 图片和音频会自动缓存，后续使用无需重复下载

### 8.2 缓存管理
- 默认缓存过期时间：3650天（约10年）
- 可在设置中调整缓存策略
- 清除缓存后需要重新下载所有资源

### 8.3 数据更新
- 每次启动应用会自动检测更新
- 新卡面和新歌会自动添加
- 更新进度显示在首页右上角日志面板中

### 8.4 已知问题
- 部分老卡面可能没有特训后图片
- 部分歌曲可能缺少某些版本的音频
- 网络不稳定时图片加载可能失败，会自动重试

---

## 九、后续项目开发建议

### 9.1 新增功能建议
- [ ] 添加游戏计分和排行榜
- [ ] 添加成就系统
- [ ] 支持卡面收藏功能
- [ ] 添加音效和背景音乐
- [ ] 支持主题切换（深色/浅色模式）

### 9.2 代码优化建议
- [ ] 使用 Provider 或 Riverpod 进行状态管理
- [ ] 添加错误边界处理
- [ ] 实现图片懒加载
- [ ] 添加单元测试和集成测试
- [ ] 优化网络请求（并发控制、重试机制）

### 9.3 数据管理建议
- [ ] 定期清理无效缓存
- [ ] 实现数据增量更新
- [ ] 添加数据备份和恢复功能
- [ ] 优化本地数据库存储（使用 sqflite）

---

## 十、联系信息

项目开发者：用户
数据来源：[https://pjsk.moe](https://pjsk.moe)

---

*文档创建日期：2026年7月18日*