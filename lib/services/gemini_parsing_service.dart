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
    final firstAttempt = await _callGemini(buildReceiptParsingPrompt(ocrText));
    final parsed = _tryParse(firstAttempt);
    if (parsed != null) return parsed;

    // Mismo mitigador que el parser local: un modelo de la familia Gemma
    // (visible en el dropdown si Google lo expone con generateContent) no
    // siempre respeta responseSchema y puede devolver JSON válido pero
    // vacío — antes esto se tragaba en silencio como "factura de 0 items".
    final stricterPrompt =
        '${buildReceiptParsingPrompt(ocrText)}\n\nIMPORTANTE: extrae TODOS los ítems y montos reales '
        'del texto de arriba. No devuelvas un JSON vacío ni todo en cero — el texto SÍ tiene datos. '
        'Responde ÚNICAMENTE el objeto JSON, sin texto antes o después.';
    final secondAttempt = await _callGemini(stricterPrompt);
    final retryParsed = _tryParse(secondAttempt);
    if (retryParsed == null) {
      throw const FormatException(
        'El modelo no devolvió datos válidos. Probá con un modelo "gemini-..." '
        '(no "gemma-...") — Gemma no siempre respeta el formato JSON que pide la app.',
      );
    }
    return retryParsed;
  }

  ParsedReceipt? _tryParse(Map<String, dynamic> json) {
    final receipt = ParsedReceipt.fromJson(json);
    final looksEmpty = receipt.items.isEmpty && receipt.total == 0 && receipt.subtotal == 0;
    if (looksEmpty) return null;
    return receipt;
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

    // Mismo motivo que OpenAiCompatibleParsingService: 30s corta modelos
    // lentos/de razonamiento antes de responder.
    final response = await http
        .post(uri, headers: {'Content-Type': 'application/json'}, body: body)
        .timeout(const Duration(seconds: 90));

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
        // El endpoint también expone la familia Gemma (y otros no-chat) bajo
        // el mismo v1beta/models — no siempre respetan responseSchema y
        // devuelven JSON vacío (bug real reportado). Solo mostramos
        // gemini-* en el dropdown; el usuario puede seguir escribiendo otro
        // ID a mano vía el fallback de texto libre si de verdad lo quiere.
        .where((id) => id.startsWith('gemini-'))
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
