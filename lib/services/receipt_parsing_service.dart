import 'dart:convert';

import '../data/models/parsed_receipt.dart';

/// Common prompt used by both the local (Qwen on-device) and cloud (Gemini)
/// parsers. Explains the mlkit OCR quirk (text grouped by column block, not
/// interleaved line-by-line) so the model can realign item names to prices
/// by position/order rather than expecting them adjacent.
String buildReceiptParsingPrompt(String ocrText) {
  return '''
Eres un asistente que extrae datos estructurados de una factura de restaurante.
El texto de abajo viene de OCR (reconocimiento óptico) y puede tener errores
de tipeo o palabras pegadas. Además, el OCR a veces agrupa el texto por
columnas (todos los nombres de platos primero, después todos los precios en
el mismo orden) en vez de línea por línea — si ves eso, empareja cada nombre
con el precio que le corresponde por su posición/orden.

Responde ÚNICAMENTE con un objeto JSON (sin texto adicional, sin markdown,
sin ```) con esta forma exacta:
{
  "restaurantName": "string o null",
  "items": [
    {"name": "string", "quantity": number, "unitPrice": number, "lineTotal": number}
  ],
  "subtotal": number,
  "tax": number,
  "tip": number,
  "total": number
}

Si un campo no aparece en el texto, usa 0 (números) o null (restaurantName).
Si quantity no aparece, usa 1.

Texto OCR:
"""
$ocrText
"""
''';
}

/// Extracts the first top-level {...} JSON object from [text] — models
/// sometimes wrap the JSON in prose or markdown fences despite instructions.
Map<String, dynamic>? extractJsonObject(String text) {
  final start = text.indexOf('{');
  if (start == -1) return null;
  var depth = 0;
  for (var i = start; i < text.length; i++) {
    if (text[i] == '{') depth++;
    if (text[i] == '}') depth--;
    if (depth == 0) {
      final candidate = text.substring(start, i + 1);
      try {
        final decoded = jsonDecode(candidate);
        return decoded is Map<String, dynamic> ? decoded : null;
      } catch (_) {
        return null;
      }
    }
  }
  return null;
}

/// Implemented by the local (Qwen on-device) and cloud (Gemini) parsers.
abstract class ReceiptParsingService {
  Future<ParsedReceipt> parseReceipt(String ocrText);
}
