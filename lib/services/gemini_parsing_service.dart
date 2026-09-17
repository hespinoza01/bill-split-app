import 'dart:convert';

import 'package:http/http.dart' as http;

import '../data/models/parsed_receipt.dart';
import 'receipt_parsing_service.dart';

/// Optional cloud parser (Gemini free tier). REST calls only — no SDK
/// dependency, everything isolated here so swapping the endpoint shape is a
/// one-file change. Only used when the user opts in and pastes their own
/// API key + elige un modelo en Settings — el modelo NO está hardcodeado acá
/// (Google descontinúa modelos cada pocos meses; hardcodear uno es una fecha
/// de caducidad garantizada, como pasó con gemini-2.0-flash).
class GeminiParsingService implements ReceiptParsingService {
  static const _baseUrl = 'https://generativelanguage.googleapis.com/v1beta';

  final String apiKey;
  final String model;

  GeminiParsingService(this.apiKey, this.model);

  static const _responseSchema = {
    'type': 'OBJECT',
    'properties': {
      'restaurantName': {'type': 'STRING', 'nullable': true},
      'items': {
        'type': 'ARRAY',
        'items': {
          'type': 'OBJECT',
          'properties': {
            'name': {'type': 'STRING'},
            'quantity': {'type': 'NUMBER'},
            'unitPrice': {'type': 'NUMBER'},
            'lineTotal': {'type': 'NUMBER'},
          },
          'required': ['name', 'lineTotal'],
        },
      },
      'subtotal': {'type': 'NUMBER'},
      'tax': {'type': 'NUMBER'},
      'tip': {'type': 'NUMBER'},
      'total': {'type': 'NUMBER'},
    },
    'required': ['items', 'total'],
  };

  @override
  Future<ParsedReceipt> parseReceipt(String ocrText) async {
    final json = await _callGemini(buildReceiptParsingPrompt(ocrText));
    return ParsedReceipt.fromJson(json);
  }

  Future<Map<String, dynamic>> _callGemini(String prompt) async {
    final uri = Uri.parse('$_baseUrl/models/$model:generateContent?key=$apiKey');
    final body = jsonEncode({
      'contents': [
        {
          'parts': [
            {'text': prompt},
          ],
        },
      ],
      'generationConfig': {
        'responseMimeType': 'application/json',
        'responseSchema': _responseSchema,
      },
    });

    final response = await http
        .post(uri, headers: {'Content-Type': 'application/json'}, body: body)
        .timeout(const Duration(seconds: 30));

    if (response.statusCode != 200) {
      throw GeminiApiException(response.statusCode, response.body);
    }

    final decoded = jsonDecode(response.body) as Map<String, dynamic>;
    final candidates = decoded['candidates'] as List?;
    if (candidates == null || candidates.isEmpty) {
      throw const FormatException('Gemini no devolvió candidatos');
    }
    final text = candidates[0]['content']['parts'][0]['text'] as String;
    return jsonDecode(text) as Map<String, dynamic>;
  }

  /// Consulta a Google los modelos realmente disponibles con esta key ahora
  /// mismo — así Settings puede mostrar un dropdown con IDs reales en vez
  /// de un texto libre propenso a typos (o a nombres ya descontinuados).
  static Future<List<String>> listModels(String apiKey) async {
    final uri = Uri.parse('$_baseUrl/models?key=$apiKey&pageSize=200');
    final response = await http.get(uri).timeout(const Duration(seconds: 15));
    if (response.statusCode != 200) {
      throw GeminiApiException(response.statusCode, response.body);
    }
    final decoded = jsonDecode(response.body) as Map<String, dynamic>;
    final models = (decoded['models'] as List?) ?? const [];
    return models
        .cast<Map<String, dynamic>>()
        .where((m) => (m['supportedGenerationMethods'] as List?)?.contains('generateContent') ?? false)
        .map((m) => (m['name'] as String).replaceFirst('models/', ''))
        .toList();
  }
}

class GeminiApiException implements Exception {
  final int statusCode;
  final String body;
  GeminiApiException(this.statusCode, this.body);

  @override
  String toString() => 'GeminiApiException($statusCode): $body';
}
