import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../models/api_config.dart';
import '../../../../providers/settings_provider.dart';
import '../../../../services/api_service.dart';
import '../../data/models/live2d_parameter_preset.dart';
import '../../data/models/model3_data.dart';
import '../../data/models/parameter_alias_map.dart';
import '../../data/repositories/live2d_settings_repository.dart';
import '../../data/services/live2d_native_bridge.dart';
import '../../data/services/model3_json_parser.dart';
import '../../../live2d_llm/services/live2d_directive_service.dart';

class Live2DFunctionTestScreen extends StatefulWidget {
  const Live2DFunctionTestScreen({super.key, required this.modelPath});

  final String? modelPath;

  @override
  State<Live2DFunctionTestScreen> createState() => _Live2DFunctionTestScreenState();
}

class _Live2DFunctionTestScreenState extends State<Live2DFunctionTestScreen>
    with TickerProviderStateMixin {
  final Live2DNativeBridge _bridge = Live2DNativeBridge();
  final Live2DDirectiveService _directiveService = Live2DDirectiveService.instance;
  final Live2DSettingsRepository _repository = Live2DSettingsRepository();
  final Model3JsonParser _parser = Model3JsonParser();
  final ApiService _apiService = ApiService();

  late final TabController _tabController;
  final TextEditingController _parameterSearchController = TextEditingController();
  final TextEditingController _commandInputController = TextEditingController();
  final TextEditingController _motionPromptController = TextEditingController();

  Model3Data _modelData = Model3Data.empty;
  final Map<String, double> _currentValues = <String, double>{};
  ParameterAliasMap? _aliasMap;
  final List<_CommandLogEntry> _commandLogs = <_CommandLogEntry>[];
  final MotionGenChatSession _motionSession = MotionGenChatSession();

  String _parameterSearch = '';
  bool _loading = true;
  bool _sendingMotionPrompt = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _parameterSearchController.addListener(() {
      setState(() {
        _parameterSearch = _parameterSearchController.text.trim().toLowerCase();
      });
    });
    _loadAll();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _parameterSearchController.dispose();
    _commandInputController.dispose();
    _motionPromptController.dispose();
    super.dispose();
  }

  Future<void> _loadAll() async {
    final modelPath = widget.modelPath;
    if (modelPath == null || modelPath.isEmpty) {
      if (!mounted) return;
      setState(() => _loading = false);
      return;
    }

    final data = await _parser.parseFile(modelPath);
    final aliases = await _ensureAliases(modelPath, data.parameters);
    final values = <String, double>{};
    for (final p in data.parameters) {
      values[p.id] = (await _bridge.getParameter(p.id)) ?? p.defaultValue;
    }

    if (!mounted) return;
    setState(() {
      _modelData = data;
      _aliasMap = aliases;
      _currentValues
        ..clear()
        ..addAll(values);
      _loading = false;
    });
  }

  Future<ParameterAliasMap> _ensureAliases(
    String modelPath,
    List<Model3Parameter> parameters,
  ) async {
    final existing = await _repository.loadParameterAliases(modelPath);
    if (existing != null && existing.aliasToReal.isNotEmpty) return existing;
    final ids = parameters.map((e) => e.id).toList(growable: false)..sort();
    final map = <String, String>{};
    for (var i = 0; i < ids.length; i++) {
      map['parameter${i + 1}'] = ids[i];
    }
    final aliases = ParameterAliasMap.fromAliasToReal(map);
    await _repository.saveParameterAliases(modelPath, aliases);
    return aliases;
  }

  Future<void> _setParameter(Model3Parameter parameter, double value) async {
    await _bridge.setParameter(parameter.id, value, durationMs: 0);
    if (!mounted) return;
    setState(() => _currentValues[parameter.id] = value);
  }

  Future<void> _editAliases() async {
    final modelPath = widget.modelPath;
    final current = _aliasMap;
    if (modelPath == null || modelPath.isEmpty || current == null) return;

    final rows = current.aliasToReal.entries.toList(growable: false)
      ..sort((a, b) => a.key.compareTo(b.key));
    final controllers = <String, TextEditingController>{
      for (final row in rows) row.value: TextEditingController(text: row.key),
    };

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Edit parameter aliases'),
        content: SizedBox(
          width: 520,
          child: ListView(
            shrinkWrap: true,
            children: rows
                .map(
                  (row) => Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: controllers[row.value],
                            decoration: const InputDecoration(
                              border: OutlineInputBorder(),
                              labelText: 'Alias',
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(child: Text(row.value)),
                      ],
                    ),
                  ),
                )
                .toList(growable: false),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Save')),
        ],
      ),
    );

    if (confirmed != true) {
      for (final c in controllers.values) {
        c.dispose();
      }
      return;
    }

    final next = <String, String>{};
    final used = <String>{};
    for (final row in rows) {
      final rawAlias = controllers[row.value]?.text.trim();
      var alias = (rawAlias == null || rawAlias.isEmpty) ? row.key : rawAlias;
      if (used.contains(alias)) {
        var index = 2;
        while (used.contains('$alias$index')) {
          index++;
        }
        alias = '$alias$index';
      }
      used.add(alias);
      next[alias] = row.value;
    }

    for (final c in controllers.values) {
      c.dispose();
    }

    final map = ParameterAliasMap.fromAliasToReal(next);
    await _repository.saveParameterAliases(modelPath, map);
    if (!mounted) return;
    setState(() => _aliasMap = map);
  }

  Future<void> _resetAll() async {
    for (final p in _modelData.parameters) {
      await _bridge.setParameter(p.id, p.defaultValue, durationMs: 200);
    }
    if (!mounted) return;
    setState(() {
      for (final p in _modelData.parameters) {
        _currentValues[p.id] = p.defaultValue;
      }
    });
  }

  Future<void> _runCommand() async {
    final input = _commandInputController.text.trim();
    if (input.isEmpty) return;
    _commandInputController.clear();
    final result = await _directiveService.processAssistantOutput(
      input,
      parsingEnabled: true,
      exposeRawDirectives: true,
    );
    await _loadCurrentValues();
    if (!mounted) return;
    setState(() {
      _commandLogs.insert(
        0,
        _CommandLogEntry(
          input: input,
          parsed: result.cleanedText,
          errors: result.errors,
        ),
      );
    });
  }

  Future<void> _loadCurrentValues() async {
    for (final p in _modelData.parameters) {
      _currentValues[p.id] = (await _bridge.getParameter(p.id)) ?? _currentValues[p.id] ?? p.defaultValue;
    }
    if (mounted) setState(() {});
  }

  Future<void> _sendMotionPrompt(BuildContext context) async {
    final settingsProvider = context.read<SettingsProvider>();
    final text = _motionPromptController.text.trim();
    if (text.isEmpty || _sendingMotionPrompt) return;
    final config = _resolveSelectedConfig(settingsProvider);
    if (config == null) return;

    _motionPromptController.clear();
    setState(() {
      _sendingMotionPrompt = true;
      _motionSession.messages.add(MotionGenMessage(role: 'user', content: text));
    });

    try {
      final response = await _requestMotionAssistant(config, text);
      if (!mounted) return;
      setState(() {
        _motionSession.messages.addAll(response);
      });
    } finally {
      if (mounted) {
        setState(() => _sendingMotionPrompt = false);
      }
    }
  }

  ApiConfig? _resolveSelectedConfig(SettingsProvider provider) {
    _motionSession.selectedApiPresetId ??= provider.activeApiConfigId;
    final id = _motionSession.selectedApiPresetId;
    if (id == null) return provider.activeApiConfig;
    for (final c in provider.apiConfigs) {
      if (c.id == id) return c;
    }
    return provider.activeApiConfig;
  }

  Future<List<MotionGenMessage>> _requestMotionAssistant(ApiConfig config, String prompt) async {
    final systemPrompt = _buildMotionSystemPrompt();
    final payload = <Map<String, dynamic>>[
      {'role': 'system', 'content': systemPrompt},
      ..._motionSession.messages
          .where((m) => m.role == 'user' || m.role == 'assistant')
          .map((m) => {'role': m.role, 'content': m.content}),
      {'role': 'user', 'content': prompt},
    ];

    final settings = context.read<SettingsProvider>().settings;
    final first = await _apiService.sendMessageWithConfig(
      apiConfig: config,
      messages: payload,
      settings: settings,
    );

    final messages = <MotionGenMessage>[];
    final toolCall = _extractToolCall(first);
    if (toolCall == null) {
      messages.add(MotionGenMessage(role: 'assistant', content: first));
      return messages;
    }

    final toolResult = await _executeToolCall(toolCall);
    messages.add(
      MotionGenMessage(
        role: 'assistant',
        content: first,
        toolName: toolCall.name,
        toolArguments: toolCall.arguments,
        toolResult: toolResult,
      ),
    );

    final followUp = <Map<String, dynamic>>[
      ...payload,
      {'role': 'assistant', 'content': first},
      {'role': 'user', 'content': 'Tool result: $toolResult\nNow provide the final answer.'},
    ];
    final second = await _apiService.sendMessageWithConfig(
      apiConfig: config,
      messages: followUp,
      settings: settings,
    );
    messages.add(MotionGenMessage(role: 'assistant', content: second));
    return messages;
  }

  String _buildMotionSystemPrompt() {
    final parameterLines = _modelData.parameters
        .map((p) => '- ${p.id}: ${p.min}..${p.max} default=${p.defaultValue}')
        .join('\n');
    final aliasLines = _aliasMap?.aliasToReal.entries
            .map((e) => '- ${e.key}: ${e.value}')
            .join('\n') ??
        '';
    return '''You are a Live2D motion preset designer.\n
Available tools:\n1) read_model_info\n2) read_param_values\n3) set_parameter\n4) create_preset\n5) list_presets\n6) delete_preset\n7) play_motion\n8) test_sequence\n
If you need a tool, respond ONLY as JSON:\n{"tool":"tool_name","arguments":{...}}\n
Parameters:\n$parameterLines\n
Aliases:\n$aliasLines''';
  }

  _ToolCall? _extractToolCall(String raw) {
    final candidate = _extractFirstJsonObject(raw) ?? raw.trim();
    try {
      final decoded = jsonDecode(candidate);
      if (decoded is! Map<String, dynamic>) return null;
      if (decoded['tool'] is String) {
        final args = decoded['arguments'];
        return _ToolCall(decoded['tool'] as String, args is Map ? Map<String, dynamic>.from(args) : <String, dynamic>{});
      }
      final nested = decoded['tool_call'];
      if (nested is Map && nested['name'] is String) {
        final args = nested['arguments'];
        return _ToolCall(
          nested['name'] as String,
          args is Map ? Map<String, dynamic>.from(args) : <String, dynamic>{},
        );
      }
    } catch (_) {
      return null;
    }
    return null;
  }

  String? _extractFirstJsonObject(String raw) {
    final fenced = RegExp(r'```json\s*([\s\S]*?)\s*```', caseSensitive: false).firstMatch(raw);
    if (fenced != null) return fenced.group(1)?.trim();
    final firstBrace = raw.indexOf('{');
    final lastBrace = raw.lastIndexOf('}');
    if (firstBrace != -1 && lastBrace > firstBrace) {
      return raw.substring(firstBrace, lastBrace + 1);
    }
    return null;
  }

  Future<String> _executeToolCall(_ToolCall call) async {
    switch (call.name) {
      case 'read_model_info':
        return jsonEncode(await _bridge.getModelInfo());
      case 'read_param_values':
        final values = <String, double>{};
        for (final p in _modelData.parameters) {
          values[p.id] = (await _bridge.getParameter(p.id)) ?? p.defaultValue;
        }
        return jsonEncode(values);
      case 'set_parameter':
        final id = call.arguments['id']?.toString() ?? '';
        final value = (call.arguments['value'] as num?)?.toDouble() ?? 0.0;
        final dur = (call.arguments['durationMs'] as num?)?.toInt() ?? 200;
        await _bridge.setParameter(id, value, durationMs: dur);
        return 'ok';
      case 'create_preset':
        return _toolCreatePreset(call.arguments);
      case 'list_presets':
        if (widget.modelPath == null) return '[]';
        final presets = await _repository.loadParameterPresets(widget.modelPath!);
        return jsonEncode(presets.map((e) => e.toJson()).toList(growable: false));
      case 'delete_preset':
        if (widget.modelPath == null) return 'missing_model';
        final id = call.arguments['id']?.toString() ?? '';
        final presets = await _repository.loadParameterPresets(widget.modelPath!);
        final next = presets.where((p) => p.id != id).toList(growable: false);
        await _repository.saveParameterPresets(widget.modelPath!, next);
        return 'ok';
      case 'play_motion':
        final group = call.arguments['group']?.toString() ?? '';
        final index = (call.arguments['index'] as num?)?.toInt() ?? 0;
        await _bridge.playMotion(group, index);
        return 'ok';
      case 'test_sequence':
        final xml = call.arguments['commands']?.toString() ?? '';
        final result = await _directiveService.processAssistantOutput(
          xml,
          parsingEnabled: true,
          exposeRawDirectives: true,
        );
        return jsonEncode({'parsed': result.cleanedText, 'errors': result.errors});
      default:
        return 'unsupported_tool:${call.name}';
    }
  }

  Future<String> _toolCreatePreset(Map<String, dynamic> args) async {
    final modelPath = widget.modelPath;
    if (modelPath == null || modelPath.isEmpty) return 'missing_model';
    final name = args['name']?.toString() ?? 'preset';
    final rawOverrides = args['overrides'];
    final overrides = <String, double>{};
    if (rawOverrides is Map) {
      for (final entry in rawOverrides.entries) {
        final value = (entry.value as num?)?.toDouble();
        if (value != null) overrides[entry.key.toString()] = value;
      }
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Save Motion Preset?'),
        content: Text(
          'The LLM wants to save preset: "$name" with ${overrides.length} parameter overrides.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Save')),
        ],
      ),
    );
    if (confirmed != true) return 'cancelled';

    final presets = await _repository.loadParameterPresets(modelPath);
    final preset = Live2DParameterPreset(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      name: name,
      overrides: overrides,
    );
    await _repository.saveParameterPresets(modelPath, [...presets, preset]);
    return 'ok';
  }

  @override
  Widget build(BuildContext context) {
    final filteredParams = _modelData.parameters.where((p) {
      if (_parameterSearch.isEmpty) return true;
      return p.id.toLowerCase().contains(_parameterSearch);
    }).toList(growable: false);
    final settingsProvider = context.watch<SettingsProvider>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Live2D Function Test'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Parameter Adjustment'),
            Tab(text: 'Command Input'),
            Tab(text: 'Motion Generation'),
          ],
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : TabBarView(
              controller: _tabController,
              children: [
                ListView(
                  padding: const EdgeInsets.all(12),
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _parameterSearchController,
                            decoration: const InputDecoration(
                              border: OutlineInputBorder(),
                              hintText: 'Filter by parameter ID',
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        ElevatedButton.icon(
                          icon: const Icon(Icons.refresh),
                          label: const Text('Reset All'),
                          onPressed: _resetAll,
                        ),
                        const SizedBox(width: 8),
                        OutlinedButton.icon(
                          icon: const Icon(Icons.edit_note),
                          label: const Text('Aliases'),
                          onPressed: _editAliases,
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    ...filteredParams.map((p) {
                      final value = _currentValues[p.id] ?? p.defaultValue;
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('${p.id}  (${value.toStringAsFixed(2)})'),
                          Slider(
                            min: p.min,
                            max: p.max,
                            value: value.clamp(p.min, p.max),
                            onChanged: (v) => _setParameter(p, v),
                          ),
                        ],
                      );
                    }),
                  ],
                ),
                Column(
                  children: [
                    Expanded(
                      child: ListView.builder(
                        reverse: true,
                        itemCount: _commandLogs.length,
                        itemBuilder: (_, i) {
                          final log = _commandLogs[i];
                          return ListTile(
                            title: Text(log.success ? '✅ ${log.input}' : '❌ ${log.input}'),
                            subtitle: Text('Parsed: ${log.parsed}\nErrors: ${log.errors.join(' | ')}'),
                          );
                        },
                      ),
                    ),
                    ExpansionTile(
                      title: const Text('Command examples'),
                      children: const [
                        Padding(
                          padding: EdgeInsets.all(12),
                          child: Text('<live2d>\n  <param id="ParamAngleX" value="30" dur="500"/>\n</live2d>\n[wait:500]\n[preset:MyCustomWave]'),
                        ),
                      ],
                    ),
                    Padding(
                      padding: const EdgeInsets.all(8),
                      child: Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: _commandInputController,
                              decoration: const InputDecoration(
                                border: OutlineInputBorder(),
                                hintText: 'Enter XML/inline directives',
                              ),
                              minLines: 1,
                              maxLines: 4,
                            ),
                          ),
                          IconButton(onPressed: _runCommand, icon: const Icon(Icons.send)),
                          IconButton(
                            onPressed: () => setState(_commandLogs.clear),
                            icon: const Icon(Icons.delete_outline),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(8),
                      child: DropdownButtonFormField<String>(
                        initialValue:
                            _motionSession.selectedApiPresetId ?? settingsProvider.activeApiConfigId,
                        decoration: const InputDecoration(
                          border: OutlineInputBorder(),
                          labelText: 'API preset',
                        ),
                        items: settingsProvider.apiConfigs
                            .map((c) => DropdownMenuItem(value: c.id, child: Text(c.name)))
                            .toList(growable: false),
                        onChanged: (v) => setState(() => _motionSession.selectedApiPresetId = v),
                      ),
                    ),
                    Expanded(
                      child: ListView.builder(
                        itemCount: _motionSession.messages.length,
                        itemBuilder: (_, i) {
                          final m = _motionSession.messages[i];
                          if (m.toolName != null) {
                            return ExpansionTile(
                              title: Text('${m.role}: ${m.toolName}'),
                              subtitle: Text(m.content),
                              children: [
                                Padding(
                                  padding: const EdgeInsets.all(8),
                                  child: Text('args=${jsonEncode(m.toolArguments)}\nresult=${m.toolResult}'),
                                ),
                              ],
                            );
                          }
                          return ListTile(title: Text(m.role), subtitle: Text(m.content));
                        },
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.all(8),
                      child: Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: _motionPromptController,
                              decoration: const InputDecoration(
                                border: OutlineInputBorder(),
                                hintText: 'Prompt for motion generation',
                              ),
                            ),
                          ),
                          IconButton(
                            onPressed: _sendingMotionPrompt ? null : () => _sendMotionPrompt(context),
                            icon: _sendingMotionPrompt
                                ? const SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(strokeWidth: 2),
                                  )
                                : const Icon(Icons.send),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
    );
  }
}

class _CommandLogEntry {
  const _CommandLogEntry({
    required this.input,
    required this.parsed,
    required this.errors,
  });

  final String input;
  final String parsed;
  final List<String> errors;
  bool get success => errors.isEmpty;
}

class MotionGenMessage {
  const MotionGenMessage({
    required this.role,
    required this.content,
    this.toolName,
    this.toolArguments,
    this.toolResult,
  });

  final String role;
  final String content;
  final String? toolName;
  final Map<String, dynamic>? toolArguments;
  final String? toolResult;
}

class MotionGenChatSession {
  MotionGenChatSession({List<MotionGenMessage>? messages, this.selectedApiPresetId})
      : messages = messages ?? <MotionGenMessage>[];

  List<MotionGenMessage> messages;
  String? selectedApiPresetId;
}

class _ToolCall {
  const _ToolCall(this.name, this.arguments);

  final String name;
  final Map<String, dynamic> arguments;
}
