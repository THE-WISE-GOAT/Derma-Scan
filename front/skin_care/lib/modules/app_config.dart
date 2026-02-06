import 'package:shared_preferences/shared_preferences.dart';

class AppConfig {
  static const String keyApiBaseUrl = 'apiBaseUrl';
  static const String keyOllamaBaseUrl = 'ollamaBaseUrl';

  static Future<String?> getApiBaseUrl() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(keyApiBaseUrl);
  }

  static Future<void> setApiBaseUrl(String? value) async {  // ✅ Nullable
    final prefs = await SharedPreferences.getInstance();
    if (value == null) {
      await prefs.remove(keyApiBaseUrl);
    } else {
      await prefs.setString(keyApiBaseUrl, value);
    }
  }

  static Future<String?> getOllamaBaseUrl() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(keyOllamaBaseUrl);
  }

  static Future<void> setOllamaBaseUrl(String? value) async {  // ✅ Nullable + FIXED
    final prefs = await SharedPreferences.getInstance();
    if (value == null) {
      await prefs.remove(keyOllamaBaseUrl);
    } else {
      await prefs.setString(keyOllamaBaseUrl, value);
    }
  }
}
