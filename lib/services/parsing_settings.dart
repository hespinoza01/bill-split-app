import 'package:shared_preferences/shared_preferences.dart';

import 'gemini_parsing_service.dart';
import 'local_parsing_service.dart';
import 'openai_compatible_parsing_service.dart';
import 'receipt_parsing_service.dart';
import 'secure_key_store.dart';

enum ParsingEngine { localQwen, localDeepSeek, gemini, groq, customOpenAi }

const groqBaseUrl = 'https://api.groq.com/openai/v1/chat/completions';
const groqDefaultModel = 'llama-3.3-70b-versatile';
const geminiDefaultModel = 'gemini-2.5-flash';

/// Qué motor de parseo usar (local u otro), y la config de cada proveedor
/// cloud (modelo, endpoint) — todo en SharedPreferences (no son secretos,
/// a diferencia de las API keys que viven en SecureKeyStore).
class ParsingSettings {
  static const _engineKey = 'parsing_engine';
  static const _geminiModelKey = 'gemini_model';
  static const _groqModelKey = 'groq_model';
  static const _customEndpointKey = 'custom_endpoint';
  static const _customModelKey = 'custom_model';

  Future<ParsingEngine> getEngine() async {
    final prefs = await SharedPreferences.getInstance();
    final stored = prefs.getString(_engineKey);
    return ParsingEngine.values.firstWhere(
      (e) => e.name == stored,
      orElse: () => ParsingEngine.localQwen,
    );
  }

  Future<void> setEngine(ParsingEngine engine) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_engineKey, engine.name);
  }

  Future<String> getGeminiModel() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_geminiModelKey) ?? geminiDefaultModel;
  }

  Future<void> setGeminiModel(String model) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_geminiModelKey, model);
  }

  Future<String> getGroqModel() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_groqModelKey) ?? groqDefaultModel;
  }

  Future<void> setGroqModel(String model) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_groqModelKey, model);
  }

  Future<String> getCustomEndpoint() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_customEndpointKey) ?? '';
  }

  Future<void> setCustomEndpoint(String endpoint) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_customEndpointKey, endpoint);
  }

  Future<String> getCustomModel() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_customModelKey) ?? '';
  }

  Future<void> setCustomModel(String model) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_customModelKey, model);
  }

  /// Arma el parser activo según el motor elegido. Si es un motor cloud sin
  /// key guardada (o "Otro" sin endpoint), cae al local Qwen — nunca deja a
  /// la app sin forma de parsear.
  Future<ReceiptParsingService> buildActiveParser() async {
    final engine = await getEngine();
    final keyStore = SecureKeyStore();

    switch (engine) {
      case ParsingEngine.localQwen:
        return const LocalParsingService(LocalModels.qwen);
      case ParsingEngine.localDeepSeek:
        return const LocalParsingService(LocalModels.deepSeekR1);
      case ParsingEngine.gemini:
        final key = await keyStore.getGeminiKey();
        if (key != null && key.isNotEmpty) {
          return GeminiParsingService(key, await getGeminiModel());
        }
      case ParsingEngine.groq:
        final key = await keyStore.getGroqKey();
        if (key != null && key.isNotEmpty) {
          return OpenAiCompatibleParsingService(baseUrl: groqBaseUrl, apiKey: key, model: await getGroqModel());
        }
      case ParsingEngine.customOpenAi:
        final key = await keyStore.getCustomKey();
        final endpoint = await getCustomEndpoint();
        if (key != null && key.isNotEmpty && endpoint.isNotEmpty) {
          return OpenAiCompatibleParsingService(baseUrl: endpoint, apiKey: key, model: await getCustomModel());
        }
    }
    return const LocalParsingService(LocalModels.qwen);
  }
}
