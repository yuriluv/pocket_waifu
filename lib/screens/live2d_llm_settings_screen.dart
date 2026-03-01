import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../features/live2d/data/services/live2d_native_bridge.dart';
import '../providers/settings_provider.dart';

class Live2DLlmSettingsScreen extends StatefulWidget {
  const Live2DLlmSettingsScreen({super.key});

  @override
  State<Live2DLlmSettingsScreen> createState() => _Live2DLlmSettingsScreenState();
}

class _Live2DLlmSettingsScreenState extends State<Live2DLlmSettingsScreen> {
  final Live2DNativeBridge _bridge = Live2DNativeBridge();
  final TextEditingController _templateController = TextEditingController();

  Timer? _modelWatchTimer;
  String _lastModelSignature = '';
  String _generatedPreview = '';
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    final settings = context.read<SettingsProvider>().settings;
    _templateController.text = settings.live2dSystemPromptTemplate;
    _reloadPreview();
    _startModelWatcher();
  }

  @override
  void dispose() {
    _modelWatchTimer?.cancel();
    _templateController.dispose();
    super.dispose();
  }

  void _startModelWatcher() {
    _modelWatchTimer?.cancel();
    _modelWatchTimer = Timer.periodic(const Duration(seconds: 2), (_) async {
      if (!mounted) return;
      final signature = await _buildModelSignature();
      if (signature == _lastModelSignature) {
        return;
      }
      _lastModelSignature = signature;
      await _reloadPreview();
    });
  }

  Future<String> _buildModelSignature() async {
    final info = await _bridge.getModelInfo();
    final motions = await _bridge.getMotionGroups();
    final expressions = await _bridge.getExpressions();
    final params = await _bridge.getParameterIds();
    return '${info.hashCode}|${motions.join(',')}|${expressions.join(',')}|${params.join(',')}';
  }

  Future<void> _reloadPreview() async {
    final provider = context.read<SettingsProvider>();
    final settings = provider.settings;
    setState(() => _loading = true);

    final motionGroups = await _bridge.getMotionGroups();
    final expressions = await _bridge.getExpressions();
    final parameterIds = await _bridge.getParameterIds();

    final preview = _buildSystemPromptPreview(
      template: _templateController.text.trim().isEmpty
          ? settings.live2dSystemPromptTemplate
          : _templateController.text.trim(),
      motions: motionGroups,
      expressions: expressions,
      parameters: parameterIds,
      tokenBudget: settings.live2dSystemPromptTokenBudget,
    );

    if (!mounted) return;
    setState(() {
      _generatedPreview = preview;
      _loading = false;
    });
  }

  String _buildSystemPromptPreview({
    required String template,
    required List<String> motions,
    required List<String> expressions,
    required List<String> parameters,
    required int tokenBudget,
  }) {
    final sections = <String>[
      template,
      '[Model Runtime Capability]',
      'Motions: ${motions.isEmpty ? '(none)' : motions.join(', ')}',
      'Expressions: ${expressions.isEmpty ? '(none)' : expressions.join(', ')}',
      'Parameters: ${parameters.isEmpty ? '(none)' : parameters.join(', ')}',
    ];

    final full = sections.join('\n');
    final maxChars = tokenBudget.clamp(100, 2000) * 4;
    if (full.length <= maxChars) {
      return full;
    }
    return '${full.substring(0, maxChars)}\n...[truncated by token budget]';
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<SettingsProvider>();
    final settings = provider.settings;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Live2D-LLM Integration'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          SwitchListTile(
            value: settings.live2dLlmIntegrationEnabled,
            title: const Text('Enable Live2D-LLM Integration'),
            subtitle: const Text('통합 파이프라인 전체 ON/OFF'),
            onChanged: provider.setLive2DLlmIntegrationEnabled,
          ),
          SwitchListTile(
            value: settings.live2dDirectiveParsingEnabled,
            title: const Text('Directive parsing'),
            subtitle: const Text('Inline/XML 지시어를 파싱해 Live2D 명령 실행'),
            onChanged: provider.setLive2DDirectiveParsingEnabled,
          ),
          SwitchListTile(
            value: settings.live2dPromptInjectionEnabled,
            title: const Text('System prompt capability injection'),
            subtitle: const Text('현재 모델의 motion/expression/parameter를 프롬프트에 주입'),
            onChanged: provider.setLive2DPromptInjectionEnabled,
          ),
          SwitchListTile(
            value: settings.live2dLuaExecutionEnabled,
            title: const Text('Lua execution'),
            subtitle: const Text('주의: 스크립트 실행을 허용합니다.'),
            onChanged: provider.setLive2DLuaExecutionEnabled,
          ),
          SwitchListTile(
            value: settings.live2dShowRawDirectivesInChat,
            title: const Text('Show raw directives in chat'),
            subtitle: const Text('지시어를 숨기지 않고 칩 형태(⟦...⟧)로 표시'),
            onChanged: provider.setLive2DShowRawDirectivesInChat,
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _templateController,
            maxLines: 8,
            decoration: const InputDecoration(
              labelText: 'Custom prompt override',
              border: OutlineInputBorder(),
            ),
            onChanged: (value) {
              provider.setLive2DSystemPromptTemplate(value);
              _reloadPreview();
            },
          ),
          const SizedBox(height: 12),
          Text('Token budget: ${settings.live2dSystemPromptTokenBudget}'),
          Slider(
            value: settings.live2dSystemPromptTokenBudget.toDouble(),
            min: 100,
            max: 2000,
            divisions: 38,
            label: settings.live2dSystemPromptTokenBudget.toString(),
            onChanged: (value) {
              provider.setLive2DSystemPromptTokenBudget(value.round());
              _reloadPreview();
            },
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              const Text('System prompt preview'),
              const Spacer(),
              TextButton.icon(
                onPressed: _reloadPreview,
                icon: const Icon(Icons.refresh, size: 18),
                label: const Text('Regenerate'),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
              borderRadius: BorderRadius.circular(8),
            ),
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : SelectableText(
                    _generatedPreview,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
          ),
        ],
      ),
    );
  }
}
