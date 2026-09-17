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

  /// Downloads the model if not already installed. [onProgress] receives
  /// 0-100. Safe to call even if already installed (installModel checks).
  static Future<void> ensureModelInstalled({void Function(int percent)? onProgress}) async {
    if (await isModelInstalled()) return;
    await FlutterGemma.installModel(modelType: ModelType.qwen)
        .fromNetwork(modelUrl)
        .withProgress((p) => onProgress?.call(p))
        .install();
  }

  @override
  Future<ParsedReceipt> parseReceipt(String ocrText) async {
    final model = await FlutterGemma.getActiveModel(
      maxTokens: 2048,
      preferredBackend: PreferredBackend.cpu,
    );
    final session = await model.createSession(temperature: 0.1, topK: 1);
    try {
      await session.addQueryChunk(
        Message.text(text: buildReceiptParsingPrompt(ocrText), isUser: true),
      );
      final response = await session.getResponse();
      final json = extractJsonObject(response);
      if (json == null) {
        throw const FormatException('El modelo local no devolvió JSON válido');
      }
      return ParsedReceipt.fromJson(json);
    } finally {
      await session.close();
    }
  }
}
