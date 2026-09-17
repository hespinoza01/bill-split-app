import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_cropper/image_cropper.dart';
import 'package:image_picker/image_picker.dart';

import '../../services/ocr_service.dart';

enum _Stage { collecting, runningOcr, done, error }

/// Fase 2: captura + OCR. Soporta varias fotos por factura (facturas largas
/// que no caben en una sola imagen) — cada foto se recorta al agregarla, y
/// el OCR corre sobre todas al tocar "Continuar", concatenando el texto.
/// Pantalla temporal: en Fase 3 el resultado va hacia Gemini + Review, no
/// se muestra el texto crudo como destino final.
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
  String? _combinedText;
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

    try {
      final buffer = StringBuffer();
      for (var i = 0; i < _pages.length; i++) {
        final text = await _ocr.recognizeText(_pages[i]);
        if (_pages.length > 1) {
          buffer.writeln('--- Página ${i + 1} ---');
        }
        buffer.writeln(text);
      }
      setState(() {
        _combinedText = buffer.toString().trim();
        _stage = _Stage.done;
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'No se pudo leer alguna imagen: $e';
        _stage = _Stage.error;
      });
    }
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
        _Stage.error => Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Text(_errorMessage ?? 'Error desconocido', style: const TextStyle(color: Colors.red)),
            ),
          ),
        _Stage.done => _buildResult(),
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

  Widget _buildResult() {
    final text = _combinedText ?? '';
    if (text.isEmpty) {
      return const Center(
        child: Text('No se detectó texto legible. Prueba con otra foto o mejor luz.'),
      );
    }
    return Padding(
      padding: const EdgeInsets.all(16),
      child: SingleChildScrollView(
        child: SelectableText(text, style: const TextStyle(fontFamily: 'monospace')),
      ),
    );
  }
}
