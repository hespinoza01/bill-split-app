import 'package:flutter/material.dart';

import '../../services/gemini_parsing_service.dart';
import '../../services/local_parsing_service.dart';
import '../../services/parsing_settings.dart';
import '../../services/secure_key_store.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _keyStore = SecureKeyStore();
  final _settings = ParsingSettings();
  final _keyController = TextEditingController();

  bool _useGemini = false;
  bool _loading = true;
  bool _modelInstalled = false;
  int? _downloadProgress;
  String? _testResult;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _keyController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final useGemini = await _settings.getUseGemini();
    final key = await _keyStore.getGeminiKey();
    final installed = await LocalParsingService.isModelInstalled();
    setState(() {
      _useGemini = useGemini;
      _keyController.text = key ?? '';
      _modelInstalled = installed;
      _loading = false;
    });
  }

  Future<void> _downloadModel() async {
    setState(() => _downloadProgress = 0);
    try {
      await LocalParsingService.ensureModelInstalled(
        onProgress: (p) => setState(() => _downloadProgress = p),
      );
      setState(() {
        _modelInstalled = true;
        _downloadProgress = null;
      });
    } catch (e) {
      setState(() => _downloadProgress = null);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error descargando modelo: $e')),
        );
      }
    }
  }

  Future<void> _testGeminiKey() async {
    setState(() => _testResult = 'Probando...');
    try {
      final service = GeminiParsingService(_keyController.text.trim());
      await service.parseReceipt('Café 2.50\nTotal 2.50');
      setState(() => _testResult = '✓ Key válida, Gemini responde bien.');
    } catch (e) {
      setState(() => _testResult = '✗ Error: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return Scaffold(
        appBar: AppBar(title: const Text('Configuración')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Configuración')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text('Motor de parseo de facturas', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(_modelInstalled ? Icons.check_circle : Icons.download, color: _modelInstalled ? Colors.green : null),
                      const SizedBox(width: 8),
                      const Expanded(child: Text('Modelo local (Qwen 2.5, en el celular)')),
                    ],
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Por defecto. Gratis, funciona sin internet, sin cuentas. '
                    'Descarga única de ~1.6GB.',
                    style: TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                  const SizedBox(height: 12),
                  if (_downloadProgress != null)
                    Column(
                      children: [
                        LinearProgressIndicator(value: _downloadProgress! / 100),
                        const SizedBox(height: 4),
                        Text('Descargando... $_downloadProgress%'),
                      ],
                    )
                  else if (!_modelInstalled)
                    FilledButton(onPressed: _downloadModel, child: const Text('Descargar modelo (~1.6GB)'))
                  else
                    const Text('Listo para usar.', style: TextStyle(color: Colors.green)),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Usar Gemini (en la nube) en vez del modelo local'),
                    subtitle: const Text('Más rápido y preciso, pero requiere tu propia API key y conexión.'),
                    value: _useGemini,
                    onChanged: (v) async {
                      setState(() => _useGemini = v);
                      await _settings.setUseGemini(v);
                    },
                  ),
                  if (_useGemini) ...[
                    const SizedBox(height: 8),
                    TextField(
                      controller: _keyController,
                      decoration: const InputDecoration(
                        labelText: 'Gemini API key',
                        border: OutlineInputBorder(),
                        helperText: 'Consíguela gratis en Google AI Studio.',
                      ),
                      obscureText: true,
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        FilledButton(
                          onPressed: () async {
                            final messenger = ScaffoldMessenger.of(context);
                            await _keyStore.setGeminiKey(_keyController.text.trim());
                            if (mounted) {
                              messenger.showSnackBar(
                                const SnackBar(content: Text('Key guardada.')),
                              );
                            }
                          },
                          child: const Text('Guardar'),
                        ),
                        const SizedBox(width: 8),
                        OutlinedButton(onPressed: _testGeminiKey, child: const Text('Probar key')),
                      ],
                    ),
                    if (_testResult != null) Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Text(_testResult!),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Tu key se guarda solo en este dispositivo y se manda directo a la '
                      'API de Google — nunca a un servidor propio.',
                      style: TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
