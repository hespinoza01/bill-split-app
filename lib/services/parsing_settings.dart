import 'package:shared_preferences/shared_preferences.dart';

import 'gemini_parsing_service.dart';
import 'local_parsing_service.dart';
import 'receipt_parsing_service.dart';
import 'secure_key_store.dart';

/// Whether the user opted into cloud parsing (Gemini) instead of the
/// on-device default (Qwen). Stored as a plain preference — not a secret,
/// unlike the API key itself (see SecureKeyStore).
class ParsingSettings {
  static const _useGeminiKey = 'use_gemini_cloud';

  Future<bool> getUseGemini() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_useGeminiKey) ?? false;
  }

  Future<void> setUseGemini(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_useGeminiKey, value);
  }

  /// Builds the active parser per current settings. Falls back to the local
  /// parser if Gemini is selected but no key is stored yet.
  Future<ReceiptParsingService> buildActiveParser() async {
    final useGemini = await getUseGemini();
    if (useGemini) {
      final key = await SecureKeyStore().getGeminiKey();
      if (key != null && key.isNotEmpty) return GeminiParsingService(key);
    }
    return LocalParsingService();
  }
}
