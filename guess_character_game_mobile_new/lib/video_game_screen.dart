import 'dart:async';
import 'dart:io';
import 'dart:math';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import 'package:just_audio/just_audio.dart';
import 'video_data_service.dart';

const Color kPurpleColor = Color(0xFF6B46C1);

class VideoGameScreen extends StatefulWidget {
  const VideoGameScreen({super.key});

  @override
  State<VideoGameScreen> createState() => _VideoGameScreenState();
}

class _VideoGameScreenState extends State<VideoGameScreen> {
  late VideoGameService _videoService;
  VideoData? _currentVideo;
  VideoPlayerController? _controller;
  final TextEditingController _answerController = TextEditingController();
  final Random _random = Random();
  AudioPlayer? _bgMusicPlayer;
  Duration _bgMusicPosition = Duration.zero;
  String? _currentBgMusicPath;
  
  final List<String> _bgMusicList = [
    'assets/bgm/101_一緒に歌おう！.mp3',
    'assets/bgm/103_Our Town, Our Life.mp3',
    'assets/bgm/109_Crossing World.mp3',
    'assets/bgm/113_Many Times With You.mp3',
  ];

  bool _isPlaying = false;
  bool _showResult = false;
  bool _isCorrect = false;
  bool _isLoading = true;
  bool _isDownloading = false;
  bool _isBgMusicPlaying = false;
  bool _isFading = false;
  double _downloadProgress = 0;
  int _score = 0;
  int _totalAttempts = 0;
  String _feedbackMessage = '';

  Duration? _clipStart;
  Duration _clipDuration = const Duration(seconds: 5);
  Duration _pendingClipDuration = const Duration(seconds: 5);
  Duration _currentPosition = Duration.zero;
  Duration _duration = Duration.zero;
  String? _currentVideoFilePath;

  @override
  void initState() {
    super.initState();
    _videoService = VideoGameService();
    _initBgMusic();
    _loadData();
  }

  Future<void> _initBgMusic() async {
    _bgMusicPlayer = AudioPlayer();
    _bgMusicPlayer!.setLoopMode(LoopMode.one);
    _bgMusicPlayer!.positionStream.listen((position) {
      setState(() {
        _bgMusicPosition = position;
      });
    });
    await _pickRandomBgMusic();
  }
  
  Future<void> _pickRandomBgMusic() async {
    if (_bgMusicPlayer == null) return;
    
    await _bgMusicPlayer!.stop();
    
    final randomIndex = _random.nextInt(_bgMusicList.length);
    _currentBgMusicPath = _bgMusicList[randomIndex];
    
    await _bgMusicPlayer!.setAsset(_currentBgMusicPath!);
    _bgMusicPosition = Duration.zero;
  }

  Future<void> _playBgMusic() async {
    if (_bgMusicPlayer != null && !_isBgMusicPlaying) {
      await _bgMusicPlayer!.seek(_bgMusicPosition);
      await _bgMusicPlayer!.play();
      setState(() {
        _isBgMusicPlaying = true;
      });
    }
  }

  Future<void> _pauseBgMusic() async {
    if (_bgMusicPlayer != null && _isBgMusicPlaying) {
      await _bgMusicPlayer!.pause();
      setState(() {
        _isBgMusicPlaying = false;
      });
    }
  }

  Future<void> _stopBgMusic() async {
    if (_bgMusicPlayer != null) {
      await _bgMusicPlayer!.stop();
      setState(() {
        _isBgMusicPlaying = false;
      });
    }
  }

  Future<void> _loadData() async {
    await _videoService.loadData();
    setState(() {
      _isLoading = false;
    });
    _pickRandomVideo();
  }

  void _pickRandomVideo() {
    _currentVideo = _videoService.getRandomVideo();
    if (_currentVideo != null) {
      _playRandomVideo();
    }
  }

  Future<void> _playRandomVideo() async {
    if (_currentVideo == null) return;

    setState(() {
      _isDownloading = true;
      _downloadProgress = 0;
    });

    await _downloadAndPlay();
  }

  Future<void> _downloadAndPlay() async {
    if (_currentVideo == null) return;

    try {
      setState(() {
        _downloadProgress = 0;
      });

      final filePath = await _videoService.downloadVideo(
        _currentVideo!.bvid,
        _currentVideo!.title,
        (progress) {
          setState(() {
            _downloadProgress = progress;
          });
        },
      );

      setState(() {
        _isDownloading = false;
      });

      if (filePath != null) {
        await _playLocalVideo(filePath);
      } else {
        setState(() {
          _feedbackMessage = '视频下载失败，请重试';
        });
        _pickRandomVideo();
      }
    } catch (e) {
      debugPrint('Download error: $e');
      setState(() {
        _isDownloading = false;
        _feedbackMessage = '下载出错，请重试';
      });
      _pickRandomVideo();
    }
  }

  Future<void> _playLocalVideo(String filePath) async {
    if (_controller != null) {
      await _controller!.dispose();
    }

    try {
      _currentVideoFilePath = filePath;
      
      _controller = VideoPlayerController.file(
        File(filePath),
        videoPlayerOptions: VideoPlayerOptions(mixWithOthers: true),
      );

      await _controller!.initialize();

      setState(() {
        _duration = _controller!.value.duration;
        _currentPosition = Duration.zero;
      });

      _controller!.addListener(() {
        setState(() {
          _currentPosition = _controller!.value.position;
        });

        if (_controller!.value.position >= _controller!.value.duration) {
          _pauseBgMusic();
          setState(() {
            _isPlaying = false;
          });
        }

        if (!_showResult && _clipStart != null && _controller!.value.isPlaying && !_isFading) {
          final clipEnd = _clipStart! + _clipDuration;
          if (_controller!.value.position >= clipEnd) {
            _loopClip();
          }
        }
      });

      _pickRandomClipStart();
      await _controller!.seekTo(_clipStart!);
      _controller!.setVolume(0);
      _controller!.play();
      _playBgMusic();
      setState(() {
        _isPlaying = true;
      });
    } catch (e) {
      debugPrint('Video play error: $e');
      setState(() {
        _feedbackMessage = '视频播放失败，请重试';
      });
      _pickRandomVideo();
    }
  }

  void _pickRandomClipStart() {
    if (_controller == null || !_controller!.value.isInitialized) {
      _clipStart = Duration.zero;
      return;
    }

    final totalDuration = _controller!.value.duration;
    final minStart = const Duration(seconds: 10);
    final maxStart = totalDuration - _clipDuration - const Duration(seconds: 10);

    if (maxStart <= minStart) {
      _clipStart = minStart;
    } else {
      final range = maxStart - minStart;
      final randomOffset = Duration(seconds: _random.nextInt(range.inSeconds));
      _clipStart = minStart + randomOffset;
    }
  }

  Future<void> _loopClip() async {
    if (_showResult || _isFading) return;
    
    setState(() {
      _isFading = true;
    });
    
    await Future.delayed(const Duration(milliseconds: 300));
    
    _clipDuration = _pendingClipDuration;
    
    if (_controller != null && _clipStart != null) {
      await _controller!.seekTo(_clipStart!);
    }
    
    await Future.delayed(const Duration(milliseconds: 300));
    
    setState(() {
      _isFading = false;
    });
  }

  void _playVideo() {
    if (_controller != null && _controller!.value.isInitialized) {
      if (!_isPlaying && (_clipStart != null && !_showResult)) {
        _controller!.seekTo(_clipStart!);
        _playBgMusic();
      }
      _controller!.play();
      setState(() {
        _isPlaying = true;
      });
    }
  }

  void _pauseVideo() {
    if (_controller != null && _controller!.value.isPlaying) {
      _controller!.pause();
      _pauseBgMusic();
      setState(() {
        _isPlaying = false;
      });
    }
  }

  void _replayVideo() {
    if (_controller != null && _controller!.value.isInitialized) {
      if (!_showResult && _clipStart != null) {
        _controller!.seekTo(_clipStart!);
        _playBgMusic();
      }
      _controller!.play();
      setState(() {
        _isPlaying = true;
      });
    }
  }

  void _skipVideo() {
    _pauseVideo();
    _stopBgMusic();
    _totalAttempts++;
    setState(() {
      _showResult = true;
      _isCorrect = false;
      _feedbackMessage = '⏭ 跳过！正确答案是：${_currentVideo!.songTitle}';
    });
    _controller?.setVolume(1);
    Future.delayed(const Duration(milliseconds: 500), () {
      _replayVideo();
    });
  }

  void _submitAnswer() {
    if (_currentVideo == null || _answerController.text.isEmpty) return;

    _totalAttempts++;
    final isCorrect = _videoService.isCorrectTitle(_currentVideo!, _answerController.text);

    setState(() {
      _showResult = true;
      _isCorrect = isCorrect;
      _pauseVideo();

      if (isCorrect) {
        _score++;
        _feedbackMessage = '🎉 正确！答案是：${_currentVideo!.songTitle}';
      } else {
        _feedbackMessage = '😢 错误！正确答案是：${_currentVideo!.songTitle}';
      }
    });
    _stopBgMusic();
    _controller?.setVolume(1);
    Future.delayed(const Duration(milliseconds: 500), () {
      _replayVideo();
    });
  }

  void _nextVideo() {
    _deleteCurrentVideoCache();
    
    setState(() {
      _showResult = false;
      _isCorrect = false;
      _answerController.clear();
      _feedbackMessage = '';
    });

    if (_controller != null) {
      _controller!.dispose();
      _controller = null;
    }

    _pickRandomBgMusic();
    _pickRandomVideo();
  }
  
  void _deleteCurrentVideoCache() {
    if (_currentVideoFilePath != null) {
      final file = File(_currentVideoFilePath!);
      if (file.existsSync()) {
        try {
          file.deleteSync();
          debugPrint('Deleted cached video: $_currentVideoFilePath');
        } catch (e) {
          debugPrint('Failed to delete cached video: $e');
        }
      }
      _currentVideoFilePath = null;
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    _bgMusicPlayer?.dispose();
    _answerController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        backgroundColor: kPurpleColor,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text('🎬 猜MV'),
        centerTitle: true,
      ),
      body: Stack(
        children: [
          SizedBox.expand(
            child: Container(
              decoration: const BoxDecoration(
                image: DecorationImage(
                  image: AssetImage('assets/miku.jpeg'),
                  fit: BoxFit.cover,
                  alignment: Alignment.topCenter,
                ),
              ),
            ),
          ),
          _isLoading
              ? const Center(child: CircularProgressIndicator())
              : SingleChildScrollView(
                  child: Column(
                    children: [
                      _buildVideoPlayer(),
                      _buildPlaybackControls(),
                      _buildGameArea(),
                    ],
                  ),
                ),
        ],
      ),
    );
  }

  Widget _buildVideoPlayer() {
    return Container(
      margin: const EdgeInsets.all(16),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: AspectRatio(
          aspectRatio: 16 / 9,
          child: Container(
            color: Colors.black,
            child: Stack(
              children: [
                if (_controller != null && _controller!.value.isInitialized)
                  VideoPlayer(_controller!),
                AnimatedOpacity(
                  opacity: _isFading ? 1.0 : 0.0,
                  duration: const Duration(milliseconds: 300),
                  curve: Curves.easeInOut,
                  child: Container(
                    color: Colors.black,
                  ),
                ),
                if (_isDownloading)
                  Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const CircularProgressIndicator(),
                        const SizedBox(height: 16),
                        Text(
                          '下载中... ${_downloadProgress.toStringAsFixed(0)}%',
                          style: const TextStyle(color: Colors.white),
                        ),
                      ],
                    ),
                  ),
                if (!_isDownloading && (_controller == null || !_controller!.value.isInitialized))
                  const Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.video_library, size: 64, color: Colors.white38),
                        SizedBox(height: 16),
                        Text(
                          '加载视频中...',
                          style: TextStyle(color: Colors.white54),
                        ),
                      ],
                    ),
                  ),
                if (!_showResult && _currentVideo?.is3dmv == true)
                  _buildMosaicMask(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMosaicMask() {
    return Positioned(
      left: 8,
      bottom: 13,
      width: 200,
      height: 10,
      child: ClipRRect(
        borderRadius: const BorderRadius.only(
          bottomLeft: Radius.circular(4),
        ),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
          child: Container(
            color: Colors.black.withOpacity(0.5),
          ),
        ),
      ),
    );
  }

  Widget _buildPlaybackControls() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        IconButton(
          icon: const Icon(Icons.replay),
          iconSize: 32,
          color: Colors.black,
          onPressed: _isDownloading ? null : _replayVideo,
        ),
        const SizedBox(width: 20),
        IconButton(
          icon: Icon(_isPlaying ? Icons.pause : Icons.play_arrow),
          iconSize: 48,
          color: Colors.black,
          onPressed: _isDownloading ? null : (_isPlaying ? _pauseVideo : _playVideo),
        ),
        const SizedBox(width: 20),
        IconButton(
          icon: const Icon(Icons.skip_next),
          iconSize: 32,
          color: Colors.black,
          onPressed: _isDownloading ? null : _skipVideo,
        ),
      ],
    );
  }

  Widget _buildGameArea() {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0),
        borderRadius: const BorderRadius.all(Radius.circular(24)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildScoreBar(),
          const SizedBox(height: 20),
          _buildQuestionArea(),
          const SizedBox(height: 20),
          _buildInputArea(),
          const SizedBox(height: 20),
          _buildProgressBar(),
          const SizedBox(height: 20),
          _buildClipDurationSlider(),
          const SizedBox(height: 20),
          _buildResultArea(),
          const SizedBox(height: 20),
          _buildActionButtons(),
          const SizedBox(height: 40),
          _buildCreditLine(),
        ],
      ),
    );
  }
  
  Widget _buildClipDurationSlider() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.6),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.black, width: 2),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                '片段长度',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.black87),
              ),
              Text(
                '${_pendingClipDuration.inSeconds}秒',
                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: kPurpleColor),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Slider(
            value: _pendingClipDuration.inSeconds.toDouble(),
            min: 5,
            max: 20,
            divisions: 15,
            activeColor: kPurpleColor,
            inactiveColor: Colors.grey[300],
            onChanged: (value) {
              setState(() {
                _pendingClipDuration = Duration(seconds: value.round());
              });
            },
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: const [
              Text('5秒', style: TextStyle(fontSize: 12, color: Colors.grey)),
              Text('20秒', style: TextStyle(fontSize: 12, color: Colors.grey)),
            ],
          ),
        ],
      ),
    );
  }
  
  Widget _buildCreditLine() {
    return const Center(
      child: Text(
        '资源来自PJS字幕组',
        style: TextStyle(
          fontSize: 12,
          color: Colors.black54,
          fontStyle: FontStyle.italic,
        ),
      ),
    );
  }

  Widget _buildScoreBar() {
    return Container();
  }

  Widget _buildQuestionArea() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: const [
        Text(
          '🎬 看MV猜歌名',
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.bold,
            color: Colors.black87,
          ),
        ),
        SizedBox(height: 8),
        Text(
          '观看视频后，输入歌曲名称',
          style: TextStyle(
            fontSize: 14,
            color: Colors.grey,
          ),
        ),
      ],
    );
  }

  Widget _buildInputArea() {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.black, width: 2),
        color: Colors.white.withOpacity(0.8),
      ),
      child: TextField(
        controller: _answerController,
        enabled: !_showResult && !_isDownloading,
        decoration: InputDecoration(
          hintText: '输入歌曲名或别名...',
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          suffixIcon: Icon(Icons.music_note, color: kPurpleColor),
        ),
        style: const TextStyle(fontSize: 16),
        onSubmitted: (_) => _submitAnswer(),
      ),
    );
  }

  Widget _buildResultArea() {
    if (!_showResult) return Container();

    final song = _currentVideo != null ? _videoService.getSongForVideo(_currentVideo!) : null;
    final aliases = song?.aliases ?? [];

    final isSkipped = !_isCorrect && _feedbackMessage.contains('跳过');
    final bgColor = _isCorrect ? Colors.green.shade100 : (isSkipped ? Colors.yellow.shade100 : Colors.red.shade100);
    final iconColor = _isCorrect ? Colors.green : (isSkipped ? Colors.yellow : Colors.red);
    final icon = _isCorrect ? Icons.check_circle : (isSkipped ? Icons.radio_button_unchecked : Icons.close);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        color: bgColor,
      ),
      child: Column(
        children: [
          Icon(
            icon,
            size: 48,
            color: iconColor,
          ),
          const SizedBox(height: 8),
          Text(
            _feedbackMessage,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: iconColor,
            ),
            textAlign: TextAlign.center,
          ),
          if (aliases.isNotEmpty) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.5),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '别名:',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: iconColor,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    aliases.join(' / '),
                    style: const TextStyle(fontSize: 14, color: Colors.black87),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildProgressBar() {
    if (_duration.inSeconds <= 0) return Container();

    return Column(
      children: [
        Slider(
          value: _currentPosition.inSeconds.toDouble(),
          min: 0,
          max: _duration.inSeconds.toDouble(),
          activeColor: Colors.black,
          inactiveColor: Colors.grey[300],
          onChanged: (value) {
            setState(() {
              _controller?.seekTo(Duration(seconds: value.round()));
            });
          },
        ),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              _formatDuration(_currentPosition),
              style: const TextStyle(fontSize: 12, color: Colors.black),
            ),
            Text(
              _formatDuration(_duration),
              style: const TextStyle(fontSize: 12, color: Colors.black),
            ),
          ],
        ),
      ],
    );
  }

  String _formatDuration(Duration duration) {
    final minutes = duration.inMinutes;
    final seconds = duration.inSeconds % 60;
    return '$minutes:${seconds.toString().padLeft(2, '0')}';
  }

  Widget _buildActionButtons() {
    return Row(
      children: [
        Expanded(
          child: OutlinedButton(
            onPressed: _isDownloading ? null : _submitAnswer,
            style: OutlinedButton.styleFrom(
              backgroundColor: Colors.white.withOpacity(0.8),
              foregroundColor: Colors.black,
              side: const BorderSide(color: Colors.black, width: 2),
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: const Text(
              '✓ 提交',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
          ),
        ),
        const SizedBox(width: 12),
        if (!_showResult)
          Expanded(
            child: OutlinedButton(
              onPressed: _isDownloading ? null : _skipVideo,
              style: OutlinedButton.styleFrom(
                backgroundColor: Colors.white.withOpacity(0.8),
                foregroundColor: Colors.black,
                side: const BorderSide(color: Colors.black, width: 2),
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text(
                '⏭ 跳过',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ),
          ),
        if (_showResult)
          Expanded(
            child: OutlinedButton(
              onPressed: _nextVideo,
              style: OutlinedButton.styleFrom(
                backgroundColor: Colors.white.withOpacity(0.8),
                foregroundColor: Colors.black,
                side: const BorderSide(color: Colors.black, width: 2),
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text(
                '➜ 下一题',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ),
          ),
      ],
    );
  }
}