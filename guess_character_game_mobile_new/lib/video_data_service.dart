import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'music_game_service.dart';

class VideoData {
  final String bvid;
  final String title;
  final int duration;
  final int songId;
  final String songTitle;
  final String songTitleEn;
  final double matchScore;
  final bool is3dmv;

  VideoData({
    required this.bvid,
    required this.title,
    required this.duration,
    required this.songId,
    required this.songTitle,
    required this.songTitleEn,
    required this.matchScore,
    this.is3dmv = false,
  });

  factory VideoData.fromJson(Map<String, dynamic> json) {
    return VideoData(
      bvid: json['bvid'] ?? '',
      title: json['title'] ?? '',
      duration: json['duration'] ?? 0,
      songId: json['song_id'] ?? 0,
      songTitle: json['song_title'] ?? '',
      songTitleEn: json['song_title_en'] ?? '',
      matchScore: (json['match_score'] ?? 0).toDouble(),
      is3dmv: json['is_3dmv'] ?? false,
    );
  }
}

class VideoGameService {
  List<VideoData> _videos = [];
  List<MusicData> _songs = [];
  bool _isLoaded = false;

  bool get isLoaded => _isLoaded;
  List<VideoData> get allVideos => _videos;

  Future<void> loadData() async {
    await _loadVideos();
    await _loadSongs();
    _isLoaded = true;
  }

  Future<void> _loadVideos() async {
    try {
      final String response = await rootBundle.loadString('assets/data/mv_videos_matched.json');
      final List<dynamic> data = json.decode(response);
      _videos = data.map((item) => VideoData.fromJson(item)).toList();
    } catch (e) {
      debugPrint('Failed to load video data: $e');
      _videos = [];
    }
  }

  Future<void> _loadSongs() async {
    try {
      final String response = await rootBundle.loadString('assets/data/musics_full.json');
      final List<dynamic> data = json.decode(response);
      _songs = data.map((item) => MusicData.fromJsonFull(item)).toList();
    } catch (e) {
      debugPrint('Failed to load song data: $e');
      _songs = [];
    }
  }

  VideoData? getRandomVideo() {
    if (_videos.isEmpty) return null;
    final random = Random();
    return _videos[random.nextInt(_videos.length)];
  }

  MusicData? getSongForVideo(VideoData video) {
    return _songs.firstWhere(
      (song) => song.id == video.songId,
      orElse: () => MusicData(id: 0, title: '', titleEn: '', audioUrls: []),
    );
  }

  bool isCorrectTitle(VideoData video, String userInput) {
    final song = getSongForVideo(video);
    if (song == null) return false;

    final normalizedInput = _normalizeText(userInput);

    final allTitles = [song.title, song.titleEn] + song.aliases;
    for (final title in allTitles) {
      if (_normalizeText(title) == normalizedInput) {
        return true;
      }
    }

    return false;
  }

  String _normalizeText(String text) {
    return text
        .trim()
        .toLowerCase()
        .replaceAll(RegExp(r'\s+'), '')
        .replaceAll('（', '')
        .replaceAll('）', '')
        .replaceAll('「', '')
        .replaceAll('」', '')
        .replaceAll('『', '')
        .replaceAll('』', '')
        .replaceAll('(', '')
        .replaceAll(')', '')
        .replaceAll('，', '')
        .replaceAll('、', '')
        .replaceAll('。', '')
        .replaceAll('！', '')
        .replaceAll('?', '')
        .replaceAll('？', '');
  }

  int getVideoCount() => _videos.length;

  Future<String?> getVideoDownloadUrl(String bvid) async {
    try {
      final infoUrl = 'https://api.bilibili.com/x/web-interface/view?bvid=$bvid';
      final infoResponse = await http.get(Uri.parse(infoUrl));
      
      if (infoResponse.statusCode == 200) {
        final infoData = json.decode(infoResponse.body);
        final cid = infoData['data']['cid'];
        
        final playUrl = 'https://api.bilibili.com/x/player/playurl?bvid=$bvid&cid=$cid&qn=64';
        final playResponse = await http.get(Uri.parse(playUrl));
        
        if (playResponse.statusCode == 200) {
          final playData = json.decode(playResponse.body);
          final durl = playData['data']['durl'];
          if (durl != null && durl.isNotEmpty) {
            return durl[0]['url'];
          }
        }
      }
    } catch (e) {
      debugPrint('Failed to get video download url: $e');
    }
    return null;
  }

  Future<String?> downloadVideo(String bvid, String title, Function(double) onProgress) async {
    final downloadUrl = await getVideoDownloadUrl(bvid);
    if (downloadUrl == null) return null;

    try {
      final dir = await getExternalStorageDirectory();
      if (dir == null) return null;

      final videoDir = Directory('${dir.path}/mv_videos');
      await videoDir.create(recursive: true);

      final safeTitle = title.replaceAll(RegExp(r'[\\/:*?"<>|]'), '_');
      final filePath = '${videoDir.path}/${bvid}_${safeTitle}.mp4';

      if (File(filePath).existsSync()) {
        return filePath;
      }

      final response = await http.get(Uri.parse(downloadUrl), headers: {
        'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36',
        'Referer': 'https://www.bilibili.com/',
      });

      if (response.statusCode == 200) {
        final file = File(filePath);
        await file.writeAsBytes(response.bodyBytes);
        return filePath;
      }
    } catch (e) {
      debugPrint('Failed to download video: $e');
    }
    return null;
  }

  Future<String?> getLocalVideoPath(String bvid) async {
    try {
      final dir = await getExternalStorageDirectory();
      if (dir == null) return null;

      final videoDir = Directory('${dir.path}/mv_videos');
      if (!videoDir.existsSync()) return null;

      final files = videoDir.listSync(recursive: false);
      for (final file in files) {
        if (file is File && file.path.contains(bvid)) {
          return file.path;
        }
      }
    } catch (e) {
      debugPrint('Failed to get local video path: $e');
    }
    return null;
  }
}