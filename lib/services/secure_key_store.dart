import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Persists the user's own cloud API keys locally (Keychain on iOS,
/// EncryptedSharedPreferences/Keystore-backed on Android). Pasted once in
/// Settings; never hardcoded, never sent anywhere but the provider's API.
class SecureKeyStore {
  static const _geminiKeyName = 'gemini_api_key';
  static const _groqKeyName = 'groq_api_key';
  static const _customKeyName = 'custom_api_key';
  final _storage = const FlutterSecureStorage();

  Future<String?> getGeminiKey() => _storage.read(key: _geminiKeyName);
  Future<void> setGeminiKey(String key) => _storage.write(key: _geminiKeyName, value: key);
  Future<void> clearGeminiKey() => _storage.delete(key: _geminiKeyName);

  Future<String?> getGroqKey() => _storage.read(key: _groqKeyName);
  Future<void> setGroqKey(String key) => _storage.write(key: _groqKeyName, value: key);
  Future<void> clearGroqKey() => _storage.delete(key: _groqKeyName);

  Future<String?> getCustomKey() => _storage.read(key: _customKeyName);
  Future<void> setCustomKey(String key) => _storage.write(key: _customKeyName, value: key);
  Future<void> clearCustomKey() => _storage.delete(key: _customKeyName);
}
