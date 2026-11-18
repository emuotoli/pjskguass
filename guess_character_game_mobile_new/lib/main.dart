import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'game_screen.dart';
import 'music_game_screen.dart';
import 'video_game_screen.dart';
import 'music_game_service.dart';
import 'game_service.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Project SEKAI 游戏',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      home: const HomeScreen(),
    );
  }
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  String _updateStatus = '检测更新中...';
  bool _isLoading = true;
  List<String> _newCards4Star = [];
  List<String> _newCards3Star = [];
  List<String> _newMusics = [];
  bool _hasUpdate = false;
  List<String> _scanLogs = [];
  bool _showLogs = false;

  @override
  void initState() {
    super.initState();
    _checkUpdates();
  }

  Future<void> _checkUpdates() async {
    setState(() {
      _isLoading = true;
      _updateStatus = '加载本地数据...';
      _newCards4Star = [];
      _newCards3Star = [];
      _newMusics = [];
    });

    try {
      final prefs = await SharedPreferences.getInstance();
      final lastMusicCount = prefs.getInt('last_music_count') ?? 0;
      final lastCardCount = prefs.getInt('last_card_count') ?? 0;

      final musicService = MusicGameService();

      setState(() {
        _updateStatus = '正在加载音乐数据...';
      });
      await musicService.loadMusics(onProgress: (message) {
        setState(() {
          _updateStatus = '🎵 $message';
          _scanLogs.add('🎵 $message');
          if (_scanLogs.length > 50) {
            _scanLogs.removeAt(0);
          }
        });
      });

      final currentMusicCount = musicService.getMusicCount();
      final addedMusicCount = currentMusicCount - lastMusicCount;

      if (addedMusicCount > 0) {
        final allMusics = musicService.allMusics;
        allMusics.sort((a, b) => b.id.compareTo(a.id));
        
        for (int i = 0; i < addedMusicCount && i < allMusics.length; i++) {
          _newMusics.add(allMusics[i].title);
        }
      }

      await prefs.setInt('last_music_count', currentMusicCount);

      final cardService = GameService();

      setState(() {
        _updateStatus = '正在加载卡面数据...';
      });
      await cardService.loadCards();

      setState(() {
        _updateStatus = '🎴 正在检查卡面更新...';
      });
      await cardService.checkForCardUpdatesInBackground(onProgress: (message) {
        setState(() {
          _updateStatus = '🎴 $message';
          _scanLogs.add(message);
          if (_scanLogs.length > 50) {
            _scanLogs.removeAt(0);
          }
        });
      });

      final currentCardCount = cardService.getCardCount();
      final addedCardCount = currentCardCount - lastCardCount;

      if (addedCardCount > 0) {
        final allCards = cardService.getAllCards();
        allCards.sort((a, b) {
          final aNum = int.tryParse(a.id.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0;
          final bNum = int.tryParse(b.id.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0;
          return bNum.compareTo(aNum);
        });
        
        for (int i = 0; i < addedCardCount && i < allCards.length; i++) {
          final card = allCards[i];
          if (card.rarity == 4) {
            _newCards4Star.add(card.cardName.isNotEmpty ? card.cardName : card.id);
          } else if (card.rarity == 3) {
            _newCards3Star.add(card.cardName.isNotEmpty ? card.cardName : card.id);
          }
        }
      }

      await prefs.setInt('last_card_count', currentCardCount);

      setState(() {
        _isLoading = false;
        final hasCardUpdate = _newCards4Star.isNotEmpty || _newCards3Star.isNotEmpty;
        _hasUpdate = _newMusics.isNotEmpty || hasCardUpdate;
        
        if (_hasUpdate) {
          _updateStatus = '发现更新';
        } else {
          _updateStatus = '本地数据已是最新\n音乐: $currentMusicCount | 卡牌: $currentCardCount';
        }
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
        _updateStatus = '更新检测失败: $e';
        _hasUpdate = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Project SEKAI'),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.menu),
            onPressed: () {
              setState(() {
                _showLogs = !_showLogs;
              });
            },
          ),
        ],
      ),
      body: Stack(
        children: [
          Container(
            width: double.infinity,
            height: double.infinity,
            decoration: const BoxDecoration(
              image: DecorationImage(
                image: AssetImage('assets/bg_home.jpeg'),
                fit: BoxFit.cover,
              ),
            ),
          ),
          Column(
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
                child: SizedBox(
                  width: 280,
                  height: 120,
                  child: OutlinedButton(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (context) => const GameScreen()),
                      );
                    },
                    style: OutlinedButton.styleFrom(
                      backgroundColor: Colors.white.withOpacity(0.1),
                      foregroundColor: Colors.white,
                      side: const BorderSide(color: Colors.white, width: 2),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    child: const Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Image(
                          image: AssetImage('kamian.png'),
                          width: 40,
                          height: 40,
                          fit: BoxFit.contain,
                        ),
                        SizedBox(height: 8),
                        Text(
                          '猜卡面',
                          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const Expanded(child: SizedBox()),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                child: SizedBox(
                  width: 280,
                  height: 120,
                  child: OutlinedButton(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (context) => VideoGameScreen()),
                      );
                    },
                    style: OutlinedButton.styleFrom(
                      backgroundColor: Colors.white.withOpacity(0.1),
                      foregroundColor: Colors.white,
                      side: const BorderSide(color: Colors.white, width: 2),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    child: const Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Image(
                          image: AssetImage('mv_icon.png'),
                          width: 40,
                          height: 40,
                          fit: BoxFit.contain,
                        ),
                        SizedBox(height: 8),
                        Text(
                          '猜MV',
                          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                child: SizedBox(
                  width: 280,
                  height: 120,
                  child: OutlinedButton(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (context) => MusicGameScreen()),
                      );
                    },
                    style: OutlinedButton.styleFrom(
                      backgroundColor: Colors.white.withOpacity(0.1),
                      foregroundColor: Colors.white,
                      side: const BorderSide(color: Colors.white, width: 2),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    child: const Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Image(
                          image: AssetImage('yinyue.png'),
                          width: 40,
                          height: 40,
                          fit: BoxFit.contain,
                        ),
                        SizedBox(height: 8),
                        Text(
                          '猜音乐',
                          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
          if (_showLogs)
            Positioned(
              top: 60,
              right: 0,
              width: 300,
              child: Container(
                margin: const EdgeInsets.all(8),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.8),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.white.withOpacity(0.3)),
                ),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxHeight: 400),
                  child: SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                              _isLoading ? Icons.refresh : (_hasUpdate ? Icons.check_circle : Icons.info),
                              size: 16,
                              color: _isLoading ? Colors.grey[400] : (_hasUpdate ? Colors.green : Colors.grey[400]),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                _updateStatus,
                                style: const TextStyle(fontSize: 14, color: Colors.white),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        if (!_isLoading) ...[
                          if (_newCards4Star.isNotEmpty) ...[
                            Text(
                              '新增四星卡牌:',
                              style: TextStyle(fontSize: 13, color: Colors.grey[400]),
                            ),
                            const SizedBox(height: 4),
                            Wrap(
                              spacing: 8,
                              children: _newCards4Star.map((name) => Text(
                                name,
                                style: const TextStyle(fontSize: 12, color: Colors.orange),
                              )).toList(),
                            ),
                            const SizedBox(height: 8),
                          ],
                          if (_newCards3Star.isNotEmpty) ...[
                            Text(
                              '新增三星卡牌:',
                              style: TextStyle(fontSize: 13, color: Colors.grey[400]),
                            ),
                            const SizedBox(height: 4),
                            Wrap(
                              spacing: 8,
                              children: _newCards3Star.map((name) => Text(
                                name,
                                style: const TextStyle(fontSize: 12, color: Colors.blue),
                              )).toList(),
                            ),
                            const SizedBox(height: 8),
                          ],
                          if (_newMusics.isNotEmpty) ...[
                            Text(
                              '新增歌曲:',
                              style: TextStyle(fontSize: 13, color: Colors.grey[400]),
                            ),
                            const SizedBox(height: 4),
                            Wrap(
                              spacing: 8,
                              children: _newMusics.map((name) => Text(
                                name,
                                style: const TextStyle(fontSize: 12, color: Colors.purple),
                              )).toList(),
                            ),
                            const SizedBox(height: 8),
                          ],
                          if (_scanLogs.isNotEmpty) ...[
                            Text(
                              '扫描日志:',
                              style: TextStyle(fontSize: 13, color: Colors.grey[400]),
                            ),
                            const SizedBox(height: 4),
                            Container(
                              height: 120,
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              padding: const EdgeInsets.all(8),
                              child: SingleChildScrollView(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: _scanLogs.map((log) => Text(
                                    log,
                                    style: TextStyle(fontSize: 11, color: Colors.grey[300]),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  )).toList(),
                                ),
                              ),
                            ),
                          ],
                        ],
                      ],
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
