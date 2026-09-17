import 'package:flutter/material.dart';

import '../../services/gemini_parsing_service.dart';
import '../../services/local_parsing_service.dart';
import '../../services/openai_compatible_parsing_service.dart';
import '../../services/parsing_settings.dart';
import '../../services/secure_key_store.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _settings = ParsingSettings();
  ParsingEngine? _engine;

  @override
  void initState() {
    super.initState();
    _settings.getEngine().then((e) => setState(() => _engine = e));
  }

  Future<void> _selectEngine(ParsingEngine engine) async {
    setState(() => _engine = engine);
    await _settings.setEngine(engine);
  }

  @override
  Widget build(BuildContext context) {
    if (_engine == null) {
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
          const SizedBox(height: 12),
          Text('Modelo local (en el celular)', style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: 4),
          RadioListTile<ParsingEngine>(
            contentPadding: EdgeInsets.zero,
            title: const Text('Qwen 2.5 1.5B'),
            value: ParsingEngine.localQwen,
            groupValue: _engine,
            onChanged: (v) => _selectEngine(v!),
          ),
          if (_engine == ParsingEngine.localQwen) const _LocalModelCard(spec: LocalModels.qwen),
          RadioListTile<ParsingEngine>(
            contentPadding: EdgeInsets.zero,
            title: const Text('DeepSeek R1 1.5B'),
            value: ParsingEngine.localDeepSeek,
            groupValue: _engine,
            onChanged: (v) => _selectEngine(v!),
          ),
          if (_engine == ParsingEngine.localDeepSeek) const _LocalModelCard(spec: LocalModels.deepSeekR1),
          const SizedBox(height: 16),
          Text('Modelo en la nube (requiere tu propia API key)', style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: 4),
          RadioListTile<ParsingEngine>(
            contentPadding: EdgeInsets.zero,
            title: const Text('Gemini'),
            value: ParsingEngine.gemini,
            groupValue: _engine,
            onChanged: (v) => _selectEngine(v!),
          ),
          if (_engine == ParsingEngine.gemini)
            _CloudProviderCard(
              helperText: 'Consíguela gratis en Google AI Studio.',
              getKey: () => SecureKeyStore().getGeminiKey(),
              setKey: (k) => SecureKeyStore().setGeminiKey(k),
              getModel: () => _settings.getGeminiModel(),
              setModel: (m) => _settings.setGeminiModel(m),
              listModels: (key) => GeminiParsingService.listModels(key),
              testKey: (key, model) => GeminiParsingService(key, model).parseReceipt('Café 2.50\nTotal 2.50'),
            ),
          RadioListTile<ParsingEngine>(
            contentPadding: EdgeInsets.zero,
            title: const Text('Groq'),
            value: ParsingEngine.groq,
            groupValue: _engine,
            onChanged: (v) => _selectEngine(v!),
          ),
          if (_engine == ParsingEngine.groq)
            _CloudProviderCard(
              helperText: 'Consíguela gratis en console.groq.com.',
              getKey: () => SecureKeyStore().getGroqKey(),
              setKey: (k) => SecureKeyStore().setGroqKey(k),
              getModel: () => _settings.getGroqModel(),
              setModel: (m) => _settings.setGroqModel(m),
              listModels: (key) => OpenAiCompatibleParsingService.listModels(groqBaseUrl, key),
              testKey: (key, model) => OpenAiCompatibleParsingService(
                baseUrl: groqBaseUrl,
                apiKey: key,
                model: model,
              ).parseReceipt('Café 2.50\nTotal 2.50'),
            ),
          RadioListTile<ParsingEngine>(
            contentPadding: EdgeInsets.zero,
            title: const Text('Otro (compatible con OpenAI)'),
            subtitle: const Text('OpenRouter, tu propio servidor, etc.', style: TextStyle(fontSize: 12)),
            value: ParsingEngine.customOpenAi,
            groupValue: _engine,
            onChanged: (v) => _selectEngine(v!),
          ),
          if (_engine == ParsingEngine.customOpenAi)
            _CloudProviderCard(
              helperText: 'La key de tu proveedor.',
              showEndpointField: true,
              getEndpoint: () => _settings.getCustomEndpoint(),
              setEndpoint: (e) => _settings.setCustomEndpoint(e),
              getKey: () => SecureKeyStore().getCustomKey(),
              setKey: (k) => SecureKeyStore().setCustomKey(k),
              getModel: () => _settings.getCustomModel(),
              setModel: (m) => _settings.setCustomModel(m),
              listModels: (key) async {
                final endpoint = await _settings.getCustomEndpoint();
                if (endpoint.isEmpty) throw Exception('Primero completa el endpoint.');
                return OpenAiCompatibleParsingService.listModels(endpoint, key);
              },
              testKey: (key, model) async {
                final endpoint = await _settings.getCustomEndpoint();
                await OpenAiCompatibleParsingService(baseUrl: endpoint, apiKey: key, model: model)
                    .parseReceipt('Café 2.50\nTotal 2.50');
              },
            ),
        ],
      ),
    );
  }
}

/// Card de estado/descarga/borrado de un modelo local — un solo widget
/// sirve para cualquier [LocalModelSpec].
class _LocalModelCard extends StatefulWidget {
  final LocalModelSpec spec;
  const _LocalModelCard({required this.spec});

  @override
  State<_LocalModelCard> createState() => _LocalModelCardState();
}

class _LocalModelCardState extends State<_LocalModelCard> {
  late final _service = LocalParsingService(widget.spec);
  bool _loading = true;
  bool _installed = false;
  int? _downloadProgress;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  Future<void> _refresh() async {
    final installed = await _service.isModelInstalled();
    if (mounted) {
      setState(() {
        _installed = installed;
        _loading = false;
      });
    }
  }

  Future<void> _download() async {
    setState(() => _downloadProgress = 0);
    try {
      await _service.ensureModelInstalled(onProgress: (p) => setState(() => _downloadProgress = p));
      setState(() {
        _installed = true;
        _downloadProgress = null;
      });
    } catch (e) {
      setState(() => _downloadProgress = null);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error descargando modelo: $e')));
      }
    }
  }

  Future<void> _confirmDelete() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Eliminar modelo descargado'),
        content: Text('Se borra ${widget.spec.label} del celular (libera ${widget.spec.sizeLabel}). Podés volver a descargarlo cuando quieras.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancelar')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Eliminar')),
        ],
      ),
    );
    if (confirmed != true) return;
    await _service.uninstall();
    if (mounted) setState(() => _installed = false);
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Gratis, funciona sin internet, sin cuentas. Descarga única de ${widget.spec.sizeLabel}.',
              style: const TextStyle(fontSize: 12, color: Colors.grey),
            ),
            const SizedBox(height: 12),
            if (_loading)
              const Center(child: CircularProgressIndicator())
            else if (_downloadProgress != null)
              Column(
                children: [
                  LinearProgressIndicator(value: _downloadProgress! / 100),
                  const SizedBox(height: 4),
                  Text('Descargando... $_downloadProgress%'),
                ],
              )
            else if (!_installed)
              FilledButton(onPressed: _download, child: Text('Descargar modelo (${widget.spec.sizeLabel})'))
            else
              Row(
                children: [
                  const Icon(Icons.check_circle, color: Colors.green, size: 18),
                  const SizedBox(width: 8),
                  const Expanded(child: Text('Listo para usar.', style: TextStyle(color: Colors.green))),
                  IconButton(
                    icon: const Icon(Icons.delete_outline),
                    tooltip: 'Eliminar modelo descargado',
                    onPressed: _confirmDelete,
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}

/// Card de configuración de un proveedor cloud: key + selector de modelo
/// (dropdown consultado en vivo, con fallback a texto libre si falla) +
/// opcionalmente un campo de endpoint (solo "Otro"). Un solo widget sirve
/// para Gemini, Groq y "Otro" — cada instancia recibe los callbacks que le
/// corresponden a su proveedor.
class _CloudProviderCard extends StatefulWidget {
  final String helperText;
  final bool showEndpointField;
  final Future<String?> Function()? getEndpoint;
  final Future<void> Function(String)? setEndpoint;
  final Future<String?> Function() getKey;
  final Future<void> Function(String) setKey;
  final Future<String> Function() getModel;
  final Future<void> Function(String) setModel;
  final Future<List<String>> Function(String apiKey) listModels;
  final Future<void> Function(String apiKey, String model) testKey;

  const _CloudProviderCard({
    required this.helperText,
    this.showEndpointField = false,
    this.getEndpoint,
    this.setEndpoint,
    required this.getKey,
    required this.setKey,
    required this.getModel,
    required this.setModel,
    required this.listModels,
    required this.testKey,
  });

  @override
  State<_CloudProviderCard> createState() => _CloudProviderCardState();
}

class _CloudProviderCardState extends State<_CloudProviderCard> {
  final _keyController = TextEditingController();
  final _endpointController = TextEditingController();
  final _manualModelController = TextEditingController();

  bool _loading = true;
  List<String>? _availableModels;
  String? _selectedModel;
  bool _loadingModels = false;
  String? _modelsError;
  String? _testResult;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _keyController.dispose();
    _endpointController.dispose();
    _manualModelController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final key = await widget.getKey();
    final model = await widget.getModel();
    if (widget.showEndpointField) {
      _endpointController.text = await widget.getEndpoint!() ?? '';
    }
    setState(() {
      _keyController.text = key ?? '';
      _selectedModel = model.isNotEmpty ? model : null;
      _manualModelController.text = model;
      _loading = false;
    });
  }

  Future<void> _saveKeyAndEndpoint() async {
    final messenger = ScaffoldMessenger.of(context);
    await widget.setKey(_keyController.text.trim());
    if (widget.showEndpointField) {
      await widget.setEndpoint!(_endpointController.text.trim());
    }
    if (mounted) messenger.showSnackBar(const SnackBar(content: Text('Guardado.')));
  }

  Future<void> _loadModels() async {
    setState(() {
      _loadingModels = true;
      _modelsError = null;
    });
    try {
      final key = _keyController.text.trim();
      final models = await widget.listModels(key);
      setState(() {
        _availableModels = models;
        if (!models.contains(_selectedModel)) {
          _selectedModel = models.isNotEmpty ? models.first : null;
        }
        _loadingModels = false;
      });
      if (_selectedModel != null) await widget.setModel(_selectedModel!);
    } catch (e) {
      setState(() {
        _modelsError = 'No se pudo cargar la lista de modelos: $e';
        _loadingModels = false;
      });
    }
  }

  Future<void> _testKey() async {
    setState(() => _testResult = 'Probando...');
    try {
      final model = _availableModels != null ? (_selectedModel ?? '') : _manualModelController.text.trim();
      await widget.testKey(_keyController.text.trim(), model);
      setState(() => _testResult = '✓ Key y modelo válidos, responde bien.');
    } catch (e) {
      setState(() => _testResult = '✗ Error: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Card(child: Padding(padding: EdgeInsets.all(16), child: LinearProgressIndicator()));
    }
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (widget.showEndpointField) ...[
              TextField(
                controller: _endpointController,
                decoration: const InputDecoration(
                  labelText: 'Endpoint',
                  border: OutlineInputBorder(),
                  helperText: 'Ej: https://api.openai.com/v1/chat/completions',
                  isDense: true,
                ),
                // Se guarda mientras se escribe (no solo al tocar "Guardar")
                // -- si no, "Cargar modelos"/"Probar key" leerían el endpoint
                // viejo o vacío hasta que el usuario toque Guardar primero.
                onChanged: (e) => widget.setEndpoint!(e.trim()),
              ),
              const SizedBox(height: 8),
            ],
            TextField(
              controller: _keyController,
              decoration: InputDecoration(
                labelText: 'API key',
                border: const OutlineInputBorder(),
                helperText: widget.helperText,
                isDense: true,
              ),
              obscureText: true,
            ),
            const SizedBox(height: 8),
            FilledButton(onPressed: _saveKeyAndEndpoint, child: const Text('Guardar')),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _availableModels != null
                      ? DropdownButtonFormField<String>(
                          value: _selectedModel,
                          isExpanded: true,
                          decoration: const InputDecoration(labelText: 'Modelo', isDense: true),
                          items: _availableModels!
                              .map((m) => DropdownMenuItem(value: m, child: Text(m, overflow: TextOverflow.ellipsis)))
                              .toList(),
                          onChanged: (m) {
                            setState(() => _selectedModel = m);
                            if (m != null) widget.setModel(m);
                          },
                        )
                      : TextField(
                          controller: _manualModelController,
                          decoration: const InputDecoration(labelText: 'Modelo (ID exacto)', isDense: true),
                          onChanged: (m) => widget.setModel(m),
                        ),
                ),
                const SizedBox(width: 8),
                _loadingModels
                    ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2))
                    : TextButton(onPressed: _loadModels, child: const Text('Cargar modelos')),
              ],
            ),
            if (_modelsError != null)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(_modelsError!, style: const TextStyle(color: Colors.red, fontSize: 12)),
              ),
            const SizedBox(height: 8),
            OutlinedButton(onPressed: _testKey, child: const Text('Probar key')),
            if (_testResult != null)
              Padding(padding: const EdgeInsets.only(top: 8), child: Text(_testResult!)),
            const SizedBox(height: 8),
            const Text(
              'Tu key se guarda solo en este dispositivo y se manda directo a la API del proveedor '
              '— nunca a un servidor propio.',
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ],
        ),
      ),
    );
  }
}
