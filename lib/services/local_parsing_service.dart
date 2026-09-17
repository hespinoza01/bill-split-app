import 'package:flutter_gemma/flutter_gemma.dart';

import '../data/models/parsed_receipt.dart';
import 'receipt_parsing_service.dart';

/// On-device parsing via Qwen 2.5 1.5B (public model, no HuggingFace auth
/// needed) through flutter_gemma/MediaPipe. Default parser — zero setup
/// friction for whoever installs the app, works fully offline after the
/// one-time model download.
class LocalParsingService implements ReceiptParsingService {
  static const modelFileName =
      'Qwen2.5-1.5B-Instruct_multi-prefill-seq_q8_ekv1280.task';
  static const modelUrl =
      'https://huggingface.co/litert-community/Qwen2.5-1.5B-Instruct/resolve/main/$modelFileName';

  static Future<bool> isModelInstalled() => FlutterGemma.isModelInstalled(modelFileName);

  /// Downloads the model file if missing, AND (re)registers it as the
  /// active inference model — `getActiveModel()` needs that in-memory
  /// registration on every fresh app process, it does not persist across
  /// restarts even though the downloaded file itself does. When the file
  /// is already on disk this completes almost instantly (no re-download).
  static Future<void> ensureModelInstalled({void Function(int percent)? onProgress}) async {
    await FlutterGemma.installModel(modelType: ModelType.qwen)
        .fromNetwork(modelUrl)
        .withProgress((p) => onProgress?.call(p))
        .install();
  }

  @override
  Future<ParsedReceipt> parseReceipt(String ocrText) async {
    await ensureModelInstalled();
    final firstAttempt = await _runInference(buildReceiptParsingPrompt(ocrText));
    final parsed = _tryParse(firstAttempt);
    if (parsed != null) return parsed;

    // Reintento único con recordatorio más estricto — mitiga el caso donde
    // el modelo agrega texto extra, corta el JSON, o devuelve un JSON
    // válido pero vacío/degenerado en vez de los datos reales.
    final stricterPrompt =
        '${buildReceiptParsingPrompt(ocrText)}\n\nIMPORTANTE: extrae TODOS los ítems y montos reales '
        'del texto de arriba. No devuelvas un JSON vacío ni todo en cero — el texto SÍ tiene datos. '
        'Responde ÚNICAMENTE el objeto JSON, sin texto antes o después.';
    final secondAttempt = await _runInference(stricterPrompt);
    final retryParsed = _tryParse(secondAttempt);
    if (retryParsed == null) {
      throw const FormatException('El modelo local no devolvió datos válidos tras reintentar');
    }
    return retryParsed;
  }

  /// Rechaza tanto JSON malformado como JSON válido pero vacío/degenerado
  /// (sin ítems y todo en cero) — ambos son señal de que el modelo no
  /// extrajo nada útil, no de que la factura esté realmente vacía (eso ya
  /// se filtra antes de llamar al parser, ver CaptureScreen).
  ParsedReceipt? _tryParse(String rawResponse) {
    final json = extractJsonObject(rawResponse);
    if (json == null) return null;
    final receipt = ParsedReceipt.fromJson(json);
    final looksEmpty = receipt.items.isEmpty && receipt.total == 0 && receipt.subtotal == 0;
    if (looksEmpty) return null;
    return receipt;
  }

  Future<String> _runInference(String prompt) async {
    final model = await FlutterGemma.getActiveModel(
      maxTokens: 2048,
      preferredBackend: PreferredBackend.cpu,
    );
    final session = await model.createSession(temperature: 0.1, topK: 1);
    try {
      await session.addQueryChunk(Message.text(text: prompt, isUser: true));
      return await session.getResponse();
    } finally {
      await session.close();
    }
  }
}
