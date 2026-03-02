import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../../data/models/auto_motion_config.dart';
import '../../data/models/gesture_motion_mapping.dart';
import '../../data/models/live2d_parameter_preset.dart';
import '../../data/models/model3_data.dart';
import '../../data/repositories/live2d_settings_repository.dart';
import '../../data/services/auto_motion_service.dart';
import '../../data/services/gesture_motion_mapper.dart';
import '../../data/services/live2d_native_bridge.dart';
import '../../data/services/model3_json_parser.dart';
import '../../domain/entities/interaction_event.dart';
import 'live2d_function_test_screen.dart';

class Live2DAdvancedSettingsScreen extends StatefulWidget {
  const Live2DAdvancedSettingsScreen({
    super.key,
    required this.model3Path,
  });

  final String? model3Path;

  @override
  State<Live2DAdvancedSettingsScreen> createState() =>
      _Live2DAdvancedSettingsScreenState();
}

class _Live2DAdvancedSettingsScreenState
    extends State<Live2DAdvancedSettingsScreen>
    with TickerProviderStateMixin {
  late final TabController _tabController;
  final Model3JsonParser _parser = Model3JsonParser();
  Model3Data? _model3Data;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _loadModel3Data();
  }

  @override
  void didUpdateWidget(covariant Live2DAdvancedSettingsScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.model3Path != widget.model3Path) {
      _loadModel3Data();
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadModel3Data() async {
    final modelPath = widget.model3Path;
    if (modelPath == null || modelPath.isEmpty) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _model3Data = null;
        });
      }
      return;
    }

    setState(() {
      _isLoading = true;
    });

    final parsed = await _parser.parseFile(modelPath);
    if (!mounted) {
      return;
    }

    setState(() {
      _isLoading = false;
      _model3Data = parsed;
    });
  }

  @override
  Widget build(BuildContext context) {
    final modelPath = widget.model3Path;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Live2D 고급 설정'),
        actions: [
          IconButton(
            icon: const Icon(Icons.science),
            tooltip: 'Live2D Function Test',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute<void>(
                  builder: (_) => Live2DFunctionTestScreen(modelPath: widget.model3Path),
                ),
              );
            },
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Auto Motion'),
            Tab(text: 'Gesture Mapping'),
            Tab(text: 'Interaction Test'),
            Tab(text: 'Motion & Params'),
          ],
        ),
      ),
      body: Column(
        children: [
          if (modelPath != null)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              color: Theme.of(context).colorScheme.surfaceContainerHighest,
              child: Text(
                'Model3: $modelPath',
                style: Theme.of(context).textTheme.bodySmall,
                overflow: TextOverflow.ellipsis,
              ),
            )
          else
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              color: Theme.of(context).colorScheme.errorContainer,
              child: Text(
                '모델 경로가 없습니다. 먼저 Live2D 모델을 선택하세요.',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: _isLoading
                  ? const [
                      _ComingSoonTabPlaceholder(),
                      _ComingSoonTabPlaceholder(),
                      _ComingSoonTabPlaceholder(),
                      _ComingSoonTabPlaceholder(),
                    ]
                  : [
                      _AutoMotionTab(
                        model3Data: _model3Data,
                        modelPath: modelPath,
                        isLoading: _isLoading,
                      ),
                      _GestureMappingTab(
                        model3Data: _model3Data,
                        modelPath: modelPath,
                        isLoading: _isLoading,
                      ),
                      _InteractionTestTab(
                        model3Data: _model3Data,
                        isLoading: _isLoading,
                      ),
                      _MotionParametersTab(
                        model3Data: _model3Data,
                        modelPath: modelPath,
                        isLoading: _isLoading,
                      ),
                    ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ComingSoonTabPlaceholder extends StatelessWidget {
  const _ComingSoonTabPlaceholder();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Text('Coming soon'),
    );
  }
}

class _AutoMotionTab extends StatefulWidget {
  const _AutoMotionTab({
    required this.model3Data,
    required this.modelPath,
    required this.isLoading,
  });

  final Model3Data? model3Data;
  final String? modelPath;
  final bool isLoading;

  @override
  State<_AutoMotionTab> createState() => _AutoMotionTabState();
}

class _AutoMotionTabState extends State<_AutoMotionTab> {
  final AutoMotionService _autoMotionService = AutoMotionService();
  final Live2DSettingsRepository _repo = Live2DSettingsRepository();
  AutoMotionConfig _config = AutoMotionConfig.defaults();
  bool _loadingConfig = true;

  @override
  void initState() {
    super.initState();
    _loadConfig();
  }

  @override
  void didUpdateWidget(covariant _AutoMotionTab oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.model3Data != widget.model3Data && widget.model3Data != null) {
      _onModelChanged(widget.model3Data!);
    }
  }

  Future<void> _onModelChanged(Model3Data data) async {
    await _sanitizeConfigForModel(data);
    if (_config.enabled) {
      await _autoMotionService.applyConfig(_config, data);
    }
  }

  Future<void> _loadConfig() async {
    final modelPath = widget.modelPath;
    final loaded = modelPath == null || modelPath.isEmpty
        ? await _autoMotionService.loadConfig()
        : (await _repo.loadAutoMotionConfig(modelPath)) ??
            await _autoMotionService.loadConfig();
    if (!mounted) {
      return;
    }

    setState(() {
      _config = loaded;
      _loadingConfig = false;
    });

    final model3Data = widget.model3Data;
    if (model3Data != null) {
      await _sanitizeConfigForModel(model3Data);
      if (_config.enabled) {
        await _autoMotionService.applyConfig(_config, model3Data);
      }
    }
  }

  Future<void> _sanitizeConfigForModel(Model3Data data) async {
    var next = _config;
    final groupKeys = data.motionGroups.keys.toList(growable: false);
    if (groupKeys.isEmpty) {
      next = next.copyWith(clearMotionGroup: true, enabled: false);
    } else if (next.motionGroup == null || !groupKeys.contains(next.motionGroup)) {
      next = next.copyWith(motionGroup: groupKeys.first, enabled: next.enabled);
    }

    final expressionNames = data.expressions.map((e) => e.name).toSet();
    if (next.expressionSelection != null &&
        !expressionNames.contains(next.expressionSelection)) {
      next = next.copyWith(clearExpressionSelection: true);
    }

    if (next != _config) {
      setState(() {
        _config = next;
      });
      await _autoMotionService.saveConfig(next);
      final modelPath = widget.modelPath;
      if (modelPath != null && modelPath.isNotEmpty) {
        await _repo.saveAutoMotionConfig(modelPath, next);
      }
    }
  }

  Future<void> _updateConfig(AutoMotionConfig config) async {
    final data = widget.model3Data;
    setState(() {
      _config = config;
    });
    if (data == null) {
      final saved = config.copyWith(enabled: false);
      await _autoMotionService.saveConfig(saved);
      final modelPath = widget.modelPath;
      if (modelPath != null && modelPath.isNotEmpty) {
        await _repo.saveAutoMotionConfig(modelPath, saved);
      }
      return;
    }
    await _autoMotionService.applyConfig(config, data);
    final modelPath = widget.modelPath;
    if (modelPath != null && modelPath.isNotEmpty) {
      await _repo.saveAutoMotionConfig(modelPath, config);
    }
  }

  @override
  Widget build(BuildContext context) {
    final data = widget.model3Data;
    if (widget.isLoading || _loadingConfig) {
      return const Center(child: CircularProgressIndicator());
    }

    if (data == null) {
      return const Center(child: Text('모델 데이터를 불러올 수 없습니다.'));
    }

    final groups = data.motionGroups.keys.toList(growable: false);
    final expressions = data.expressions.map((e) => e.name).toList(growable: false);

    final selectedGroup = groups.contains(_config.motionGroup)
        ? _config.motionGroup
        : (groups.isNotEmpty ? groups.first : null);

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        SwitchListTile(
          title: const Text('Enable Auto Motion'),
          subtitle: Text(_autoMotionService.isRunning ? 'Running' : 'Stopped'),
          value: _config.enabled,
          onChanged: groups.isEmpty
              ? null
              : (value) {
                  _updateConfig(_config.copyWith(enabled: value, motionGroup: selectedGroup));
                },
        ),
        const SizedBox(height: 8),
        DropdownButtonFormField<String>(
          decoration: const InputDecoration(
            labelText: 'Idle motion group',
            border: OutlineInputBorder(),
          ),
          initialValue: selectedGroup,
          items: groups
              .map(
                (group) => DropdownMenuItem<String>(
                  value: group,
                  child: Text('$group (${data.motionGroups[group]?.length ?? 0})'),
                ),
              )
              .toList(growable: false),
          onChanged: groups.isEmpty
              ? null
              : (value) {
                  if (value == null) {
                    return;
                  }
                  _updateConfig(_config.copyWith(motionGroup: value));
                },
        ),
        const SizedBox(height: 12),
        Text('Idle motion interval: ${_config.intervalSeconds}s'),
        Slider(
          min: 5,
          max: 120,
          divisions: 23,
          value: _config.intervalSeconds.toDouble().clamp(5, 120),
          label: '${_config.intervalSeconds}s',
          onChanged: (value) {
            _updateConfig(_config.copyWith(intervalSeconds: value.round()));
          },
        ),
        SwitchListTile(
          title: const Text('Random mode'),
          subtitle: const Text('OFF uses sequential motion order'),
          value: _config.randomMode,
          onChanged: (value) {
            _updateConfig(_config.copyWith(randomMode: value));
          },
        ),
        SwitchListTile(
          title: const Text('Auto-expression change'),
          subtitle: Text(
            expressions.isEmpty
                ? 'No expressions found in model'
                : 'Change expression when idle motion is triggered',
          ),
          value: _config.autoExpressionChange,
          onChanged: expressions.isEmpty
              ? null
              : (value) {
                  _updateConfig(_config.copyWith(autoExpressionChange: value));
                },
        ),
        const SizedBox(height: 8),
        DropdownButtonFormField<String>(
          decoration: const InputDecoration(
            labelText: 'Expression change group',
            border: OutlineInputBorder(),
          ),
          initialValue: _config.expressionSelection,
          hint: const Text('All expressions (cycle/random)'),
          items: expressions
              .map(
                (name) => DropdownMenuItem<String>(
                  value: name,
                  child: Text(name),
                ),
              )
              .toList(growable: false),
          onChanged: !_config.autoExpressionChange || expressions.isEmpty
              ? null
              : (value) {
                  _updateConfig(
                    _config.copyWith(
                      expressionSelection: value,
                      clearExpressionSelection: value == null,
                    ),
                  );
                },
        ),
      ],
    );
  }
}

class _GestureMappingTab extends StatefulWidget {
  const _GestureMappingTab({
    required this.model3Data,
    required this.modelPath,
    required this.isLoading,
  });

  final Model3Data? model3Data;
  final String? modelPath;
  final bool isLoading;

  @override
  State<_GestureMappingTab> createState() => _GestureMappingTabState();
}

class _GestureMappingTabState extends State<_GestureMappingTab> {
  final GestureMotionMapper _mapper = GestureMotionMapper();
  final Live2DSettingsRepository _repo = Live2DSettingsRepository();
  GestureMotionConfig _config = GestureMotionConfig.defaults();
  bool _loading = true;

  static const Map<InteractionType, String> _gestureLabels = <InteractionType, String>{
    InteractionType.tap: 'Single Tap',
    InteractionType.doubleTap: 'Double Tap',
    InteractionType.longPress: 'Long Press',
    InteractionType.swipeLeft: 'Swipe Left',
    InteractionType.swipeRight: 'Swipe Right',
    InteractionType.swipeUp: 'Swipe Up',
    InteractionType.swipeDown: 'Swipe Down',
  };

  @override
  void initState() {
    super.initState();
    _loadConfig();
  }

  Future<void> _loadConfig() async {
    final modelPath = widget.modelPath;
    final config = modelPath == null || modelPath.isEmpty
        ? await _mapper.loadConfig()
        : (await _repo.loadGestureMappingConfig(modelPath)) ??
            await _mapper.loadConfig();
    if (!mounted) {
      return;
    }
    setState(() {
      _config = config;
      _loading = false;
    });
  }

  Future<void> _saveConfig(GestureMotionConfig config) async {
    await _mapper.setConfig(config);
    final modelPath = widget.modelPath;
    if (modelPath != null && modelPath.isNotEmpty) {
      await _repo.saveGestureMappingConfig(modelPath, config);
    }
    if (!mounted) {
      return;
    }
    setState(() {
      _config = config;
    });
  }

  Future<void> _toggleRandom(InteractionType gesture, bool enabled) async {
    final nextRandom = Map<InteractionType, bool>.from(_config.randomPerGesture)
      ..[gesture] = enabled;
    await _saveConfig(_config.copyWith(randomPerGesture: nextRandom));
  }

  Future<void> _addEntry(InteractionType gesture) async {
    final data = widget.model3Data;
    if (data == null || data.motionGroups.isEmpty) {
      return;
    }
    final firstGroup = data.motionGroups.keys.first;
    final next = GestureMotionEntry(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      motionGroup: firstGroup,
      motionIndex: 0,
      enabled: true,
      priority: 5,
    );
    final updated = _config.entriesFor(gesture)..add(next);
    final mappings = Map<InteractionType, List<GestureMotionEntry>>.from(_config.mappings)
      ..[gesture] = updated;
    await _saveConfig(_config.copyWith(mappings: mappings));
  }

  Future<void> _updateEntry(
    InteractionType gesture,
    GestureMotionEntry entry,
  ) async {
    final updated = _config
        .entriesFor(gesture)
        .map((e) => e.id == entry.id ? entry : e)
        .toList(growable: false);
    final mappings = Map<InteractionType, List<GestureMotionEntry>>.from(_config.mappings)
      ..[gesture] = updated;
    await _saveConfig(_config.copyWith(mappings: mappings));
  }

  Future<void> _removeEntry(InteractionType gesture, String id) async {
    final updated = _config
        .entriesFor(gesture)
        .where((e) => e.id != id)
        .toList(growable: false);
    final mappings = Map<InteractionType, List<GestureMotionEntry>>.from(_config.mappings)
      ..[gesture] = updated;
    await _saveConfig(_config.copyWith(mappings: mappings));
  }

  @override
  Widget build(BuildContext context) {
    if (widget.isLoading || _loading) {
      return const Center(child: CircularProgressIndicator());
    }

    final data = widget.model3Data;
    if (data == null) {
      return const Center(child: Text('모델 데이터를 불러올 수 없습니다.'));
    }

    return ListView(
      padding: const EdgeInsets.all(16),
      children: GestureMotionConfig.supportedGestures
          .map(
            (gesture) => _buildGestureCard(
              context,
              gesture,
              _config.entriesFor(gesture),
              data,
            ),
          )
          .toList(growable: false),
    );
  }

  Widget _buildGestureCard(
    BuildContext context,
    InteractionType gesture,
    List<GestureMotionEntry> entries,
    Model3Data data,
  ) {
    final theme = Theme.of(context);
    final label = _gestureLabels[gesture] ?? gesture.name;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    label,
                    style: theme.textTheme.titleMedium,
                  ),
                ),
                TextButton.icon(
                  onPressed: () => _addEntry(gesture),
                  icon: const Icon(Icons.add),
                  label: const Text('Add Mapping'),
                ),
              ],
            ),
            SwitchListTile(
              dense: true,
              contentPadding: EdgeInsets.zero,
              title: const Text('Random selection'),
              subtitle: const Text('OFF uses highest-priority mapping first'),
              value: _config.randomEnabled(gesture),
              onChanged: (value) => _toggleRandom(gesture, value),
            ),
            if (entries.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 8),
                child: Text('No mappings yet.'),
              )
            else
              ...entries.map((entry) => _buildEntryEditor(gesture, entry, data)),
          ],
        ),
      ),
    );
  }

  Widget _buildEntryEditor(
    InteractionType gesture,
    GestureMotionEntry entry,
    Model3Data data,
  ) {
    final groups = data.motionGroups.keys.toList(growable: false);
    final motionCount = (data.motionGroups[entry.motionGroup] ?? const <String>[]).length;
    final safeMotionCount = motionCount <= 0 ? 1 : motionCount;
    final safeIndex = entry.motionIndex.clamp(0, safeMotionCount - 1);
    final expressions = data.expressions.map((e) => e.name).toList(growable: false);
    final missingGroup = !groups.contains(entry.motionGroup);
    final missingMotion = !missingGroup && entry.motionIndex >= motionCount;
    final missingExpression = entry.expressionOverride != null &&
        entry.expressionOverride!.isNotEmpty &&
        !expressions.contains(entry.expressionOverride);
    final hasMissingReference = missingGroup || missingMotion || missingExpression;

    return Container(
      margin: const EdgeInsets.only(top: 10),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.black12),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Mapping #${entry.id.substring(entry.id.length > 4 ? entry.id.length - 4 : 0)}',
                ),
              ),
              if (hasMissingReference)
                const Padding(
                  padding: EdgeInsets.only(right: 6),
                  child: Tooltip(
                    message: 'Current model does not contain one or more referenced values',
                    child: Icon(Icons.warning_amber_rounded, color: Colors.orange),
                  ),
                ),
              Switch(
                value: entry.enabled,
                onChanged: (value) {
                  _updateEntry(gesture, entry.copyWith(enabled: value));
                },
              ),
              IconButton(
                onPressed: () => _removeEntry(gesture, entry.id),
                icon: const Icon(Icons.delete_outline),
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (hasMissingReference)
            Container(
              width: double.infinity,
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.orange.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.orange.withValues(alpha: 0.4)),
              ),
              child: Text(
                "Warning: mapped motion/expression not found in current model.",
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
          const SizedBox(height: 8),
          DropdownButtonFormField<String>(
            initialValue: groups.contains(entry.motionGroup)
                ? entry.motionGroup
                : (groups.isNotEmpty ? groups.first : null),
            decoration: const InputDecoration(
              labelText: 'Motion group',
              border: OutlineInputBorder(),
            ),
            items: groups
                .map(
                  (group) => DropdownMenuItem<String>(
                    value: group,
                    child: Text('$group (${data.motionGroups[group]?.length ?? 0})'),
                  ),
                )
                .toList(growable: false),
            onChanged: (value) {
              if (value == null) {
                return;
              }
              _updateEntry(
                gesture,
                entry.copyWith(motionGroup: value, motionIndex: 0),
              );
            },
          ),
          const SizedBox(height: 8),
          DropdownButtonFormField<int>(
            initialValue: safeIndex,
            decoration: const InputDecoration(
              labelText: 'Motion index',
              border: OutlineInputBorder(),
            ),
            items: List<int>.generate(safeMotionCount, (i) => i)
                .map(
                  (index) => DropdownMenuItem<int>(
                    value: index,
                    child: Text(index.toString()),
                  ),
                )
                .toList(growable: false),
            onChanged: (value) {
              if (value == null) {
                return;
              }
              _updateEntry(gesture, entry.copyWith(motionIndex: value));
            },
          ),
          const SizedBox(height: 8),
          DropdownButtonFormField<String>(
            initialValue: expressions.contains(entry.expressionOverride)
                ? entry.expressionOverride
                : null,
            decoration: const InputDecoration(
              labelText: 'Expression override (optional)',
              border: OutlineInputBorder(),
            ),
            items: expressions
                .map(
                  (exp) => DropdownMenuItem<String>(
                    value: exp,
                    child: Text(exp),
                  ),
                )
                .toList(growable: false),
            onChanged: expressions.isEmpty
                ? null
                : (value) {
                    _updateEntry(
                      gesture,
                      entry.copyWith(
                        expressionOverride: value,
                        clearExpressionOverride: value == null,
                      ),
                    );
                  },
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              const Text('Priority'),
              Expanded(
                child: Slider(
                  min: 1,
                  max: 10,
                  divisions: 9,
                  label: entry.priority.toString(),
                  value: entry.priority.toDouble().clamp(1, 10),
                  onChanged: (value) {
                    _updateEntry(gesture, entry.copyWith(priority: value.round()));
                  },
                ),
              ),
              Text(entry.priority.toString()),
            ],
          ),
        ],
      ),
    );
  }
}

class _InteractionTestTab extends StatefulWidget {
  const _InteractionTestTab({
    required this.model3Data,
    required this.isLoading,
  });

  final Model3Data? model3Data;
  final bool isLoading;

  @override
  State<_InteractionTestTab> createState() => _InteractionTestTabState();
}

class _InteractionTestTabState extends State<_InteractionTestTab> {
  final Map<String, double> _currentValues = <String, double>{};
  final Live2DNativeBridge _bridge = Live2DNativeBridge();

  @override
  void didUpdateWidget(covariant _InteractionTestTab oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.model3Data != widget.model3Data) {
      _initializeParameterValues();
    }
  }

  @override
  void initState() {
    super.initState();
    _initializeParameterValues();
  }

  void _initializeParameterValues() {
    final data = widget.model3Data;
    if (data == null) {
      return;
    }
    final next = <String, double>{
      for (final param in data.parameters) param.id: param.defaultValue,
    };
    setState(() {
      _currentValues
        ..clear()
        ..addAll(next);
    });
  }

  Future<void> _playMotion(String group, int index) async {
    await _bridge.playMotion(group, index);
  }

  Future<void> _setExpression(String name) async {
    await _bridge.setExpression(name);
  }

  Future<void> _setParameter(Model3Parameter parameter, double value) async {
    await _bridge.setParameter(parameter.id, value);
    if (!mounted) {
      return;
    }
    setState(() {
      _currentValues[parameter.id] = value;
    });
  }

  Future<void> _resetParameters(Model3Data data) async {
    for (final parameter in data.parameters) {
      await _bridge.setParameter(parameter.id, parameter.defaultValue);
    }
    if (!mounted) {
      return;
    }
    setState(() {
      for (final parameter in data.parameters) {
        _currentValues[parameter.id] = parameter.defaultValue;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final data = widget.model3Data;
    if (widget.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (data == null) {
      return const Center(child: Text('모델 데이터를 불러올 수 없습니다.'));
    }

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Motion Groups'),
                const SizedBox(height: 8),
                ...data.motionGroups.entries.map(
                  (entry) => Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: List<Widget>.generate(
                      entry.value.length,
                      (index) => ActionChip(
                        label: Text('${entry.key}/$index'),
                        onPressed: () => _playMotion(entry.key, index),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Expressions'),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: data.expressions
                      .map(
                        (exp) => ActionChip(
                          label: Text(exp.name),
                          onPressed: () => _setExpression(exp.name),
                        ),
                      )
                      .toList(growable: false),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Expanded(child: Text('Parameters')),
                    TextButton.icon(
                      onPressed: () => _resetParameters(data),
                      icon: const Icon(Icons.refresh),
                      label: const Text('Reset All Parameters'),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                ...data.parameters.map((parameter) {
                  final current = _currentValues[parameter.id] ?? parameter.defaultValue;
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('${parameter.name} (${parameter.id})'),
                      Slider(
                        min: parameter.min,
                        max: parameter.max,
                        value: current.clamp(parameter.min, parameter.max),
                        onChanged: (value) => _setParameter(parameter, value),
                      ),
                      Text(
                        'Min ${parameter.min.toStringAsFixed(2)} · '
                        'Default ${parameter.defaultValue.toStringAsFixed(2)} · '
                        'Max ${parameter.max.toStringAsFixed(2)} · '
                        'Current ${current.toStringAsFixed(2)}',
                      ),
                      const SizedBox(height: 8),
                    ],
                  );
                }),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

enum _ParameterSortField { id, name, min, defaultValue, max, current }

class _MotionParametersTab extends StatefulWidget {
  const _MotionParametersTab({
    required this.model3Data,
    required this.modelPath,
    required this.isLoading,
  });

  final Model3Data? model3Data;
  final String? modelPath;
  final bool isLoading;

  @override
  State<_MotionParametersTab> createState() => _MotionParametersTabState();
}

class _MotionParametersTabState extends State<_MotionParametersTab> {
  final Live2DNativeBridge _bridge = Live2DNativeBridge();
  final Live2DSettingsRepository _repo = Live2DSettingsRepository();
  final TextEditingController _searchController = TextEditingController();
  final TextEditingController _presetNameController = TextEditingController();

  final Map<String, double> _currentValues = <String, double>{};
  Map<String, bool> _motionEnabled = <String, bool>{};
  List<Live2DParameterPreset> _presets = <Live2DParameterPreset>[];

  String _search = '';
  _ParameterSortField _sortField = _ParameterSortField.name;
  bool _sortAsc = true;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _searchController.addListener(() {
      setState(() {
        _search = _searchController.text.trim().toLowerCase();
      });
    });
    _loadState();
  }

  @override
  void didUpdateWidget(covariant _MotionParametersTab oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.modelPath != widget.modelPath ||
        oldWidget.model3Data != widget.model3Data) {
      _loadState();
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    _presetNameController.dispose();
    super.dispose();
  }

  Future<void> _loadState() async {
    final data = widget.model3Data;
    final modelPath = widget.modelPath;
    if (data == null || modelPath == null || modelPath.isEmpty) {
      if (!mounted) {
        return;
      }
      setState(() {
        _loading = false;
      });
      return;
    }

    final defaults = <String, bool>{
      for (final entry in data.motionGroups.entries)
        for (var i = 0; i < entry.value.length; i++) '${entry.key}#$i': true,
    };

    final savedMotionEnabled = await _repo.loadMotionEnabled(modelPath);
    final presets = await _repo.loadParameterPresets(modelPath);
    final current = <String, double>{
      for (final parameter in data.parameters) parameter.id: parameter.defaultValue,
    };

    if (!mounted) {
      return;
    }
    setState(() {
      _motionEnabled = {
        for (final key in defaults.keys) key: savedMotionEnabled[key] ?? true,
      };
      _presets = presets;
      _currentValues
        ..clear()
        ..addAll(current);
      _loading = false;
    });
  }

  Future<void> _setMotionEnabled(String key, bool enabled) async {
    final modelPath = widget.modelPath;
    if (modelPath == null || modelPath.isEmpty) {
      return;
    }
    setState(() {
      _motionEnabled[key] = enabled;
    });
    await _repo.saveMotionEnabled(modelPath, _motionEnabled);
  }

  Future<void> _setParameter(Model3Parameter parameter, double value) async {
    await _bridge.setParameter(parameter.id, value);
    if (!mounted) {
      return;
    }
    setState(() {
      _currentValues[parameter.id] = value;
    });
  }

  Future<void> _savePreset() async {
    final modelPath = widget.modelPath;
    final data = widget.model3Data;
    if (modelPath == null || modelPath.isEmpty || data == null) {
      return;
    }
    final name = _presetNameController.text.trim();
    if (name.isEmpty) {
      return;
    }

    final overrides = <String, double>{};
    for (final parameter in data.parameters) {
      final current = _currentValues[parameter.id] ?? parameter.defaultValue;
      if ((current - parameter.defaultValue).abs() > 0.0001) {
        overrides[parameter.id] = current;
      }
    }

    final preset = Live2DParameterPreset(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      name: name,
      overrides: overrides,
    );

    final next = <Live2DParameterPreset>[..._presets, preset];
    await _repo.saveParameterPresets(modelPath, next);
    if (!mounted) {
      return;
    }
    setState(() {
      _presets = next;
      _presetNameController.clear();
    });
  }

  Future<void> _applyPreset(Live2DParameterPreset preset) async {
    final data = widget.model3Data;
    if (data == null) {
      return;
    }
    for (final parameter in data.parameters) {
      final target = preset.overrides[parameter.id] ?? parameter.defaultValue;
      await _bridge.setParameter(parameter.id, target);
    }
    if (!mounted) {
      return;
    }
    setState(() {
      for (final parameter in data.parameters) {
        _currentValues[parameter.id] =
            preset.overrides[parameter.id] ?? parameter.defaultValue;
      }
    });
  }

  Future<void> _deletePreset(String presetId) async {
    final modelPath = widget.modelPath;
    if (modelPath == null || modelPath.isEmpty) {
      return;
    }
    final next = _presets.where((e) => e.id != presetId).toList(growable: false);
    await _repo.saveParameterPresets(modelPath, next);
    if (!mounted) {
      return;
    }
    setState(() {
      _presets = next;
    });
  }

  Future<void> _exportPresets() async {
    final modelPath = widget.modelPath;
    if (modelPath == null || modelPath.isEmpty) {
      return;
    }
    final path = await _repo.exportParameterPresets(modelPath, _presets);
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Exported: $path')),
    );
  }

  Future<void> _importPresets() async {
    final modelPath = widget.modelPath;
    if (modelPath == null || modelPath.isEmpty) {
      return;
    }
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: <String>['json'],
    );
    if (result == null || result.files.isEmpty) {
      return;
    }
    final path = result.files.single.path;
    if (path == null || path.isEmpty) {
      return;
    }

    final imported = await _repo.importParameterPresets(path);
    final merged = <Live2DParameterPreset>[
      ..._presets,
      ...imported.map(
        (p) => p.copyWith(
          id: '${DateTime.now().microsecondsSinceEpoch}_${p.id}',
        ),
      ),
    ];
    await _repo.saveParameterPresets(modelPath, merged);
    if (!mounted) {
      return;
    }
    setState(() {
      _presets = merged;
    });
  }

  List<_MotionItem> _buildMotionItems(Model3Data data) {
    final items = <_MotionItem>[];
    for (final entry in data.motionGroups.entries) {
      for (var i = 0; i < entry.value.length; i++) {
        final key = '${entry.key}#$i';
        final label = entry.value[i];
        if (_search.isNotEmpty) {
          final haystack = '${entry.key} $i $label'.toLowerCase();
          if (!haystack.contains(_search)) {
            continue;
          }
        }
        items.add(
          _MotionItem(
            keyName: key,
            group: entry.key,
            index: i,
            label: label,
            enabled: _motionEnabled[key] ?? true,
          ),
        );
      }
    }
    return items;
  }

  List<Model3Parameter> _sortedParameters(Model3Data data) {
    final list = List<Model3Parameter>.from(data.parameters);
    int compare(Model3Parameter a, Model3Parameter b) {
      switch (_sortField) {
        case _ParameterSortField.id:
          return a.id.compareTo(b.id);
        case _ParameterSortField.name:
          return a.name.compareTo(b.name);
        case _ParameterSortField.min:
          return a.min.compareTo(b.min);
        case _ParameterSortField.defaultValue:
          return a.defaultValue.compareTo(b.defaultValue);
        case _ParameterSortField.max:
          return a.max.compareTo(b.max);
        case _ParameterSortField.current:
          return (_currentValues[a.id] ?? a.defaultValue)
              .compareTo(_currentValues[b.id] ?? b.defaultValue);
      }
    }

    list.sort((a, b) {
      final v = compare(a, b);
      return _sortAsc ? v : -v;
    });
    return list;
  }

  void _toggleSort(_ParameterSortField field) {
    setState(() {
      if (_sortField == field) {
        _sortAsc = !_sortAsc;
      } else {
        _sortField = field;
        _sortAsc = true;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    if (widget.isLoading || _loading) {
      return const Center(child: CircularProgressIndicator());
    }
    final data = widget.model3Data;
    if (data == null) {
      return const Center(child: Text('모델 데이터를 불러올 수 없습니다.'));
    }

    final motionItems = _buildMotionItems(data);
    final parameters = _sortedParameters(data);

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        TextField(
          controller: _searchController,
          decoration: const InputDecoration(
            border: OutlineInputBorder(),
            labelText: 'Search motions',
          ),
        ),
        const SizedBox(height: 10),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Motion List'),
                const SizedBox(height: 8),
                ...motionItems.map((item) {
                  return SwitchListTile(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    value: item.enabled,
                    title: Text('${item.group} [${item.index}]'),
                    subtitle: Text(item.label),
                    onChanged: (value) => _setMotionEnabled(item.keyName, value),
                  );
                }),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Parameter Table'),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    ActionChip(
                      label: const Text('ID'),
                      onPressed: () => _toggleSort(_ParameterSortField.id),
                    ),
                    ActionChip(
                      label: const Text('Name'),
                      onPressed: () => _toggleSort(_ParameterSortField.name),
                    ),
                    ActionChip(
                      label: const Text('Min'),
                      onPressed: () => _toggleSort(_ParameterSortField.min),
                    ),
                    ActionChip(
                      label: const Text('Default'),
                      onPressed: () => _toggleSort(_ParameterSortField.defaultValue),
                    ),
                    ActionChip(
                      label: const Text('Max'),
                      onPressed: () => _toggleSort(_ParameterSortField.max),
                    ),
                    ActionChip(
                      label: const Text('Current'),
                      onPressed: () => _toggleSort(_ParameterSortField.current),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                ...parameters.map((p) {
                  final current = _currentValues[p.id] ?? p.defaultValue;
                  return ListTile(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    title: Text('${p.name} (${p.id})'),
                    subtitle: Text(
                      'Min ${p.min.toStringAsFixed(2)} | '
                      'Default ${p.defaultValue.toStringAsFixed(2)} | '
                      'Max ${p.max.toStringAsFixed(2)} | '
                      'Current ${current.toStringAsFixed(2)}',
                    ),
                    trailing: SizedBox(
                      width: 180,
                      child: Slider(
                        min: p.min,
                        max: p.max,
                        value: current.clamp(p.min, p.max),
                        onChanged: (value) => _setParameter(p, value),
                      ),
                    ),
                  );
                }),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Presets'),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _presetNameController,
                        decoration: const InputDecoration(
                          border: OutlineInputBorder(),
                          labelText: 'Preset name',
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    FilledButton(
                      onPressed: _savePreset,
                      child: const Text('Save Current as Preset'),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    OutlinedButton(
                      onPressed: _exportPresets,
                      child: const Text('Export JSON'),
                    ),
                    const SizedBox(width: 8),
                    OutlinedButton(
                      onPressed: _importPresets,
                      child: const Text('Import JSON'),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                ..._presets.map(
                  (preset) => ListTile(
                    dense: true,
                    title: Text(preset.name),
                    subtitle: Text('Overrides: ${preset.overrides.length}'),
                    trailing: Wrap(
                      spacing: 8,
                      children: [
                        TextButton(
                          onPressed: () => _applyPreset(preset),
                          child: const Text('Apply Preset'),
                        ),
                        IconButton(
                          onPressed: () => _deletePreset(preset.id),
                          icon: const Icon(Icons.delete_outline),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _MotionItem {
  const _MotionItem({
    required this.keyName,
    required this.group,
    required this.index,
    required this.label,
    required this.enabled,
  });

  final String keyName;
  final String group;
  final int index;
  final String label;
  final bool enabled;
}
