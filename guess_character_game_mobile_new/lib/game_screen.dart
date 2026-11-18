import 'dart:async';
import 'dart:io';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:path_provider/path_provider.dart';
import 'constants.dart';
import 'game_service.dart';

class GameScreen extends StatefulWidget {
  const GameScreen({super.key});

  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen> {
  final GameService _gameService = GameService();
  CardData? _currentCard;
  CardData? _nextCard;
  String? _currentImageUrl;
  bool _isRevealed = false;
  bool _isAnswered = false;
  double _fragmentSize = 0.3;
  double _fragmentOffsetX = 0.5;
  double _fragmentOffsetY = 0.5;
  List<bool> _disabledButtons = List.filled(CHARACTER_ORDER.length, false);
  bool _showFullImage = false;
  bool _useNormalImage = true;
  bool? _nextUseNormalImage;
  bool _isDrawerOpen = false;
  String? _selectedCharacter;
  int _score = 0;
  int _totalQuestions = 0;

  @override
  void initState() {
    super.initState();
    _initGame();
  }
  
  Future<void> _initGame() async {
    await _gameService.loadCards();
    _gameService.checkForCardUpdatesInBackground();
    _loadGame();
  }

  @override
  void dispose() {
    super.dispose();
  }

  void _loadGame() {
    _clearPreviousCardCache();
    
    setState(() {
      _isRevealed = false;
      _isAnswered = false;
      _disabledButtons = List.filled(CHARACTER_ORDER.length, false);
      _showFullImage = false;
      _fragmentOffsetX = 0.25 + Random().nextDouble() * 0.5;
      _fragmentOffsetY = 0.25 + Random().nextDouble() * 0.5;
      _selectedCharacter = null;
    });

    if (_nextCard != null) {
      _currentCard = _nextCard;
      _useNormalImage = _nextUseNormalImage ?? Random().nextBool();
      _nextCard = null;
      _nextUseNormalImage = null;
    } else {
      _currentCard = _gameService.getRandomCard();
      _useNormalImage = Random().nextBool();
    }

    if (_currentCard != null) {
      _currentImageUrl = _useNormalImage 
          ? _currentCard!.normalUrl 
          : _currentCard!.afterUrl;
    }
  }

  void _clearPreviousCardCache() {
    if (_currentCard != null) {
      DefaultCacheManager().removeFile(_currentCard!.normalUrl);
      if (_currentCard!.afterUrl.isNotEmpty && _currentCard!.afterUrl != _currentCard!.normalUrl) {
        DefaultCacheManager().removeFile(_currentCard!.afterUrl);
      }
    }
    if (_nextCard != null) {
      DefaultCacheManager().removeFile(_nextCard!.normalUrl);
      if (_nextCard!.afterUrl.isNotEmpty && _nextCard!.afterUrl != _nextCard!.normalUrl) {
        DefaultCacheManager().removeFile(_nextCard!.afterUrl);
      }
    }
  }

  void _pickNextCard() {
    final nextCard = _gameService.getRandomCard();
    if (nextCard != null) {
      _nextCard = nextCard;
      _nextUseNormalImage = Random().nextBool();
    }
  }

  void _selectCardFromDrawer(CardData card, bool isNormal) {
    setState(() {
      _nextCard = null;
      _nextUseNormalImage = null;
      _currentCard = card;
      _currentImageUrl = isNormal ? card.normalUrl : card.afterUrl;
      _useNormalImage = isNormal;
      _isRevealed = true;
      _isAnswered = true;
      _showFullImage = true;
      _selectedCharacter = card.character;
      _disabledButtons[CHARACTER_ORDER.indexOf(card.character)] = true;
      _isDrawerOpen = false;
      _score++;
      _totalQuestions++;
    });
  }

  int _retryCount = 0;
  static const int _maxRetries = 2;

  void _onImageLoadFailed() {
    _retryCount++;
    if (_retryCount < _maxRetries) {
      Future.delayed(const Duration(milliseconds: 500), () {
        if (_currentImageUrl != null) {
          setState(() {});
        }
      });
    } else {
      _retryCount = 0;
      if (_currentCard != null) {
        _gameService.markCardFailed(_currentCard!.id);
      }
      Future.delayed(const Duration(milliseconds: 500), () {
        _loadGame();
      });
    }
  }

  

  void _onCharacterSelected(String character) {
    if (_isAnswered || _disabledButtons[CHARACTER_ORDER.indexOf(character)]) {
      return;
    }

    final index = CHARACTER_ORDER.indexOf(character);

    setState(() {
      _disabledButtons[index] = true;

      if (_gameService.isCorrectCharacter(_currentCard!, character)) {
        _isAnswered = true;
        _isRevealed = true;
        _selectedCharacter = character;
        _score++;
      } else {
        _selectedCharacter = character;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('答错了！继续尝试'),
            duration: Duration(seconds: 2),
          ),
        );
      }
      _totalQuestions++;
    });
  }

  void _onNextQuestion() {
    Future.delayed(const Duration(milliseconds: 300), () {
      _loadGame();
    });
  }

  void _onToggleFullImage() {
    setState(() {
      _showFullImage = !_showFullImage;
    });
  }

  Future<void> _downloadImage(String url, String filename) async {
    try {
      final response = await http.get(Uri.parse(url));
      if (response.statusCode == 200) {
        String savePath = '/storage/emulated/0/Download/';
        
        if (Platform.isIOS) {
          savePath = (await getApplicationDocumentsDirectory()).path + '/';
        }
        
        final downloadsDir = Directory(savePath);
        if (!downloadsDir.existsSync()) {
          downloadsDir.createSync(recursive: true);
        }
        
        final cardId = _currentCard?.id ?? 'unknown';
        final safeFilename = '$cardId-$filename';
        final filePath = '${downloadsDir.path}$safeFilename';
        
        final file = File(filePath);
        await file.writeAsBytes(response.bodyBytes);
        
        if (Platform.isAndroid) {
          await _scanFile(filePath);
        }
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('已保存到: $savePath$safeFilename'),
            duration: const Duration(seconds: 4),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('下载失败')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('保存失败: ${e.toString()}')),
      );
    }
  }

  Future<void> _scanFile(String path) async {
    try {
      await Process.run('am', ['scan', '-p', path]);
    } catch (_) {}
  }

  Widget _buildFragmentImage() {
    if (_currentImageUrl == null || _currentImageUrl!.isEmpty) {
      return const Center(
        child: Text(
          '无法加载图片',
          style: TextStyle(fontSize: 18, color: Colors.red),
        ),
      );
    }

    final scale = 1 / _fragmentSize;

    return Container(
      width: double.infinity,
      height: 350,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black26,
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Transform.scale(
          scale: scale,
          alignment: Alignment(_fragmentOffsetX * 2 - 1, _fragmentOffsetY * 2 - 1),
          child: CachedNetworkImage(
            imageUrl: _currentImageUrl!,
            fit: BoxFit.contain,
            width: MediaQuery.of(context).size.width,
            height: MediaQuery.of(context).size.width,
            cacheManager: DefaultCacheManager(),
            placeholder: (context, url) => const Center(child: CircularProgressIndicator()),
            errorWidget: (context, url, error) {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                _onImageLoadFailed();
              });
              return const Center(
                child: Text(
                  '图片加载失败',
                  style: TextStyle(fontSize: 16, color: Colors.red),
                ),
              );
            },
            fadeInDuration: const Duration(milliseconds: 300),
            cacheKey: _currentImageUrl!,
          ),
        ),
      ),
    );
  }

  Widget _buildRevealedImages() {
    if (_currentCard == null) {
      return const SizedBox();
    }

    final hasAfterUrl = _currentCard!.afterUrl != null && _currentCard!.afterUrl!.isNotEmpty && _currentCard!.afterUrl != _currentCard!.normalUrl;

    return Column(
      children: [
        Container(
          width: double.infinity,
          height: 200,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: Colors.black26,
                blurRadius: 8,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: CachedNetworkImage(
              imageUrl: _currentCard!.normalUrl,
              fit: BoxFit.contain,
              cacheManager: DefaultCacheManager(),
              placeholder: (context, url) => const Center(child: CircularProgressIndicator()),
              errorWidget: (context, url, error) => const Center(child: Text('加载失败')),
              fadeInDuration: const Duration(milliseconds: 300),
            ),
          ),
        ),
        const SizedBox(height: 4),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text(
              '特训前',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.blue),
            ),
            const SizedBox(width: 8),
            ElevatedButton(
              onPressed: () => _downloadImage(_currentCard!.normalUrl, '特训前.png'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.transparent,
                foregroundColor: Colors.blue,
                padding: const EdgeInsets.symmetric(vertical: 2, horizontal: 6),
                elevation: 0,
              ),
              child: const Text('下载'),
            ),
          ],
        ),
        if (hasAfterUrl) ...[
          const SizedBox(height: 12),
          Container(
            width: double.infinity,
            height: 200,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: Colors.black26,
                  blurRadius: 8,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: CachedNetworkImage(
              imageUrl: _currentCard!.afterUrl!,
              fit: BoxFit.contain,
              cacheManager: DefaultCacheManager(),
              placeholder: (context, url) => const Center(child: CircularProgressIndicator()),
              errorWidget: (context, url, error) => const Center(child: Text('加载失败')),
              fadeInDuration: const Duration(milliseconds: 300),
            ),
          ),
        ),
        const SizedBox(height: 4),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text(
              '特训后',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.purple),
            ),
            const SizedBox(width: 8),
              ElevatedButton(
                onPressed: () => _downloadImage(_currentCard!.afterUrl!, '特训后.png'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.transparent,
                  foregroundColor: Colors.purple,
                  padding: const EdgeInsets.symmetric(vertical: 2, horizontal: 6),
                  elevation: 0,
                ),
                child: const Text('下载'),
              ),
            ],
          ),
        ],
      ],
    );
  }

  Widget _buildCharacterButtons() {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: CHARACTER_ORDER.map((character) {
        final index = CHARACTER_ORDER.indexOf(character);
        final isCorrect = _isRevealed && _currentCard?.character == character;
        final isDisabled = _disabledButtons[index];

        return OutlinedButton(
          onPressed: isDisabled ? null : () => _onCharacterSelected(character),
          style: OutlinedButton.styleFrom(
            backgroundColor: isCorrect ? Colors.green[100] : Colors.transparent,
            foregroundColor: isCorrect ? Colors.green : (isDisabled ? Colors.grey : Colors.blue),
            side: BorderSide(
              color: isCorrect ? Colors.green : (isDisabled ? Colors.grey : Colors.blue),
              width: 2,
            ),
            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            elevation: 0,
          ),
          child: Text(
            character,
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        );
      }).toList(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('猜角色小游戏'),
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Text(
              '$_score/$_totalQuestions',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.menu),
            onPressed: () {
              setState(() {
                _isDrawerOpen = !_isDrawerOpen;
              });
            },
          ),
        ],
      ),
      body: Container(
        decoration: const BoxDecoration(
          image: DecorationImage(
            image: AssetImage('assets/bg_game.jpeg'),
            fit: BoxFit.cover,
            alignment: Alignment.topCenter,
          ),
        ),
        child: Row(
        children: [
          if (_isDrawerOpen)
            SizedBox(
              width: 300,
              child: Drawer(
                child: Column(
                  children: [
                    const DrawerHeader(
                      child: Text('选择角色'),
                    ),
                    Expanded(
                      child: ListView.builder(
                        itemCount: _gameService.allCharacters.length,
                        itemBuilder: (context, index) {
                          final character = _gameService.allCharacters[index];
                          return ExpansionTile(
                            title: Text(character),
                            children: _gameService.getCardsForCharacter(character).map((card) {
                              return Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                child: SizedBox(
                                  width: double.infinity,
                                  child: GestureDetector(
                                    onTap: () => _selectCardFromDrawer(card, true),
                                    child: Container(
                                      width: double.infinity,
                                      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 14),
                                      decoration: BoxDecoration(
                                        border: Border.all(color: Colors.blue),
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: Text(
                                        card.cardName.isNotEmpty 
                                            ? card.cardName 
                                            : card.id,
                                        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.blue),
                                        textAlign: TextAlign.left,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ),
                                ),
                              );
                            }).toList(),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  const SizedBox(height: 8),
                  _isRevealed || _showFullImage
                      ? _buildRevealedImages()
                      : _buildFragmentImage(),
                  const SizedBox(height: 12),
                  if (_isRevealed && _currentCard != null)
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.green[100],
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        '正确答案: ${_currentCard?.character}',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.green,
                        ),
                      ),
                    ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      const Text(
                        '碎片大小: ',
                        style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                      ),
                      Expanded(
                        child: Slider(
                          value: _fragmentSize,
                          min: 0.1,
                          max: 0.6,
                          onChanged: (value) {
                            setState(() {
                              _fragmentSize = value;
                            });
                          },
                        ),
                      ),
                      Text(
                        '${(_fragmentSize * 100).round()}%',
                        style: TextStyle(fontSize: 14),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: _onNextQuestion,
                          style: OutlinedButton.styleFrom(
                            backgroundColor: Colors.white.withOpacity(0.3),
                            foregroundColor: Colors.black,
                            side: const BorderSide(color: Colors.black, width: 2),
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          child: const Text(
                            '抽取新卡',
                            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: OutlinedButton(
                        onPressed: _onToggleFullImage,
                        style: OutlinedButton.styleFrom(
                          backgroundColor: Colors.white.withOpacity(0.3),
                          foregroundColor: Colors.black,
                          side: const BorderSide(color: Colors.black, width: 2),
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        child: Text(
                          _showFullImage ? '隐藏原图' : '查看完整原图',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                      ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  _buildCharacterButtons(),
                  const SizedBox(height: 20),
                ],
              ),
            ),
          ),
        ],
      ),
    ),
    );
  }
}
