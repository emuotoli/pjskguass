import 'dart:convert';
import 'dart:math';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:guess_character_game_mobile_new/constants.dart';
import 'package:guess_character_game_mobile_new/card_info_map.dart';
import 'package:guess_character_game_mobile_new/card_names.dart';

const String CARD_BASE_URL = 'https://storage.exmeaning.com/sekai-jp-assets/character/member';
const String PREFS_KEY_LAST_CARD_ID = 'last_card_id';
const String PREFS_KEY_NEW_CARDS = 'new_cards_data';

const Map<String, String> RES_TO_CHARACTER = {
  '001': '星乃一歌',
  '002': '天马咲希',
  '003': '望月穗波',
  '004': '日野森志步',
  '005': '花里实乃理',
  '006': '桐谷遥',
  '007': '桃井爱莉',
  '008': '日野森雫',
  '009': '小豆泽心羽',
  '010': '白石杏',
  '011': '东云彰人',
  '012': '青柳冬弥',
  '013': '天马司',
  '014': '凤笑梦',
  '015': '草薙宁宁',
  '016': '神代类',
  '017': '宵崎奏',
  '018': '朝比奈真冬',
  '019': '东云绘名',
  '020': '晓山瑞希',
  '021': '初音未来',
  '022': '镜音铃',
  '023': '镜音连',
  '024': '巡音流歌',
  '025': 'MEIKO',
  '026': 'KAITO',
};

class CardData {
  final String id;
  final String character;
  final int rarity;
  final String normalUrl;
  final String afterUrl;
  final String cardName;

  CardData({
    required this.id,
    required this.character,
    required this.rarity,
    required this.normalUrl,
    required this.afterUrl,
    this.cardName = '',
  });
}

class GameService {
  static final GameService _instance = GameService._internal();
  factory GameService() => _instance;
  GameService._internal();

  List<CardData> _allCards = [];
  List<CardData> _validCards = [];
  bool _isLoaded = false;

  Future<bool> loadCards() async {
    if (_isLoaded) {
      return _validCards.isNotEmpty;
    }

    _allCards = [];
    _validCards = [];

    try {
      await _loadCardsFromJson();
    } catch (e) {
      print('Failed to load cards from JSON: $e');
      _loadCardsFromMap();
    }

    try {
      await _loadExtraCardsFromJson();
    } catch (e) {
      print('Failed to load extra cards: $e');
    }

    await _loadNewCardsFromPrefs();

    _allCards.sort((a, b) {
      final aNum = int.tryParse(a.id.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0;
      final bNum = int.tryParse(b.id.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0;
      return aNum.compareTo(bNum);
    });

    _isLoaded = true;
    return _validCards.isNotEmpty;
  }

  int getCardCount() {
    return _allCards.length;
  }

  List<CardData> getAllCards() {
    return List.from(_allCards);
  }

  CardData? getRandomCard() {
    if (_validCards.isEmpty) return null;
    return _validCards[Random().nextInt(_validCards.length)];
  }

  void markCardFailed(String cardId) {
  }

  bool isCorrectCharacter(CardData card, String character) {
    return card.character == character;
  }

  List<String> get allCharacters {
    return CHARACTER_ORDER;
  }

  List<CardData> getCardsForCharacter(String character) {
    return _allCards.where((card) => card.character == character).toList();
  }

  Future<void> checkForCardUpdatesInBackground({Function(String)? onProgress}) async {
    _reportProgress('🔍 开始检查卡面更新...', onProgress);

    try {
      final prefs = await SharedPreferences.getInstance();
      final savedIdStr = prefs.getString(PREFS_KEY_LAST_CARD_ID);
      int lastCardId = int.tryParse(savedIdStr ?? '1421') ?? 1421;

      _reportProgress('📦 上次保存的最后卡牌ID: $lastCardId', onProgress);

      final currentLocalIds = _allCards.map((card) {
        final match = RegExp(r'(\d+)').firstMatch(card.id);
        return match != null ? int.tryParse(match.group(1) ?? '0') ?? 0 : 0;
      }).toSet();

      int maxLocalId = currentLocalIds.isEmpty ? 0 : currentLocalIds.reduce((a, b) => a > b ? a : b);
      _reportProgress('📦 本地最大卡牌ID: $maxLocalId', onProgress);

      List<CardData> newCards = [];
      int consecutiveFailures = 0;
      const maxConsecutiveFailures = 5;

      _reportProgress('🔍 从ID ${lastCardId + 1} 开始检查...', onProgress);

      for (int id = lastCardId + 1; ; id++) {
        if (currentLocalIds.contains(id)) {
          _reportProgress('⏭️ ID $id 已存在本地', onProgress);
          lastCardId = id;
          continue;
        }

        _reportProgress('🔍 检查卡 ID $id...', onProgress);
        final cardData = await _fetchCardData(id.toString(), onProgress: onProgress);
        
        if (cardData != null) {
          if (!_allCards.any((c) => c.id == cardData.id)) {
            _allCards.add(cardData);
            
            if (cardData.character.isNotEmpty && (cardData.rarity >= 3 || cardData.rarity == 0)) {
              _validCards.add(cardData);
            }
            
            newCards.add(cardData);
            _reportProgress('🎉 添加新卡: ${cardData.character} ${cardData.cardName}', onProgress);
          }
          
          lastCardId = id;
          consecutiveFailures = 0;
        } else {
          consecutiveFailures++;
          _reportProgress('❌ ID $id 获取失败 (连续失败: $consecutiveFailures/$maxConsecutiveFailures)', onProgress);
          
          if (consecutiveFailures >= maxConsecutiveFailures) {
            _reportProgress('🛑 连续 $maxConsecutiveFailures 个ID无效，停止扫描', onProgress);
            break;
          }
        }
        
        await Future.delayed(Duration(milliseconds: 500));
      }
      
      _reportProgress('✅ 扫描完成', onProgress);

      if (newCards.isNotEmpty) {
        _validCards.sort((a, b) {
          final aNum = int.tryParse(a.id.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0;
          final bNum = int.tryParse(b.id.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0;
          return aNum.compareTo(bNum);
        });
        
        _allCards.sort((a, b) {
          final aNum = int.tryParse(a.id.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0;
          final bNum = int.tryParse(b.id.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0;
          return aNum.compareTo(bNum);
        });
        
        _reportProgress('🎉 成功添加 ${newCards.length} 张新卡!', onProgress);
        
        await _saveNewCardsToPrefs();
        
        await prefs.setString(PREFS_KEY_LAST_CARD_ID, lastCardId.toString());
        _reportProgress('📝 已保存最后卡牌ID: $lastCardId', onProgress);
      } else {
        _reportProgress('✅ 完成: 本地数据已是最新', onProgress);
      }
    } catch (e) {
      _reportProgress('❌ 更新失败: $e', onProgress);
    }
  }

  void _reportProgress(String message, Function(String)? onProgress) {
    print(message);
    if (onProgress != null) {
      onProgress(message);
    }
  }

  Future<CardData?> _fetchCardData(String id, {Function(String)? onProgress}) async {
    try {
      final response = await http.get(Uri.parse('$PJSK_MOE_BASE_URL/ja-JP/cards/$id/'));
      
      if (response.statusCode == 200) {
        final html = response.body;
        _reportProgress('📄 ID$id HTML长度: ${html.length}', onProgress);
        
        final titleMatch = RegExp(r'<title[^>]*>([^<]+)</title>', caseSensitive: false).firstMatch(html);
        final pageTitle = titleMatch?.group(1) ?? '';
        
        if (pageTitle == '卡牌详情 | Moesekai' || pageTitle == 'カード詳細 | Moesekai') {
          _reportProgress('❌ ID$id 页面标题为"卡牌详情"，无效卡牌', onProgress);
          return null;
        }
        
        final ogImageMatch = RegExp(r'<meta[^>]+property="og:image"[^>]+content="([^"]+)"', caseSensitive: false).firstMatch(html);
        final ogImageUrl = ogImageMatch?.group(1) ?? '';
        
        if (ogImageUrl.contains('pjsk.moe/data/icon/icon.jpg')) {
          _reportProgress('❌ ID$id og:image为通用图标，无效卡牌', onProgress);
          return null;
        }
        
        String character = '';
        String normalUrl = '';
        String afterUrl = '';
        String resourceId = id;
        String cardName = '';
        
        try {
          if (ogImageMatch != null) {
            _reportProgress('🖼️ ID$id 找到og:image', onProgress);
            final resourceIdMatch = RegExp(r'res(\d+)_no(\d+)').firstMatch(ogImageUrl);
            if (resourceIdMatch != null) {
              final resNum = resourceIdMatch.group(1)?.padLeft(3, '0') ?? '000';
              final noNum = resourceIdMatch.group(2)?.padLeft(3, '0') ?? '000';
              resourceId = 'res${resNum}_no${noNum}';
              character = RES_TO_CHARACTER[resNum] ?? '';
              
              normalUrl = '$CARD_BASE_URL/res${resNum}_no${noNum}/card_normal.webp';
              afterUrl = '$CARD_BASE_URL/res${resNum}_no${noNum}/card_after_training.webp';
              _reportProgress('✅ ID$id 从og解析: $resourceId', onProgress);
            }
          }
        } catch (e) {
          _reportProgress('❌ ID$id og:image解析失败: $e', onProgress);
        }
        
        if (resourceId.length < 12) {
          try {
            final internalAssetMatch = RegExp(r'Internal Asset Name\s*([^\n<]+)', caseSensitive: false).firstMatch(html);
            if (internalAssetMatch != null) {
              final assetName = internalAssetMatch.group(1)?.trim() ?? '';
              _reportProgress('📦 ID$id 找到Internal Asset: $assetName', onProgress);
              final resMatch = RegExp(r'res(\d+)_no(\d+)').firstMatch(assetName);
              if (resMatch != null) {
                final resNum = resMatch.group(1)?.padLeft(3, '0') ?? '000';
                final noNum = resMatch.group(2)?.padLeft(3, '0') ?? '000';
                resourceId = 'res${resNum}_no${noNum}';
                character = RES_TO_CHARACTER[resNum] ?? '';
                
                normalUrl = '$CARD_BASE_URL/res${resNum}_no${noNum}/card_normal.webp';
                afterUrl = '$CARD_BASE_URL/res${resNum}_no${noNum}/card_after_training.webp';
                _reportProgress('✅ ID$id 从Asset解析: $resourceId', onProgress);
              }
            }
          } catch (e) {
            _reportProgress('❌ ID$id Internal Asset解析失败: $e', onProgress);
          }
        }
        
        if (resourceId.length < 12) {
          try {
            final jsonDataMatch = RegExp(r'window\.__NEXT_DATA__\s*=\s*({.*});', multiLine: true, dotAll: true).firstMatch(html);
            if (jsonDataMatch != null) {
              final jsonStr = jsonDataMatch.group(1) ?? '';
              if (jsonStr.isNotEmpty && jsonStr.startsWith('{') && jsonStr.endsWith('}')) {
                try {
                  final jsonData = json.decode(jsonStr);
                  final props = jsonData['props']?['pageProps']?['data'];
                  if (props != null) {
                    final assetName = props['assetName'] ?? props['internalAssetName'] ?? '';
                    _reportProgress('📦 ID$id Next.js数据: $assetName', onProgress);
                    final resMatch = RegExp(r'res(\d+)_no(\d+)').firstMatch(assetName.toString());
                    if (resMatch != null) {
                      final resNum = resMatch.group(1)?.padLeft(3, '0') ?? '000';
                      final noNum = resMatch.group(2)?.padLeft(3, '0') ?? '000';
                      resourceId = 'res${resNum}_no${noNum}';
                      character = RES_TO_CHARACTER[resNum] ?? '';
                      
                      normalUrl = '$CARD_BASE_URL/res${resNum}_no${noNum}/card_normal.webp';
                      afterUrl = '$CARD_BASE_URL/res${resNum}_no${noNum}/card_after_training.webp';
                      _reportProgress('✅ ID$id 从Next.js解析: $resourceId', onProgress);
                    }
                  }
                } catch (e) {
                  _reportProgress('❌ ID$id Next.js JSON解析失败: $e', onProgress);
                }
              }
            }
          } catch (e) {
            _reportProgress('❌ ID$id Next.js正则匹配失败: $e', onProgress);
          }
        }
        
        int rarity = -1;
        try {
          final starMatch = RegExp(r'(\d+)★').firstMatch(html);
          final cnStarMatch = RegExp(r'(\d+)星').firstMatch(html);
          final raritySpanMatch = RegExp(r'rarity-(\d)').firstMatch(html);
          final rarityClassMatch = RegExp(r'class="[^"]*rarity[^"]*"[^>]*>(\d)').firstMatch(html);
          
          if (starMatch != null) {
            rarity = int.tryParse(starMatch.group(1) ?? '-1') ?? -1;
            _reportProgress('✅ ID$id 从★解析稀有度: $rarity', onProgress);
          } else if (cnStarMatch != null) {
            rarity = int.tryParse(cnStarMatch.group(1) ?? '-1') ?? -1;
            _reportProgress('✅ ID$id 从星解析稀有度: $rarity', onProgress);
          } else if (raritySpanMatch != null) {
            rarity = int.tryParse(raritySpanMatch.group(1) ?? '-1') ?? -1;
            _reportProgress('✅ ID$id 从rarity class解析稀有度: $rarity', onProgress);
          } else if (rarityClassMatch != null) {
            rarity = int.tryParse(rarityClassMatch.group(1) ?? '-1') ?? -1;
            _reportProgress('✅ ID$id 从class解析稀有度: $rarity', onProgress);
          }
          
          if (rarity == -1) {
            final birthdayMatch = RegExp(r'(?i)birthday').firstMatch(html);
            if (birthdayMatch != null) {
              rarity = 4;
              _reportProgress('✅ ID$id 识别为生日卡，稀有度设为4', onProgress);
            }
          }
        } catch (e) {
          _reportProgress('❌ ID$id 星级解析失败: $e', onProgress);
        }
        
        if (rarity == -1) {
          rarity = 3;
          _reportProgress('⚠️ ID$id 稀有度解析失败，默认设为3', onProgress);
        }
        
        if (normalUrl.isEmpty) {
          try {
            final resMatch = RegExp(r'res(\d+)_no(\d+)').firstMatch(resourceId);
            if (resMatch != null) {
              final resNum = resMatch.group(1)?.padLeft(3, '0') ?? '000';
              final noNum = resMatch.group(2)?.padLeft(3, '0') ?? '000';
              normalUrl = '$CARD_BASE_URL/res${resNum}_no${noNum}/card_normal.webp';
              afterUrl = '$CARD_BASE_URL/res${resNum}_no${noNum}/card_after_training.webp';
            }
          } catch (e) {
            _reportProgress('❌ ID$id URL构建失败: $e', onProgress);
          }
        }
        
        if (normalUrl.isEmpty) {
          _reportProgress('❌ ID$id 失败: normalUrl为空', onProgress);
          return null;
        }
        
        cardName = CARD_NAMES[resourceId] ?? '';
        if (cardName.isEmpty) {
          try {
            final titleMatch = RegExp(r'<title[^>]*>([^<]+)</title>', caseSensitive: false).firstMatch(html);
            if (titleMatch != null) {
              final title = titleMatch.group(1)?.trim() ?? '';
              final parts = title.split(' - ');
              if (parts.length >= 3) {
                cardName = parts[1].trim();
              } else if (parts.length == 2) {
                cardName = parts[1].trim();
              }
            }
          } catch (e) {
            _reportProgress('❌ ID$id 标题解析失败: $e', onProgress);
          }
        }
        
        if (cardName.isEmpty) {
          try {
            final nameMatch = RegExp(r'^#\s+(.+)$', multiLine: true).firstMatch(html);
            if (nameMatch != null) {
              cardName = nameMatch.group(1)?.trim() ?? '';
            }
          } catch (e) {
            _reportProgress('❌ ID$id 名称解析失败: $e', onProgress);
          }
        }
        
        if (cardName.isEmpty) {
          try {
            final nameMatch = RegExp(r'Name\s*([^\n<]+)', caseSensitive: false).firstMatch(html);
            if (nameMatch != null) {
              cardName = nameMatch.group(1)?.trim() ?? '';
            }
          } catch (e) {
            _reportProgress('❌ ID$id Name解析失败: $e', onProgress);
          }
        }
        
        final isBirthdayCard = cardName.toLowerCase().contains('birthday') || html.toLowerCase().contains('birthday');
        String displayName = '';
        
        if (cardName.isNotEmpty) {
          if (isBirthdayCard) {
            displayName = '生日 $cardName';
          } else {
            displayName = '${rarity}星 $cardName';
          }
        } else {
          displayName = '${rarity}星';
        }
        
        _reportProgress('✅ ID$id 成功: $character ($displayName)', onProgress);
        
        return CardData(
          id: resourceId,
          character: character,
          rarity: rarity,
          normalUrl: normalUrl,
          afterUrl: afterUrl.isNotEmpty ? afterUrl : normalUrl,
          cardName: displayName,
        );
      } else {
        _reportProgress('❌ ID$id 失败: HTTP ${response.statusCode}', onProgress);
      }
    } catch (e) {
      _reportProgress('❌ ID$id 错误: $e', onProgress);
    }
    
    return null;
  }

  Future<void> _loadCardsFromJson() async {
    final jsonString = await rootBundle.loadString('assets/data/cards.json');
    final List<dynamic> cardsJson = json.decode(jsonString);
    
    int addedCount = 0;
    for (final cardJson in cardsJson) {
      final cardId = cardJson['id'] ?? '';
      
      if (cardId.isEmpty) continue;
      
      if (_allCards.any((c) => c.id == cardId)) continue;
      
      final character = cardJson['character'] ?? '';
      final rawRarity = cardJson['star'] ?? cardJson['rarity'] ?? 3;
      final rarity = rawRarity is int ? rawRarity : int.tryParse(rawRarity.toString()) ?? 3;
      String normalUrl = '';
      String afterUrl = '';
      
      final images = cardJson['images'];
      if (images is List && images.isNotEmpty) {
        for (final img in images) {
          if (img is Map && img['type'] == 'normal') {
            normalUrl = img['url'] ?? img['fallback'] ?? '';
          } else if (img is Map && (img['type'] == 'after_training' || img['type'] == 'after')) {
            afterUrl = img['url'] ?? img['fallback'] ?? '';
          }
        }
      }
      
      if (normalUrl.isEmpty) {
        normalUrl = cardJson['normalUrl'] ?? '';
      }
      if (afterUrl.isEmpty) {
        afterUrl = cardJson['afterUrl'] ?? '';
      }
      
      String cardName = cardJson['cardName'] ?? cardJson['title'] ?? CARD_NAMES[cardId] ?? '';
      
      final isBirthdayCard = cardName.toLowerCase().contains('birthday');
      if (cardName.isNotEmpty) {
        if (isBirthdayCard) {
          cardName = '生日 $cardName';
        } else {
          cardName = '${rarity}星 $cardName';
        }
      } else {
        cardName = '${rarity}星';
      }
      
      final cardData = CardData(
        id: cardId,
        character: character,
        rarity: rarity is int ? rarity : 3,
        normalUrl: normalUrl,
        afterUrl: afterUrl.isNotEmpty ? afterUrl : normalUrl,
        cardName: cardName,
      );
      
      _allCards.add(cardData);
      
      if (cardData.character.isNotEmpty && (cardData.rarity >= 3 || cardData.rarity == 0)) {
        _validCards.add(cardData);
      }
      
      addedCount++;
    }
  }

  void _loadCardsFromMap() {
    int addedCount = 0;
    for (final entry in CARD_INFO_MAP.entries) {
      final cardId = entry.key;
      
      if (_allCards.any((c) => c.id == cardId)) continue;
      
      final info = entry.value;
      String cardName = info.cardName.isNotEmpty ? info.cardName : CARD_NAMES[cardId] ?? '';
      
      final isBirthdayCard = cardName.toLowerCase().contains('birthday');
      if (cardName.isNotEmpty) {
        if (isBirthdayCard) {
          cardName = '生日 $cardName';
        } else {
          cardName = '${info.rarity}星 $cardName';
        }
      } else {
        cardName = '${info.rarity}星';
      }
      
      final normalUrl = '$PJSK_API_BASE_URL/character/member/$cardId/card_normal.webp';
      final afterUrl = '$PJSK_API_BASE_URL/character/member/$cardId/card_after_training.webp';
      
      final cardData = CardData(
        id: cardId,
        character: info.character,
        rarity: info.rarity,
        normalUrl: normalUrl,
        afterUrl: afterUrl,
        cardName: cardName,
      );
      
      _allCards.add(cardData);
      
      if (cardData.character.isNotEmpty && (cardData.rarity >= 3 || cardData.rarity == 0)) {
        _validCards.add(cardData);
      }
      
      addedCount++;
    }
  }

  Future<void> _loadExtraCardsFromJson() async {
    final jsonString = await rootBundle.loadString('assets/data/extra_cards.json');
    final List<dynamic> cardsJson = json.decode(jsonString);
    
    int addedCount = 0;
    for (final cardJson in cardsJson) {
      final cardId = cardJson['id'] ?? '';
      
      if (cardId.isEmpty) continue;
      
      String existingCardName = '';
      int? existingRarity;
      final existingIndex = _allCards.indexWhere((c) => c.id == cardId);
      if (existingIndex != -1) {
        existingCardName = _allCards[existingIndex].cardName;
        existingRarity = _allCards[existingIndex].rarity;
        _allCards.removeAt(existingIndex);
        final validIndex = _validCards.indexWhere((c) => c.id == cardId);
        if (validIndex != -1) {
          _validCards.removeAt(validIndex);
        }
      }
      
      final character = cardJson['character'] ?? '';
      final rawRarity = cardJson['rarity'];
      final rarity = rawRarity is int ? rawRarity : int.tryParse(rawRarity.toString()) ?? 3;
      final hasNormal = cardJson['hasNormal'] ?? false;
      final hasAfter = cardJson['hasAfter'] ?? false;
      
      String normalUrl = '';
      String afterUrl = '';
      
      if (hasNormal) {
        normalUrl = '$CARD_BASE_URL/$cardId/card_normal.webp';
      }
      if (hasAfter) {
        afterUrl = '$CARD_BASE_URL/$cardId/card_after_training.webp';
      } else {
        afterUrl = normalUrl;
      }
      
      if (normalUrl.isEmpty) continue;
      
      bool isBirthdayCard = rarity == 0;
      
      String cardName = cardJson['cardName'] ?? CARD_NAMES[cardId] ?? '';
      
      if (cardName.isEmpty && existingCardName.isNotEmpty) {
        if (isBirthdayCard && existingRarity == 1) {
          cardName = existingCardName.replaceFirst(RegExp(r'^(1星)\s*'), '');
        } else if (existingCardName.startsWith('生日') || existingCardName.startsWith('4星')) {
          cardName = existingCardName.replaceFirst(RegExp(r'^(生日|4星)\s*'), '');
        } else if (existingCardName.startsWith('2星')) {
          cardName = existingCardName.replaceFirst('2星 ', '');
        } else {
          cardName = existingCardName;
        }
      }
      
      if (cardName.isNotEmpty) {
        final teamNames = ['Leo/need', 'MORE MORE JUMP！', 'Vivid BAD SQUAD', 'ワンダーランズ×ショウタイム', '25時、ナイトコードで。', '教室のセカイ', 'ステージのセカイ', 'ストリートのセカイ', 'ワンダーランドのセカイ', '誰もいないセカイ'];
        
        if (teamNames.contains(cardName) && rarity != 2) {
          cardName = '';
        }
        
        if (cardName.isNotEmpty) {
          if (isBirthdayCard) {
            if (!cardName.startsWith('生日')) {
              cardName = '生日 $cardName';
            }
          } else {
            if (!cardName.startsWith('${rarity}星')) {
              cardName = '${rarity}星 $cardName';
            }
          }
        }
      }
      
      if (cardName.isEmpty) {
        if (isBirthdayCard) {
          cardName = '生日';
        } else {
          cardName = '${rarity}星';
        }
      }
      
      final displayRarity = isBirthdayCard ? 4 : rarity;
      
      final cardData = CardData(
        id: cardId,
        character: character,
        rarity: displayRarity,
        normalUrl: normalUrl,
        afterUrl: afterUrl,
        cardName: cardName,
      );
      
      _allCards.add(cardData);
      
      if (cardData.character.isNotEmpty && (cardData.rarity >= 3 || cardData.rarity == 0)) {
        _validCards.add(cardData);
      }
      
      addedCount++;
    }
    
    print('Loaded $addedCount extra cards');
  }

  Future<void> _saveNewCardsToPrefs() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cardsJson = _allCards.map((card) => {
        'id': card.id,
        'character': card.character,
        'rarity': card.rarity,
        'normalUrl': card.normalUrl,
        'afterUrl': card.afterUrl,
        'cardName': card.cardName,
      }).toList();
      await prefs.setString(PREFS_KEY_NEW_CARDS, json.encode(cardsJson));
      print('Saved ${cardsJson.length} cards to prefs');
    } catch (e) {
      print('Failed to save cards: $e');
    }
  }

  Future<void> _loadNewCardsFromPrefs() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cardsJsonStr = prefs.getString(PREFS_KEY_NEW_CARDS);
      if (cardsJsonStr != null) {
        final List<dynamic> cardsJson = json.decode(cardsJsonStr);
        int loadedCount = 0;
        for (final cardJson in cardsJson) {
          final cardId = cardJson['id'] ?? '';
          if (cardId.isEmpty) continue;
          if (_allCards.any((c) => c.id == cardId)) continue;
          
          final normalUrl = cardJson['normalUrl'] ?? '';
          if (normalUrl.isEmpty) continue;
          
          final cardData = CardData(
            id: cardId,
            character: cardJson['character'] ?? '',
            rarity: cardJson['rarity'] is int ? cardJson['rarity'] : 3,
            normalUrl: normalUrl,
            afterUrl: cardJson['afterUrl'] ?? '',
            cardName: cardJson['cardName'] ?? '',
          );
          
          _allCards.add(cardData);
          if (cardData.character.isNotEmpty && (cardData.rarity >= 3 || cardData.rarity == 0)) {
            _validCards.add(cardData);
          }
          loadedCount++;
        }
        print('Loaded $loadedCount cards from prefs');
      }
    } catch (e) {
      print('Failed to load cards from prefs: $e');
    }
  }
}