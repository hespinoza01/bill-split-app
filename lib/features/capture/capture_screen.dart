import 'package:flutter/material.dart';
import 'package:image_cropper/image_cropper.dart';
import 'package:image_picker/image_picker.dart';

import '../../services/ocr_service.dart';

enum _Stage { idle, cropping, runningOcr, done, error }

/// Fase 2: captura + OCR. Muestra el texto crudo extraído en pantalla —
/// pantalla temporal, en Fase 3 esto se reemplaza por el flujo real hacia
/// Gemini y la Receipt Review screen.
class CaptureScreen extends StatefulWidget {
  const CaptureScreen({super.key});

  @override
  State<CaptureScreen> createState() => _CaptureScreenState();
}

class _CaptureScreenState extends State<CaptureScreen> {
  final _picker = ImagePicker();
  final _ocr = OcrService();

  _Stage _stage = _Stage.idle;
  String? _ocrText;
  String? _errorMessage;

  @override
  void dispose() {
    _ocr.dispose();
    super.dispose();
  }

  Future<void> _pickAndProcess(ImageSource source) async {
    setState(() {
      _stage = _Stage.idle;
      _ocrText = null;
      _errorMessage = null;
    });

    final picked = await _picker.pickImage(source: source, imageQuality: 90);
    if (picked == null) return;

    setState(() => _stage = _Stage.cropping);
    final cropped = await ImageCropper().cropImage(
      sourcePath: picked.path,
      uiSettings: [
        AndroidUiSettings(
          toolbarTitle: 'Recortar factura',
          lockAspectRatio: false,
        ),
        IOSUiSettings(title: 'Recortar factura'),
      ],
    );
    if (cropped == null) {
      setState(() => _stage = _Stage.idle);
      return;
    }

    setState(() => _stage = _Stage.runningOcr);
    try {
      final text = await _ocr.recognizeText(cropped.path);
      setState(() {
        _ocrText = text;
        _stage = _Stage.done;
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'No se pudo leer la imagen: $e';
        _stage = _Stage.error;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Escanear factura')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _stage == _Stage.cropping || _stage == _Stage.runningOcr
                        ? null
                        : () => _pickAndProcess(ImageSource.camera),
                    icon: const Icon(Icons.camera_alt),
                    label: const Text('Cámara'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _stage == _Stage.cropping || _stage == _Stage.runningOcr
                        ? null
                        : () => _pickAndProcess(ImageSource.gallery),
                    icon: const Icon(Icons.photo_library),
                    label: const Text('Galería'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            Expanded(child: _buildBody()),
          ],
        ),
      ),
    );
  }

  Widget _buildBody() {
    switch (_stage) {
      case _Stage.idle:
        return const Center(
          child: Text('Toma o elige una foto de la factura pa extraer el texto.'),
        );
      case _Stage.cropping:
        return const Center(child: Text('Recortando...'));
      case _Stage.runningOcr:
        return const Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 12),
              Text('Leyendo texto (OCR local)...'),
            ],
          ),
        );
      case _Stage.error:
        return Center(
          child: Text(_errorMessage ?? 'Error desconocido', style: const TextStyle(color: Colors.red)),
        );
      case _Stage.done:
        final text = _ocrText ?? '';
        if (text.isEmpty) {
          return const Center(
            child: Text('No se detectó texto legible. Prueba con otra foto o mejor luz.'),
          );
        }
        return SingleChildScrollView(
          child: SelectableText(text, style: const TextStyle(fontFamily: 'monospace')),
        );
    }
  }
}
