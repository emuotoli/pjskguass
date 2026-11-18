import 'package:shared_preferences/shared_preferences.dart';

class CacheSettings {
  static const String PREF_CACHE_EXPIRE_DAYS = 'cache_expire_days';
  static const String PREF_CACHE_MAX_SIZE_MB = 'cache_max_size_mb';

  static Future<int> getExpireDays() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(PREF_CACHE_EXPIRE_DAYS) ?? 7;
  }

  static Future<void> setExpireDays(int days) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(PREF_CACHE_EXPIRE_DAYS, days);
  }

  static Future<int> getMaxSizeMB() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(PREF_CACHE_MAX_SIZE_MB) ?? 100;
  }

  static Future<void> setMaxSizeMB(int sizeMB) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(PREF_CACHE_MAX_SIZE_MB, sizeMB);
  }

  static List<Map<String, dynamic>> expireOptions = [
    {'value': 1, 'label': '1天'},
    {'value': 7, 'label': '7天'},
    {'value': 30, 'label': '30天'},
    {'value': -1, 'label': '永不过期'},
  ];

  static List<Map<String, dynamic>> sizeOptions = [
    {'value': 10, 'label': '10MB'},
    {'value': 100, 'label': '100MB'},
    {'value': 1024, 'label': '1GB'},
    {'value': -1, 'label': '无限制'},
  ];
}