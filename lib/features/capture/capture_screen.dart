import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_cropper/image_cropper.dart';
import 'package:image_picker/image_picker.dart';

import '../../data/models/parsed_receipt.dart';
import '../../services/ocr_service.dart';
import '../../services/parsing_settings.dart';
import '../receipt_review/receipt_review_screen.dart';

enum _Stage { collecting, runningOcr, parsing, error }

/// Captura (Fase 2) + parseo (Fase 3): varias fotos por factura → OCR local
/// por página → parseo a JSON estructurado (Qwen on-device por defecto, o
/// Gemini si el usuario lo activó en Settings) → Receipt Review editable.
/// Si OCR no detecta texto o el parseo falla, cae a entrada manual (receipt
/// vacío en Review) en vez de bloquear al usuario.
class CaptureScreen extends StatefulWidget {
  const CaptureScreen({super.key});

  @override
  State<CaptureScreen> createState() => _CaptureScreenState();
}

class _CaptureScreenState extends State<CaptureScreen> {
  final _picker = ImagePicker();
  final _ocr = OcrService();
  final _pages = <String>[]; // rutas de imágenes ya recortadas, en orden

  _Stage _stage = _Stage.collecting;
  String? _errorMessage;

  @override
  void dispose() {
    _ocr.dispose();
    super.dispose();
  }

  Future<void> _addPage(ImageSource source) async {
    final picked = await _picker.pickImage(source: source, imageQuality: 90);
    if (picked == null) return;

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
    if (cropped == null) return;

    setState(() => _pages.add(cropped.path));
  }

  void _removePage(int index) {
    setState(() => _pages.removeAt(index));
  }

  Future<void> _processAllPages() async {
    setState(() {
      _stage = _Stage.runningOcr;
      _errorMessage = null;
    });

    String combinedText;
    try {
      final buffer = StringBuffer();
      for (var i = 0; i < _pages.length; i++) {
        final text = await _ocr.recognizeText(_pages[i]);
        if (_pages.length > 1) {
          buffer.writeln('--- Página ${i + 1} ---');
        }
        buffer.writeln(text);
      }
      combinedText = buffer.toString().trim();
    } catch (e) {
      setState(() {
        _errorMessage = 'No se pudo leer alguna imagen: $e';
        _stage = _Stage.error;
      });
      return;
    }

    if (combinedText.isEmpty) {
      // OCR no detectó nada legible — no gastar el parseo, ir directo a
      // entrada manual.
      _goToReview(ParsedReceipt.empty());
      return;
    }

    setState(() => _stage = _Stage.parsing);
    try {
      final parser = await ParsingSettings().buildActiveParser();
      final parsed = await parser.parseReceipt(combinedText);
      _goToReview(parsed);
    } catch (e) {
      if (!mounted) return;
      await showDialog<void>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('No se pudo leer la factura automáticamente'),
          content: const Text(
            'Vamos a abrir la lista de ítems vacía para que la completes a mano.',
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Entendido')),
          ],
        ),
      );
      _goToReview(ParsedReceipt.empty());
    }
  }

  void _goToReview(ParsedReceipt parsed) {
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => ReceiptReviewScreen(parsed: parsed)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Escanear factura')),
      body: switch (_stage) {
        _Stage.collecting => _buildCollecting(),
        _Stage.runningOcr => const Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(),
                SizedBox(height: 12),
                Text('Leyendo texto (OCR local)...'),
              ],
            ),
          ),
        _Stage.parsing => const Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(),
                SizedBox(height: 12),
                Text('Parseando con IA...'),
              ],
            ),
          ),
        _Stage.error => Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Text(_errorMessage ?? 'Error desconocido', style: const TextStyle(color: Colors.red)),
            ),
          ),
      },
    );
  }

  Widget _buildCollecting() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () => _addPage(ImageSource.camera),
                  icon: const Icon(Icons.camera_alt),
                  label: Text(_pages.isEmpty ? 'Cámara' : 'Agregar otra página'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _addPage(ImageSource.gallery),
                  icon: const Icon(Icons.photo_library),
                  label: const Text('Galería'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (_pages.isEmpty)
            const Expanded(
              child: Center(
                child: Text(
                  'Toma o elige foto(s) de la factura pa extraer el texto.\n'
                  'Si la factura es larga, agrega varias páginas antes de continuar.',
                  textAlign: TextAlign.center,
                ),
              ),
            )
          else
            Expanded(
              child: GridView.builder(
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 3,
                  crossAxisSpacing: 8,
                  mainAxisSpacing: 8,
                ),
                itemCount: _pages.length,
                itemBuilder: (context, index) {
                  return Stack(
                    fit: StackFit.expand,
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Image.file(File(_pages[index]), fit: BoxFit.cover),
                      ),
                      Positioned(
                        top: 2,
                        left: 2,
                        child: CircleAvatar(
                          radius: 11,
                          backgroundColor: Colors.black54,
                          child: Text('${index + 1}', style: const TextStyle(fontSize: 12, color: Colors.white)),
                        ),
                      ),
                      Positioned(
                        top: 2,
                        right: 2,
                        child: GestureDetector(
                          onTap: () => _removePage(index),
                          child: const CircleAvatar(
                            radius: 11,
                            backgroundColor: Colors.black54,
                            child: Icon(Icons.close, size: 14, color: Colors.white),
                          ),
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
          const SizedBox(height: 16),
          FilledButton(
            onPressed: _pages.isEmpty ? null : _processAllPages,
            child: Text(_pages.length > 1 ? 'Continuar (${_pages.length} páginas)' : 'Continuar'),
          ),
        ],
      ),
    );
  }
}
