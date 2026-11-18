import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';



const String AUDIO_BASE_URL = 'https://storage.exmeaning.com/sekai-jp-assets/music/long';
const String JACKET_BASE_URL = 'https://storage.exmeaning.com/sekai-jp-assets/music/jacket';
const String MUSIC_LIST_URL = 'https://pjsk.moe/ja-jp/music/';


class MusicData {
  final int id;
  final String title;
  final String titleEn;
  final String composer;
  final String lyricist;
  final String arranger;
  final double fillerSec;
  final List<String> aliases;
  final List<String> audioUrls;
  final List<String> versionNames;
  final String jacketUrl;
  String category;

  MusicData({
    required this.id,
    required this.title,
    this.titleEn = '',
    this.composer = '',
    this.lyricist = '',
    this.arranger = '',
    this.fillerSec = 0,
    this.aliases = const [],
    this.audioUrls = const [],
    this.versionNames = const [],
    this.jacketUrl = '',
    this.category = '',
  });

  factory MusicData.fromJson(Map<String, dynamic> json) {
    final titleEn = json['titleEn'] ?? json['title_en'] ?? '';
    return MusicData(
      id: json['id'] ?? 0,
      title: json['title'] ?? '',
      titleEn: titleEn,
      composer: json['composer'] ?? '',
      lyricist: json['lyricist'] ?? '',
      arranger: json['arranger'] ?? '',
      fillerSec: json['fillerSec']?.toDouble() ?? 9.0,
    );
  }

  factory MusicData.fromJsonFull(Map<String, dynamic> json) {
    return MusicData(
      id: json['id'] ?? 0,
      title: json['title'] ?? '',
      titleEn: json['titleEn'] ?? '',
      audioUrls: List<String>.from(json['audioUrls'] ?? []),
      versionNames: List<String>.from(json['versionNames'] ?? []),
      jacketUrl: json['jacketUrl'] ?? '',
      aliases: List<String>.from(json['aliases'] ?? []),
      category: json['category'] ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'titleEn': titleEn,
      'composer': composer,
      'lyricist': lyricist,
      'arranger': arranger,
      'fillerSec': fillerSec,
      'audioUrls': audioUrls,
      'versionNames': versionNames,
      'jacketUrl': jacketUrl,
      'aliases': aliases,
      'category': category,
    };
  }
}

class MusicGameService {
  final List<MusicData> _musics = [];
  String? _loadError;
  final Set<String> _recentPlayedIds = {};
  static const int _maxRecentPlayed = 50;
  final Random _random = Random();

  String? get loadError => _loadError;
  bool get isLoaded => _musics.isNotEmpty;
  int get musicCount => _musics.length;

  List<MusicData> get allMusics => _musics;

  List<String> getAllMusicIds() {
    return _musics.map((music) => music.id.toString()).toList();
  }

  MusicData? getMusicById(int id) {
    try {
      return _musics.firstWhere((music) => music.id == id);
    } catch (_) {
      return null;
    }
  }

  List<String> get allTitles => _musics.map((m) => m.title).toList();
  
  int getMusicCount() {
    return _musics.length;
  }
  
  bool get hasMusics => _musics.isNotEmpty;

  List<MusicData> getMusicsByCategory(String categoryKey) {
    if (categoryKey.isEmpty) return _musics;
    
    if (categoryKey == 'other') {
      return _musics.where((music) => music.category.isEmpty || music.category == 'other').toList();
    }
    
    return _musics.where((music) => music.category == categoryKey).toList();
  }

  Future<void> loadMusics({Function(String)? onProgress}) async {
    _loadError = null;
    _musics.clear();

    await _loadMusicsFromLocal(onProgress: onProgress);

    if (_musics.isNotEmpty) {
      await assignCategories(onProgress: onProgress);
      await _checkForUpdatesInBackground(onProgress: onProgress);
    } else {
      await _loadMusicsFromPjskMoe(onProgress: onProgress);
    }
  }
  
  Future<void> loadMusicsLocalOnly() async {
    _loadError = null;
    _musics.clear();
    
    await _loadMusicsFromLocal();
    
    if (_musics.isNotEmpty) {
      await assignCategories();
    }
  }

  Future<void> saveMusicsToLocal({Function(String)? onProgress}) async {
    try {
      final dir = await getApplicationDocumentsDirectory();
      final file = File('${dir.path}/musics_full_updated.json');

      final jsonList = _musics.map((m) => m.toJson()).toList();
      await file.writeAsString(json.encode(jsonList));

      _reportProgress('🎵 已保存 ${_musics.length} 首到本地', onProgress);
    } catch (e) {
      _reportProgress('🎵 保存失败: $e', onProgress);
    }
  }

  Future<void> _checkForUpdatesInBackground({Function(String)? onProgress}) async {
    try {
      final existingIds = Set<int>.from(_musics.map((m) => m.id));

      _reportProgress('获取网站地图...', onProgress);

      final sitemapResponse = await http.get(Uri.parse('https://pjsk.moe/sitemap.xml'));
      if (sitemapResponse.statusCode != 200) {
        _reportProgress('获取sitemap失败 (${sitemapResponse.statusCode})', onProgress);
        return;
      }

      final sitemapXml = sitemapResponse.body;
      
      // Try to find ja-jp sitemap first, fallback to sitemap-details.xml
      final jpDetailsMatch = RegExp(r'<loc>(https://pjsk\.moe/sitemap-details/ja-jp\.xml)</loc>').firstMatch(sitemapXml);
      final detailsMatch = jpDetailsMatch ?? RegExp(r'<loc>(https://pjsk\.moe/sitemap-details\.xml)</loc>').firstMatch(sitemapXml);
      
      if (detailsMatch == null) {
        _reportProgress('找不到sitemap-details.xml', onProgress);
        return;
      }

      final detailsUrl = detailsMatch.group(1)!;
      _reportProgress('获取详细地图: $detailsUrl', onProgress);

      final detailsResponse = await http.get(Uri.parse(detailsUrl));
      if (detailsResponse.statusCode != 200) {
        _reportProgress('获取sitemap-details失败 (${detailsResponse.statusCode})', onProgress);
        return;
      }

      final detailsXml = detailsResponse.body;
      _reportProgress('详细地图大小: ${detailsXml.length} 字节', onProgress);

      // Match both old format (/music/) and new format (/ja-jp/music/)
      final locRegex = RegExp(r'<loc>https://pjsk\.moe/(?:ja-jp/)?music/(\d+)/</loc>');
      final locMatches = locRegex.allMatches(detailsXml);

      final siteIds = <int>[];
      for (final locMatch in locMatches) {
        final id = int.tryParse(locMatch.group(1) ?? '0') ?? 0;
        if (id > 0) {
          siteIds.add(id);
        }
      }

      siteIds.sort((a, b) => b.compareTo(a));

      _reportProgress('网站共有 ${siteIds.length} 首歌 (最大ID: ${siteIds.isEmpty ? "N/A" : siteIds.first})', onProgress);
      _reportProgress('本地共有 ${existingIds.length} 首歌', onProgress);

      if (siteIds.isEmpty) {
        _reportProgress('完成: 网站无歌曲数据', onProgress);
        return;
      }

      final prefs = await SharedPreferences.getInstance();
      final lastSavedIdStr = prefs.getString('last_saved_music_id');
      var lastSavedId = lastSavedIdStr != null ? int.tryParse(lastSavedIdStr) : null;

      if (lastSavedId == null) {
        lastSavedId = 754;
        await prefs.setString('last_saved_music_id', '754');
        _reportProgress('首次扫描, 默认停止ID: 754', onProgress);
      }

      _reportProgress('上次保存ID: $lastSavedId', onProgress);

      final newMusics = <MusicData>[];
      int scannedCount = 0;

      for (int i = 0; i < siteIds.length; i++) {
        final currentId = siteIds[i];

        if (currentId == lastSavedId) {
          _reportProgress('✓ ID $currentId - 达到上次保存位置, 停止扫描 (共扫描$scannedCount个)', onProgress);
          break;
        }

        if (existingIds.contains(currentId)) {
          scannedCount++;
          continue;
        }

        scannedCount++;
        _reportProgress('🔍 扫描 ID $currentId (第${scannedCount}个)...', onProgress);
        final music = await _fetchMusicData(currentId, '', onProgress);

        if (music != null) {
          newMusics.add(music);
          existingIds.add(currentId);
          _reportProgress('✅ ID $currentId - 发现新歌: ${music.title}', onProgress);
        } else {
          _reportProgress('❌ ID $currentId - 获取失败', onProgress);
        }

        await Future.delayed(const Duration(milliseconds: 100));
      }

      if (newMusics.isNotEmpty) {
        _musics.addAll(newMusics);
        _musics.sort((a, b) => a.id.compareTo(b.id));

        await saveMusicsToLocal(onProgress: onProgress);
        
        if (siteIds.isNotEmpty) {
          await prefs.setString('last_saved_music_id', siteIds.first.toString());
        }

        _reportProgress('🎉 成功添加 ${newMusics.length} 首新歌!', onProgress);
        _reportProgress('当前总数: ${_musics.length} 首', onProgress);
      } else {
        _reportProgress('完成: 本地数据已是最新', onProgress);

        if (siteIds.isNotEmpty) {
          await prefs.setString('last_saved_music_id', siteIds.first.toString());
          _reportProgress('更新停止ID: ${siteIds.first}', onProgress);
        }
      }
    } catch (e) {
      _reportProgress('音乐更新错误: $e', onProgress);
    }
  }
  
  void _reportProgress(String message, Function(String)? onProgress) {
    print(message);
    if (onProgress != null) {
      onProgress(message);
    }
  }

  Future<bool> _loadMusicsFromPjskMoe({Function(String)? onProgress}) async {
    try {
      final categories = ['vocaloid', 'light_music_club', 'idol', 'street', 'theme_park', 'school_refusal', 'other'];

      for (final category in categories) {
        final url = 'https://pjsk.moe/ja-jp/music/?tag=$category';
        _reportProgress('🎵 获取分类: $category', onProgress);
        final response = await http.get(Uri.parse(url));

        if (response.statusCode == 200) {
          final html = response.body;

          final musicLinks = RegExp(r'/ja-jp/music/(\d+)/').allMatches(html);
          final musicIds = <int>{};

          for (final match in musicLinks) {
            final id = int.tryParse(match.group(1) ?? '');
            if (id != null && id > 0) {
              musicIds.add(id);
            }
          }

          _reportProgress('🎵 分类 $category: 找到 ${musicIds.length} 首', onProgress);

          for (final id in musicIds) {
            if (_musics.any((m) => m.id == id)) {
              continue;
            }

            final music = await _fetchMusicData(id, category, onProgress);
            if (music != null) {
              _musics.add(music);
            }
          }
        } else {
          _reportProgress('🎵 分类 $category: HTTP ${response.statusCode}', onProgress);
        }
      }

      _musics.sort((a, b) => a.id.compareTo(b.id));

      _reportProgress('🎵 首次加载完成, 共 ${_musics.length} 首', onProgress);
      return _musics.isNotEmpty;
    } catch (e) {
      _reportProgress('🎵 网络错误: $e', onProgress);
      return false;
    }
  }

  Future<bool> _checkUrlExists(String url) async {
    try {
      final request = http.Request('GET', Uri.parse(url));
      request.headers['Range'] = 'bytes=0-0';
      final response = await request.send();
      return response.statusCode == 200 || response.statusCode == 206;
    } catch (e) {
      return false;
    }
  }

  Future<MusicData?> _fetchMusicData(int id, [String category = '', Function(String)? onProgress]) async {
    try {
      final paddedId4 = id.toString().padLeft(4, '0');

      final jacketUrl = 'https://storage.exmeaning.com/sekai-jp-assets/music/jacket/jacket_s_$id/jacket_s_$id.webp';

      _reportProgress('🎵 ID $id: 检查封面...', onProgress);
      if (!await _checkUrlExists(jacketUrl)) {
        _reportProgress('🎵 ID $id: 封面不存在, 跳过', onProgress);
        return null;
      }

      final url = '$MUSIC_LIST_URL$id/';
      final response = await http.get(Uri.parse(url));

      if (response.statusCode != 200) {
        _reportProgress('🎵 ID $id: HTTP ${response.statusCode}', onProgress);
        return null;
      }

      final html = response.body;

      String title = '';
      final ogTitleMatch = RegExp(r'<meta property="og:title" content="([^"]+)"').firstMatch(html);
      if (ogTitleMatch != null) {
        title = ogTitleMatch.group(1)?.trim() ?? '';
      }

      if (title.isEmpty) {
        final titleMatch = RegExp(r'<title>([^<]+)</title>').firstMatch(html);
        if (titleMatch != null) {
          title = titleMatch.group(1)?.trim().replaceAll(' | Moesekai', '') ?? '';
        }
      }

      if (title.isEmpty) {
        _reportProgress('🎵 ID $id: 未找到标题, 跳过', onProgress);
        return null;
      }

      _reportProgress('🎵 ID $id: "$title" - 检查音频版本...', onProgress);

      final audioUrls = <String>[];
      final versionNames = <String>[];

      // 新歌最多只有虚拟歌手和セカイ两个版本，各只需检查 suffix 01
      final audioPatterns = [
        ('vs', 'バーチャル・シンガーver.'),
        ('se', 'セカイver.'),
      ];

      for (final pattern in audioPatterns) {
        final suffixStr = '01';
        final audioUrl = 'https://storage.exmeaning.com/sekai-jp-assets/music/long/${pattern.$1}_${paddedId4}_${suffixStr}/${pattern.$1}_${paddedId4}_${suffixStr}.mp3';
        if (await _checkUrlExists(audioUrl)) {
          audioUrls.add(audioUrl);
          versionNames.add(pattern.$2);
        }
      }

      if (audioUrls.isEmpty) {
        _reportProgress('🎵 ID $id: "$title" - 无音频, 跳过', onProgress);
        return null;
      }

      _reportProgress('🎵 ID $id: "$title" - 找到 ${audioUrls.length} 个版本', onProgress);

      if (category.isEmpty) {
        category = 'other';
      }

      final aliases = <String>[];
      aliases.add(title);
      aliases.add(title.toLowerCase());

      return MusicData(
        id: id,
        title: title,
        titleEn: '',
        composer: '',
        lyricist: '',
        arranger: '',
        fillerSec: 9.0,
        audioUrls: audioUrls,
        versionNames: versionNames,
        jacketUrl: jacketUrl,
        aliases: aliases,
        category: category,
      );
    } catch (e) {
      _reportProgress('🎵 ID $id: 错误 $e', onProgress);
      return null;
    }
  }

  Future<void> _loadMusicsFromLocal({Function(String)? onProgress}) async {
    try {
      String jsonString;
      bool fromAssets = true;

      try {
        final dir = await getApplicationDocumentsDirectory();
        final updatedFile = File('${dir.path}/musics_full_updated.json');

        if (await updatedFile.exists()) {
          jsonString = await updatedFile.readAsString();
          fromAssets = false;
          _reportProgress('🎵 从本地更新文件加载', onProgress);
        } else {
          jsonString = await rootBundle.loadString('assets/data/musics_full.json');
          _reportProgress('🎵 从内置资源加载', onProgress);
        }
      } catch (e) {
        jsonString = await rootBundle.loadString('assets/data/musics_full.json');
        _reportProgress('🎵 从内置资源加载(回退)', onProgress);
      }

      try {
        final dynamic parsed = json.decode(jsonString);
        if (parsed is List) {
          _musics.clear();
          for (final json in parsed) {
            try {
              _musics.add(MusicData.fromJsonFull(json));
            } catch (e) {
              _reportProgress('🎵 解析歌曲失败: $e', onProgress);
            }
          }
          _musics.removeWhere((m) => m.id <= 0 || m.title.isEmpty);
        } else {
          _loadError = 'Invalid data format: expected array';
          _reportProgress('🎵 数据格式错误', onProgress);
          return;
        }

        _reportProgress('🎵 本地加载完成: ${_musics.length} 首 (${fromAssets ? '内置' : '更新文件'})', onProgress);
      } catch (e) {
        _loadError = 'JSON parsing error: $e';
        _reportProgress('🎵 JSON解析错误: $e', onProgress);
      }
    } catch (e) {
      _loadError = 'Failed to load music data: $e';
      _reportProgress('🎵 加载音乐数据失败: $e', onProgress);
    }
  }

  void markMusicPlayed(String musicId) {
    _recentPlayedIds.add(musicId);
    if (_recentPlayedIds.length > _maxRecentPlayed) {
      _recentPlayedIds.remove(_recentPlayedIds.first);
    }
  }

  bool hasRecentPlayed(String musicId) {
    return _recentPlayedIds.contains(musicId);
  }

  void clearRecentPlayed() {
    _recentPlayedIds.clear();
  }

  Future<void> assignCategories({Function(String)? onProgress}) async {
    try {
      String jsonString;
      try {
        jsonString = await rootBundle.loadString('assets/data/music_categories.json');
      } catch (e) {
        _reportProgress('🎵 加载分类文件失败', onProgress);
        return;
      }

      final dynamic parsed = json.decode(jsonString);
      if (parsed is Map) {
        for (final music in _musics) {
          final category = parsed[music.id.toString()] ?? parsed[music.title] ?? '';
          if (category is String) {
            music.category = category;
          }
          if (music.category.isEmpty) {
            music.category = 'other';
          }
        }
      }

      _reportProgress('🎵 已分配分类', onProgress);
    } catch (e) {
      _reportProgress('🎵 分配分类失败: $e', onProgress);
    }
  }

  List<MusicData> searchMusics(String query) {
    if (query.isEmpty) return _musics;
    final lowerQuery = query.toLowerCase();
    
    return _musics.where((music) {
      return music.title.toLowerCase().contains(lowerQuery) ||
             music.titleEn.toLowerCase().contains(lowerQuery) ||
             music.aliases.any((alias) => alias.toLowerCase().contains(lowerQuery));
    }).toList();
  }
  
  MusicData? getRandomMusic({bool beginnerMode = false}) {
    if (_musics.isEmpty) return null;
    
    List<MusicData> candidates = _musics;
    
    if (beginnerMode) {
      candidates = _musics.where((m) => m.audioUrls.isNotEmpty).toList();
    }
    
    if (candidates.isEmpty) {
      candidates = _musics;
    }
    
    return candidates[_random.nextInt(candidates.length)];
  }
  
  void markMusicFailed(String musicId) {
  }
  
  bool isCorrectTitle(MusicData music, String userInput) {
    if (userInput.isEmpty) return false;
    
    final lowerInput = userInput.toLowerCase();
    
    if (music.title.toLowerCase().contains(lowerInput)) {
      return true;
    }
    
    if (music.titleEn.toLowerCase().contains(lowerInput)) {
      return true;
    }
    
    for (final alias in music.aliases) {
      if (alias.toLowerCase().contains(lowerInput)) {
        return true;
      }
    }
    
    return false;
  }
}
