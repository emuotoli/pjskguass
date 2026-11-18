import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'music_game_service.dart';

import 'package:just_audio/just_audio.dart';

class MusicGameScreen extends StatefulWidget {
  @override
  _MusicGameScreenState createState() => _MusicGameScreenState();
}

class _MusicGameScreenState extends State<MusicGameScreen> {
  final MusicGameService _gameService = MusicGameService();
  final AudioPlayer _audioPlayer = AudioPlayer();
  final Random _random = Random();
  final TextEditingController _searchController = TextEditingController();

  MusicData? _currentMusic;
  MusicData? _nextMusic;
  String _audioUrl = '';
  int _selectedVersion = 0;
  
  int _placeholderIndex = 0;

  String _userInput = '';
  String? _feedback;
  bool _isCorrect = false;
  bool _isPlaying = false;
  bool _showAnswer = false;
  bool _isLoadingAudio = false;
  bool _isDataLoaded = false;
  bool _isPreviewMode = true;
  bool _beginnerMode = false;
  bool _isDrawerOpen = false;
  String _selectedCategory = '';
  String _searchQuery = '';

  int _clipSeconds = 5;
  Duration get _clipDuration => Duration(seconds: _clipSeconds);
  Duration? _currentClipStart;
  Duration? _clipEnd;
  Duration _currentPosition = Duration.zero;
  Duration _duration = Duration.zero;

  Timer? _playbackTimer;
  StreamSubscription? _playerStateSub;
  StreamSubscription? _positionSub;

  @override
  void initState() {
    super.initState();
    _playerStateSub = _audioPlayer.playerStateStream.listen((state) {
      setState(() {
        _isPlaying = state.playing;
        if (state.processingState == ProcessingState.completed) {
          _isPlaying = false;
        }
      });
    });
    _positionSub = _audioPlayer.positionStream.listen((position) {
      setState(() {
        _currentPosition = position;
      });
      
      if (_isPreviewMode && _clipEnd != null && position >= _clipEnd!) {
        _audioPlayer.pause();
      }
    });
    _audioPlayer.durationStream.listen((duration) {
      if (duration != null) {
        setState(() => _duration = duration);
      }
    });
    _loadData();
  }

  @override
  void dispose() {
    _playbackTimer?.cancel();
    _playerStateSub?.cancel();
    _positionSub?.cancel();
    _audioPlayer.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    try {
      await _gameService.loadMusicsLocalOnly();
      if (_gameService.hasMusics) {
        await _loadNextMusic();
      }
      setState(() => _isDataLoaded = true);
    } catch (e) {
      print('Error loading data: $e');
      setState(() => _isDataLoaded = true);
    }
  }

  Future<void> _loadNextMusic() async {
    await _audioPlayer.stop();
    _playbackTimer?.cancel();

    if (_nextMusic != null) {
      _currentMusic = _nextMusic;
      _nextMusic = null;
    } else {
      _currentMusic = _gameService.getRandomMusic(beginnerMode: _beginnerMode);
    }
    
    _selectedVersion = 0;
    _audioUrl = '';
    _currentClipStart = null;
    _clipEnd = null;
    _placeholderIndex = _random.nextInt(6);

    if (_currentMusic != null) {
      _gameService.markMusicPlayed(_currentMusic!.id.toString());
    }

    setState(() {
      _userInput = '';
      _feedback = null;
      _isCorrect = false;
      _isPlaying = false;
      _showAnswer = false;
      _isLoadingAudio = false;
      _isPreviewMode = true;
    });

    _preloadNextMusic();
  }

  void _preloadNextMusic() {
    final nextMusic = _gameService.getRandomMusic(beginnerMode: _beginnerMode);
    if (nextMusic != null && nextMusic.audioUrls.isNotEmpty) {
      _nextMusic = nextMusic;
      for (final url in nextMusic.audioUrls) {
        _audioPlayer.setUrl(url, preload: true);
      }
    }
  }

  Future<void> _playMusic() async {
    if (_currentMusic == null || _currentMusic!.audioUrls.isEmpty) {
      setState(() => _feedback = '无法加载音频');
      return;
    }

    setState(() {
      _feedback = null;
      _isLoadingAudio = true;
    });

    final url = _currentMusic!.audioUrls[_selectedVersion];

    try {
      print('Playing audio: $url (version ${_selectedVersion + 1})');

      if (_isPreviewMode) {
        await _playPreviewClip(url);
      } else {
        await _playFullMusic(url);
      }

      setState(() {
        _isLoadingAudio = false;
      });

      print(_isPreviewMode ? 'Playing preview clip' : 'Playing full music');
    } catch (e) {
      print('Audio play failed: $e');
      
      setState(() {
        _isLoadingAudio = false;
      });
      
      if (_currentMusic != null) {
        _gameService.markMusicFailed(_currentMusic!.id.toString());
      }
      
      await _loadNextMusic();
    }
  }

  Future<void> _playPreviewClip(String url) async {
    if (_audioUrl != url) {
      await _audioPlayer.setUrl(url);
      _audioUrl = url;
      
      if (_currentClipStart == null) {
        final duration = await _audioPlayer.duration;
        if (duration == null) {
          _currentClipStart = Duration(seconds: 10);
        } else {
          final maxStart = duration - _clipDuration - Duration(seconds: 5);
          if (maxStart.inSeconds > 9) {
            _currentClipStart = Duration(seconds: _random.nextInt(maxStart.inSeconds - 9) + 9);
          } else {
            _currentClipStart = Duration(seconds: 9);
          }
        }
      }
    }

    _clipEnd = _currentClipStart! + _clipDuration;

    if (_currentClipStart != null) {
      await _audioPlayer.seek(_currentClipStart!);
    }
    
    await _audioPlayer.play();

    print('Playing clip from ${_currentClipStart!.inSeconds}s for ${_clipDuration.inSeconds}s, ends at ${_clipEnd!.inSeconds}s');
  }

  Future<void> _playFullMusic(String url) async {
    if (_audioUrl != url) {
      await _audioPlayer.setUrl(url);
      _audioUrl = url;
    }
    await _audioPlayer.seek(Duration(seconds: 9));
    await _audioPlayer.play();
  }
  
  void _selectVersion(int version) {
    if (_currentMusic != null && version >= 0 && version < _currentMusic!.audioUrls.length) {
      setState(() {
        _selectedVersion = version;
      });
    }
  }

  void _selectMusicFromDrawer(MusicData music) async {
    await _audioPlayer.stop();
    setState(() {
      _currentMusic = music;
      _selectedVersion = 0;
      _audioUrl = '';
      _currentClipStart = null;
      _clipEnd = null;
      _isPreviewMode = false;
      _isPlaying = false;
      _showAnswer = true;
      _feedback = '直接播放';
      _userInput = '';
      _isDrawerOpen = false;
    });
    _playFullMusicAfterDelay();
  }

  Future<void> _pauseMusic() async {
    await _audioPlayer.pause();
    _playbackTimer?.cancel();
  }

  Future<void> _replayMusic() async {
    await _playMusic();
  }

  void _checkAnswer() {
    if (_currentMusic == null) return;

    final isCorrect = _gameService.isCorrectTitle(_currentMusic!, _userInput);

    setState(() {
      _isCorrect = isCorrect;
      _showAnswer = true;
      _isPreviewMode = false;

      if (isCorrect) {
        _feedback = '🎉 回答正确！';
      } else {
        _feedback = '😢 回答错误';
      }
    });

    _pauseMusic();
    _playFullMusicAfterDelay();
  }

  void _skipQuestion() {
    setState(() {
      _showAnswer = true;
      _feedback = '跳过';
      _isPreviewMode = false;
    });
    _pauseMusic();
    _playFullMusicAfterDelay();
  }

  Future<void> _playFullMusicAfterDelay() async {
    await Future.delayed(Duration(milliseconds: 500));
    if (_currentMusic != null && _currentMusic!.audioUrls.isNotEmpty) {
      final url = _currentMusic!.audioUrls[_selectedVersion];
      try {
        await _audioPlayer.stop();
        await _audioPlayer.setUrl(url);
        await _audioPlayer.seek(Duration(seconds: 9));
        await _audioPlayer.play();
        _playbackTimer?.cancel();
      } catch (e) {
        print('Failed to play full music: $e');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('🎵 猜音乐'),
        centerTitle: true,
        backgroundColor: Colors.purple[700],
        leading: IconButton(
          icon: Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.menu),
            onPressed: () {
              setState(() {
                _isDrawerOpen = !_isDrawerOpen;
              });
            },
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: TextButton(
              onPressed: () {
                setState(() {
                  _beginnerMode = !_beginnerMode;
                });
                if (_beginnerMode) {
                  _loadNextMusic();
                }
              },
              child: Text(
                '新手模式',
                style: TextStyle(
                  color: _beginnerMode ? Colors.white : Colors.white70,
                  fontWeight: _beginnerMode ? FontWeight.bold : FontWeight.normal,
                ),
              ),
            ),
          ),
        ],
      ),
      body: Container(
        decoration: const BoxDecoration(
          image: DecorationImage(
            image: AssetImage('assets/bg_music.jpeg'),
            fit: BoxFit.cover,
            alignment: Alignment.topCenter,
          ),
        ),
        child: !_isDataLoaded
            ? Center(child: CircularProgressIndicator())
            : !_gameService.hasMusics
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text('无法加载音乐数据'),
                        if (_gameService.loadError != null)
                          Padding(
                            padding: const EdgeInsets.all(16),
                            child: Text(
                              _gameService.loadError!,
                              style: TextStyle(fontSize: 12, color: Colors.red),
                              textAlign: TextAlign.center,
                            ),
                          ),
                        SizedBox(height: 20),
                        ElevatedButton(
                          onPressed: _loadData,
                          child: Text('重试'),
                        ),
                      ],
                    ),
                  )
                : Row(
                    children: [
                      if (_isDrawerOpen)
                        SizedBox(
                          width: 300,
                          child: Drawer(
                            child: Column(
                              children: [
                                const DrawerHeader(
                                  child: Text('选择歌曲'),
                                ),
                                Padding(
                                  padding: const EdgeInsets.all(8),
                                  child: TextField(
                                    controller: _searchController,
                                    decoration: InputDecoration(
                                      hintText: '搜索歌曲...',
                                      prefixIcon: Icon(Icons.search),
                                      border: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                    ),
                                    onChanged: (value) {
                                      setState(() {
                                        _searchQuery = value;
                                      });
                                    },
                                  ),
                                ),
                                Expanded(
                                  child: Scrollbar(
                                    child: ListView.builder(
                                      itemCount: _getAllMusicsForDrawer().length,
                                      itemBuilder: (context, index) {
                                        final music = _getAllMusicsForDrawer()[index];
                                        return Padding(
                                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                                          child: GestureDetector(
                                            onTap: () => _selectMusicFromDrawer(music),
                                            child: Container(
                                              padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                                              decoration: BoxDecoration(
                                                border: Border.all(color: Colors.purple),
                                                borderRadius: BorderRadius.circular(8),
                                              ),
                                              child: Text(
                                                music.title,
                                                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.purple),
                                                textAlign: TextAlign.center,
                                                maxLines: 2,
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ),
                                          ),
                                        );
                                      },
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      Expanded(
                        child: LayoutBuilder(
                          builder: (context, constraints) {
                            return SingleChildScrollView(
                              physics: AlwaysScrollableScrollPhysics(),
                              padding: EdgeInsets.all(16),
                              child: ConstrainedBox(
                                constraints: BoxConstraints(
                                  minHeight: constraints.maxHeight,
                                ),
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    _buildPlaybackArea(),
                                    SizedBox(height: 20),
                                    _buildAnswerArea(),
                                    SizedBox(height: 20),
                                    _buildFeedbackArea(),
                                    SizedBox(height: 30),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    ],
                  ),
      ),
    );
  }

  Widget _buildPlaybackArea() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withOpacity(0.3)),
      ),
      padding: EdgeInsets.all(20),
      child: Column(
        children: [
          Container(
            width: 150,
            height: 150,
            decoration: BoxDecoration(
              color: Colors.deepPurple[200],
              borderRadius: BorderRadius.circular(12),
              image: _showAnswer && _currentMusic != null
                  ? DecorationImage(
                      image: NetworkImage(_currentMusic!.jacketUrl),
                      fit: BoxFit.cover,
                    )
                  : DecorationImage(
                      image: AssetImage('assets/photo/${[
                        '1783920273571.png',
                        '1783920285029.png',
                        '1783920289155.png',
                        '1783920293633.png',
                        '1783920301253.png',
                        '1783920763549.png',
                      ][_placeholderIndex]}'),
                      fit: BoxFit.cover,
                    ),
            ),
          ),
          SizedBox(height: 15),
          if (_currentMusic != null && _currentMusic!.audioUrls.length > 1)
            Wrap(
              alignment: WrapAlignment.center,
              spacing: 4,
              children: List.generate(_currentMusic!.audioUrls.length, (index) {
                String versionName = '';
                if (_currentMusic!.versionNames.length > index) {
                  versionName = _currentMusic!.versionNames[index];
                } else {
                  versionName = '版本 ${index + 1}';
                }
                return OutlinedButton(
                  onPressed: () => _selectVersion(index),
                  style: OutlinedButton.styleFrom(
                    backgroundColor: _selectedVersion == index ? Colors.black.withOpacity(0.1) : Colors.transparent,
                    foregroundColor: Colors.black,
                    side: const BorderSide(color: Colors.black, width: 2),
                    padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: Text(versionName),
                );
              }),
            ),
          SizedBox(height: 15),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              IconButton(
                icon: const Icon(Icons.replay),
                iconSize: 32,
                color: Colors.black,
                onPressed: _replayMusic,
              ),
              const SizedBox(width: 20),
              IconButton(
                icon: Icon(_isPlaying ? Icons.pause : Icons.play_arrow),
                iconSize: 48,
                color: Colors.black,
                onPressed: _isPlaying ? _pauseMusic : _playMusic,
              ),
              const SizedBox(width: 20),
              IconButton(
                icon: const Icon(Icons.skip_next),
                iconSize: 32,
                color: Colors.black,
                onPressed: _loadNextMusic,
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(_isPlaying ? '正在播放...' : '点击播放按钮开始', style: const TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 5),
          if (_isLoadingAudio)
            Text('音频加载中...', style: TextStyle(fontSize: 12, color: Colors.grey, fontWeight: FontWeight.bold)),
          SizedBox(height: 15),
          if (_showAnswer && _duration.inSeconds > 0)
            _buildProgressBar(),
          SizedBox(height: 15),
          _buildClipDurationSlider(),
        ],
      ),
    );
  }

  Widget _buildClipDurationSlider() {
    return Column(
      children: [
        Text(
          '试听时长: ${_clipSeconds}秒',
          style: TextStyle(fontSize: 14, color: Colors.black, fontWeight: FontWeight.bold),
        ),
        Slider(
          value: _clipSeconds.toDouble(),
          min: 5,
          max: 10,
          divisions: 5,
          activeColor: Colors.black,
          inactiveColor: Colors.grey[300],
          label: '${_clipSeconds}秒',
          onChanged: (value) {
            setState(() {
              _clipSeconds = value.round();
            });
          },
        ),
      ],
    );
  }

  Widget _buildProgressBar() {
    final progress = _duration.inSeconds > 0 ? (_currentPosition.inSeconds / _duration.inSeconds).toDouble() : 0.0;
    
    return Column(
      children: [
        Slider(
          value: progress,
          min: 0,
          max: 1,
          activeColor: Colors.black,
          inactiveColor: Colors.grey[300],
          onChanged: (value) async {
            final newPosition = Duration(seconds: (value * _duration.inSeconds).round());
            await _audioPlayer.seek(newPosition);
          },
        ),
        SizedBox(height: 5),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(_formatDuration(_currentPosition), style: TextStyle(fontSize: 12, color: Colors.black, fontWeight: FontWeight.bold)),
            Text(_formatDuration(_duration), style: TextStyle(fontSize: 12, color: Colors.black, fontWeight: FontWeight.bold)),
          ],
        ),
      ],
    );
  }

  String _formatDuration(Duration duration) {
    final minutes = duration.inMinutes;
    final seconds = duration.inSeconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  List<MusicData> _getAllMusicsForDrawer() {
    List<MusicData> musics;

    if (_searchQuery.isNotEmpty) {
      musics = _gameService.searchMusics(_searchQuery);
    } else {
      musics = List<MusicData>.from(_gameService.allMusics);
    }

    // 按ID降序排列（最新下载的歌在最上面）
    musics.sort((a, b) => b.id.compareTo(a.id));

    return musics;
  }

  Widget _buildAnswerArea() {
    return Column(
      children: [
        TextField(
          decoration: InputDecoration(
            labelText: '输入歌曲名称',
            hintText: '输入日文或英文歌名',
            border: const OutlineInputBorder(
              borderSide: BorderSide(color: Colors.black, width: 2),
            ),
            filled: true,
            fillColor: Colors.white.withOpacity(0.3),
            labelStyle: const TextStyle(color: Colors.black),
            hintStyle: TextStyle(color: Colors.black.withOpacity(0.5)),
          ),
          style: const TextStyle(color: Colors.black),
          onChanged: (value) {
            setState(() => _userInput = value);
          },
          onSubmitted: (_) => !_showAnswer ? _checkAnswer() : _loadNextMusic(),
          enabled: !_showAnswer,
        ),
        SizedBox(height: 10),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            OutlinedButton(
              onPressed: !_showAnswer && _userInput.isNotEmpty ? _checkAnswer : null,
              child: const Text('确认答案'),
              style: OutlinedButton.styleFrom(
                backgroundColor: Colors.white.withOpacity(0.3),
                foregroundColor: Colors.black,
                side: const BorderSide(color: Colors.black, width: 2),
                padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 15),
              ),
            ),
            const SizedBox(width: 10),
            OutlinedButton(
              onPressed: !_showAnswer ? _skipQuestion : _loadNextMusic,
              child: Text(_showAnswer ? '下一题' : '跳过'),
              style: OutlinedButton.styleFrom(
                backgroundColor: Colors.white.withOpacity(0.3),
                foregroundColor: Colors.black,
                side: const BorderSide(color: Colors.black, width: 2),
                padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 15),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildFeedbackArea() {
    if (_showAnswer && _currentMusic != null) {
      final chineseAliases = _currentMusic!.aliases
          .where((alias) => RegExp(r'[\u4e00-\u9fa5]').hasMatch(alias))
          .toSet()
          .toList();

      return Container(
        decoration: BoxDecoration(
          color: Colors.deepPurple[50],
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.deepPurple[200] ?? Colors.deepPurple),
        ),
        padding: EdgeInsets.all(16),
        child: Column(
          children: [
            Text(
              _feedback ?? '',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 10),
            Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(8),
                image: DecorationImage(
                  image: NetworkImage(_currentMusic!.jacketUrl),
                  fit: BoxFit.cover,
                ),
              ),
            ),
            SizedBox(height: 10),
            Text(
              '正确答案：${_currentMusic!.title}',
              style: TextStyle(fontSize: 16),
            ),
            if (_currentMusic!.titleEn.isNotEmpty && _currentMusic!.titleEn != _currentMusic!.title)
              Text(
                '英文：${_currentMusic!.titleEn}',
                style: TextStyle(fontSize: 14, color: Colors.grey),
              ),
            if (chineseAliases.isNotEmpty)
              Text(
                '中文：${chineseAliases.join(' / ')}',
                style: TextStyle(fontSize: 14, color: Colors.grey),
              ),
          ],
        ),
      );
    }
    return SizedBox.shrink();
  }
}