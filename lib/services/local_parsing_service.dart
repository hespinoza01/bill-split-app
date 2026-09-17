import 'package:flutter_gemma/flutter_gemma.dart';

import '../data/models/parsed_receipt.dart';
import 'receipt_parsing_service.dart';

/// Un modelo local instalable — así `LocalParsingService` sirve para
/// cualquiera de ellos en vez de estar hardcodeada a uno solo.
class LocalModelSpec {
  final String label;
  final ModelType modelType;
  final String fileName;
  final String url;
  final String sizeLabel;

  const LocalModelSpec({
    required this.label,
    required this.modelType,
    required this.fileName,
    required this.url,
    required this.sizeLabel,
  });
}

/// Modelos locales soportados — ambos públicos en HuggingFace (litert-community),
/// sin token/cuenta necesaria.
class LocalModels {
  static const qwen = LocalModelSpec(
    label: 'Qwen 2.5 1.5B',
    modelType: ModelType.qwen,
    fileName: 'Qwen2.5-1.5B-Instruct_multi-prefill-seq_q8_ekv1280.task',
    url:
        'https://huggingface.co/litert-community/Qwen2.5-1.5B-Instruct/resolve/main/Qwen2.5-1.5B-Instruct_multi-prefill-seq_q8_ekv1280.task',
    sizeLabel: '~1.6GB',
  );

  static const deepSeekR1 = LocalModelSpec(
    label: 'DeepSeek R1 1.5B',
    modelType: ModelType.deepSeek,
    fileName: 'DeepSeek-R1-Distill-Qwen-1.5B_multi-prefill-seq_q8_ekv1280.task',
    url:
        'https://huggingface.co/litert-community/DeepSeek-R1-Distill-Qwen-1.5B/resolve/main/DeepSeek-R1-Distill-Qwen-1.5B_multi-prefill-seq_q8_ekv1280.task',
    sizeLabel: '~1.9GB',
  );

  static const all = [qwen, deepSeekR1];
}

/// On-device parsing vía flutter_gemma/MediaPipe, para cualquier
/// [LocalModelSpec] soportado — zero setup friction (modelos públicos, sin
/// key), funciona offline tras la descarga única.
class LocalParsingService implements ReceiptParsingService {
  final LocalModelSpec spec;

  const LocalParsingService(this.spec);

  Future<bool> isModelInstalled() => FlutterGemma.isModelInstalled(spec.fileName);

  /// Descarga el archivo si falta, Y (re)registra el modelo como activo —
  /// `getActiveModel()` necesita ese registro en memoria en cada proceso
  /// nuevo de la app, no persiste entre reinicios aunque el archivo
  /// descargado sí. Cuando el archivo ya está en disco esto completa casi
  /// instantáneo (sin re-descarga).
  Future<void> ensureModelInstalled({void Function(int percent)? onProgress}) async {
    await FlutterGemma.installModel(modelType: spec.modelType)
        .fromNetwork(spec.url)
        .withProgress((p) => onProgress?.call(p))
        .install();
  }

  /// Borra el modelo del disco (libera espacio) — el usuario puede volver a
  /// descargarlo cuando quiera, no es destructivo pa nada más.
  Future<void> uninstall() => FlutterGemma.uninstallModel(spec.fileName);

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
  /// se filtra antes de llamar al parser, ver CaptureScreen). También
  /// tolera un preámbulo de "thinking" (DeepSeek R1) antes del JSON, porque
  /// `extractJsonObject` busca desde la primera `{` sin importar qué haya
  /// antes.
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
