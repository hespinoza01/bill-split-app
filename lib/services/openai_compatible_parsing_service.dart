import 'dart:convert';

import 'package:http/http.dart' as http;

import '../data/models/parsed_receipt.dart';
import 'receipt_parsing_service.dart';

/// Cualquier proveedor cloud que hable el protocolo de OpenAI
/// (`/chat/completions` + `response_format: json_object`) — sirve tanto
/// para Groq (baseUrl fijo, solo cambia key/modelo) como para "Otro"
/// (baseUrl también editable por el usuario: OpenRouter, un servidor
/// propio, lo que sea). Una sola implementación evita duplicar el mismo
/// código de request/response dos veces.
class OpenAiCompatibleParsingService implements ReceiptParsingService {
  final String baseUrl;
  final String apiKey;
  final String model;

  OpenAiCompatibleParsingService({required this.baseUrl, required this.apiKey, required this.model});

  @override
  Future<ParsedReceipt> parseReceipt(String ocrText) async {
    final uri = Uri.parse(baseUrl);
    final body = jsonEncode({
      'model': model,
      'messages': [
        {'role': 'user', 'content': buildReceiptParsingPrompt(ocrText)},
      ],
      'response_format': {'type': 'json_object'},
      'temperature': 0.1,
    });

    final response = await http
        .post(uri, headers: {'Content-Type': 'application/json', 'Authorization': 'Bearer $apiKey'}, body: body)
        .timeout(const Duration(seconds: 30));

    if (response.statusCode != 200) {
      throw OpenAiCompatibleApiException(response.statusCode, response.body);
    }

    final decoded = jsonDecode(response.body) as Map<String, dynamic>;
    final choices = decoded['choices'] as List?;
    if (choices == null || choices.isEmpty) {
      throw const FormatException('El proveedor no devolvió choices');
    }
    final content = choices[0]['message']['content'] as String;
    // response_format json_object debería garantizar JSON puro, pero
    // igual usamos extractJsonObject por si algún proveedor agrega texto
    // extra pese a pedirlo — mismo patrón defensivo que Gemini/local.
    final json = extractJsonObject(content);
    if (json == null) {
      throw const FormatException('El proveedor no devolvió JSON válido');
    }
    return ParsedReceipt.fromJson(json);
  }

  /// Convención estándar OpenAI: el endpoint de listado vive en la misma
  /// base que `/chat/completions`, reemplazando ese sufijo por `/models`.
  /// No todo servidor "compatible" lo implementa (sobre todo endpoints
  /// custom) — el caller decide qué hacer si esto falla (fallback a texto
  /// libre), acá solo se intenta.
  static Future<List<String>> listModels(String chatCompletionsUrl, String apiKey) async {
    final modelsUrl = chatCompletionsUrl.replaceFirst(RegExp(r'/chat/completions/?$'), '/models');
    final uri = Uri.parse(modelsUrl);
    final response = await http.get(uri, headers: {'Authorization': 'Bearer $apiKey'}).timeout(
      const Duration(seconds: 15),
    );
    if (response.statusCode != 200) {
      throw OpenAiCompatibleApiException(response.statusCode, response.body);
    }
    final decoded = jsonDecode(response.body) as Map<String, dynamic>;
    final data = (decoded['data'] as List?) ?? const [];
    return data.cast<Map<String, dynamic>>().map((m) => m['id'] as String).toList();
  }
}

class OpenAiCompatibleApiException implements Exception {
  final int statusCode;
  final String body;
  OpenAiCompatibleApiException(this.statusCode, this.body);

  @override
  String toString() => 'OpenAiCompatibleApiException($statusCode): $body';
}
