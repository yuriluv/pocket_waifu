// ============================================================================
// ============================================================================
// ============================================================================

import 'package:flutter/material.dart';
import '../../data/services/live2d_native_bridge.dart';
import '../../data/services/interaction_config_service.dart';
import '../../data/services/live2d_log_service.dart';
import '../../domain/entities/gesture_config.dart';
import '../../domain/entities/interaction_event.dart';
import 'auto_behavior_settings_screen.dart';

class InteractionSettingsScreen extends StatefulWidget {
  const InteractionSettingsScreen({super.key});

  @override
  State<InteractionSettingsScreen> createState() =>
      _InteractionSettingsScreenState();
}

class _InteractionSettingsScreenState extends State<InteractionSettingsScreen>
    with TickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('상호작용 설정'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(icon: Icon(Icons.play_circle_outline), text: '모션/표정'),
            Tab(icon: Icon(Icons.touch_app), text: '상호작용'),
            Tab(icon: Icon(Icons.auto_awesome), text: '자동 동작'),
          ],
          labelColor: theme.colorScheme.primary,
          unselectedLabelColor: theme.colorScheme.onSurfaceVariant,
          indicatorColor: theme.colorScheme.primary,
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: const [
          _MotionTestTab(),
          _InteractionMappingTab(),
          _AutoBehaviorTab(),
        ],
      ),
    );
  }
}

// ============================================================================
// ============================================================================

class _MotionTestTab extends StatefulWidget {
  const _MotionTestTab();

  @override
  State<_MotionTestTab> createState() => _MotionTestTabState();
}

class _MotionTestTabState extends State<_MotionTestTab>
    with AutomaticKeepAliveClientMixin {
  final Live2DNativeBridge _bridge = Live2DNativeBridge();
  
  List<String> _motionGroups = [];
  Map<String, int> _motionCounts = {};
  Map<String, List<String>> _motionNames = {};
  List<String> _expressions = [];
  bool _isLoading = true;
  String? _playingMotion;
  String? _activeExpression;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _loadModelInfo();
  }

  Future<void> _loadModelInfo() async {
    setState(() => _isLoading = true);
    try {
      _motionGroups = await _bridge.getMotionGroups();
      
      for (final group in _motionGroups) {
        _motionCounts[group] = await _bridge.getMotionCount(group);
        _motionNames[group] = await _bridge.getMotionNames(group);
      }
      
      _expressions = await _bridge.getExpressions();
      
      live2dLog.info('MotionTest', '모델 정보 로드 완료',
          details: '모션 그룹: ${_motionGroups.length}개, 표정: ${_expressions.length}개');
    } catch (e) {
      live2dLog.error('MotionTest', '모델 정보 로드 실패', error: e);
    }
    
    if (mounted) {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _playMotion(String group, int index) async {
    setState(() => _playingMotion = '$group:$index');
    try {
      await _bridge.playMotion(group, index);
      live2dLog.info('MotionTest', '모션 재생', details: '$group[$index]');
    } catch (e) {
      live2dLog.error('MotionTest', '모션 재생 실패', error: e);
    }
    
    await Future.delayed(const Duration(seconds: 2));
    if (mounted) {
      setState(() => _playingMotion = null);
    }
  }

  Future<void> _setExpression(String expressionId) async {
    setState(() => _activeExpression = expressionId);
    try {
      await _bridge.setExpression(expressionId);
      live2dLog.info('MotionTest', '표정 설정', details: expressionId);
    } catch (e) {
      live2dLog.error('MotionTest', '표정 설정 실패', error: e);
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final theme = Theme.of(context);

    if (_isLoading) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('모델 정보 로드 중...'),
          ],
        ),
      );
    }

    if (_motionGroups.isEmpty && _expressions.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.info_outline,
                size: 64, color: theme.colorScheme.onSurfaceVariant),
            const SizedBox(height: 16),
            Text(
              '모션/표정 정보를 가져올 수 없습니다',
              style: theme.textTheme.titleMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '오버레이를 활성화하고 모델을 로드한 후\n다시 시도해주세요.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 24),
            FilledButton.tonalIcon(
              onPressed: _loadModelInfo,
              icon: const Icon(Icons.refresh),
              label: const Text('다시 로드'),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadModelInfo,
      child: ListView(
        padding: const EdgeInsets.only(bottom: 32),
        children: [
          if (_motionGroups.isNotEmpty) ...[
            _buildSectionHeader(theme, Icons.animation, '모션 그룹',
                trailing: Text('${_motionGroups.length}개',
                    style: theme.textTheme.bodySmall)),
            ..._motionGroups.map((group) => _buildMotionGroupTile(theme, group)),
          ],

          if (_expressions.isNotEmpty) ...[
            const SizedBox(height: 8),
            _buildSectionHeader(theme, Icons.face, '표정',
                trailing: Text('${_expressions.length}개',
                    style: theme.textTheme.bodySmall)),
            _buildExpressionList(theme),
          ],
          
          const SizedBox(height: 16),
          
          Card(
            margin: const EdgeInsets.symmetric(horizontal: 16),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Icon(Icons.info_outline,
                      size: 20, color: theme.colorScheme.primary),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      '모델 변경 후 목록이 업데이트되지 않으면\n아래로 당겨서 새로고침하세요.',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(ThemeData theme, IconData icon, String title,
      {Widget? trailing}) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Row(
        children: [
          Icon(icon, size: 20, color: theme.colorScheme.primary),
          const SizedBox(width: 8),
          Text(
            title,
            style: theme.textTheme.titleMedium?.copyWith(
              color: theme.colorScheme.primary,
              fontWeight: FontWeight.bold,
            ),
          ),
          if (trailing != null) ...[
            const Spacer(),
            trailing,
          ],
        ],
      ),
    );
  }

  Widget _buildMotionGroupTile(ThemeData theme, String group) {
    final count = _motionCounts[group] ?? 0;
    final names = _motionNames[group] ?? [];

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: ExpansionTile(
        leading: Icon(Icons.movie_filter, color: theme.colorScheme.secondary),
        title: Text(group, style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Text('$count개 모션'),
        children: [
          const Divider(height: 1),
          if (count == 0)
            const Padding(
              padding: EdgeInsets.all(16),
              child: Text('모션이 없습니다'),
            )
          else
            ...List.generate(count, (index) {
              final motionKey = '$group:$index';
              final isPlaying = _playingMotion == motionKey;
              final motionName = index < names.length ? names[index] : '$group[$index]';
              
              return ListTile(
                dense: true,
                leading: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 200),
                  child: isPlaying
                      ? SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: theme.colorScheme.primary,
                          ),
                        )
                      : Icon(Icons.play_arrow,
                          size: 24, color: theme.colorScheme.primary),
                ),
                title: Text(
                  motionName,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: isPlaying ? theme.colorScheme.primary : null,
                    fontWeight: isPlaying ? FontWeight.bold : null,
                  ),
                ),
                subtitle: Text('인덱스: $index'),
                trailing: FilledButton.tonal(
                  onPressed: isPlaying ? null : () => _playMotion(group, index),
                  child: Text(isPlaying ? '재생 중...' : '테스트'),
                ),
              );
            }),
        ],
      ),
    );
  }

  Widget _buildExpressionList(ThemeData theme) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            Padding(
              padding: const EdgeInsets.only(left: 16),
              child: ActionChip(
                avatar: Icon(Icons.refresh, size: 18,
                    color: theme.colorScheme.onSurfaceVariant),
                label: const Text('기본'),
                onPressed: () {
                  setState(() => _activeExpression = null);
                  _bridge.setExpression('');
                },
                backgroundColor: _activeExpression == null
                    ? theme.colorScheme.primaryContainer
                    : null,
              ),
            ),
            ..._expressions.map((expr) => Padding(
                  padding: const EdgeInsets.only(left: 8),
                  child: ActionChip(
                    avatar: Icon(Icons.face, size: 18,
                        color: _activeExpression == expr
                            ? theme.colorScheme.primary
                            : theme.colorScheme.onSurfaceVariant),
                    label: Text(expr),
                    onPressed: () => _setExpression(expr),
                    backgroundColor: _activeExpression == expr
                        ? theme.colorScheme.primaryContainer
                        : null,
                  ),
                )),
          ],
        ),
      ),
    );
  }
}

// ============================================================================
// ============================================================================

class _InteractionMappingTab extends StatefulWidget {
  const _InteractionMappingTab();

  @override
  State<_InteractionMappingTab> createState() => _InteractionMappingTabState();
}

class _InteractionMappingTabState extends State<_InteractionMappingTab>
    with AutomaticKeepAliveClientMixin {
  final InteractionConfigService _configService = InteractionConfigService();
  final Live2DNativeBridge _bridge = Live2DNativeBridge();
  
  GestureConfig _config = GestureConfig.defaults();
  List<String> _motionGroups = [];
  Map<String, int> _motionCounts = {};
  List<String> _expressions = [];
  bool _isLoading = true;
  bool _hasChanges = false;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    
    _config = await _configService.loadGestureConfig();
    _motionGroups = await _bridge.getMotionGroups();
    for (final group in _motionGroups) {
      _motionCounts[group] = await _bridge.getMotionCount(group);
    }
    _expressions = await _bridge.getExpressions();
    
    if (mounted) {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _saveConfig() async {
    await _configService.saveGestureConfig(_config);
    setState(() => _hasChanges = false);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('설정이 저장되었습니다')),
      );
    }
  }

  void _updateConfig(GestureConfig newConfig) {
    setState(() {
      _config = newConfig;
      _hasChanges = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final theme = Theme.of(context);

    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    return Column(
      children: [
        if (_hasChanges)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            color: theme.colorScheme.primaryContainer,
            child: Row(
              children: [
                Icon(Icons.info_outline, size: 18,
                    color: theme.colorScheme.onPrimaryContainer),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '변경사항이 있습니다',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onPrimaryContainer,
                    ),
                  ),
                ),
                FilledButton.tonal(
                  onPressed: _saveConfig,
                  child: const Text('저장'),
                ),
              ],
            ),
          ),
        
        Expanded(
          child: ListView(
            padding: const EdgeInsets.only(bottom: 32),
            children: [
              _buildSectionHeader(theme, '제스처 활성화', '인식할 제스처를 선택하세요'),

              _buildGestureToggle(
                theme: theme,
                icon: Icons.touch_app,
                title: '탭',
                subtitle: '화면을 한 번 터치',
                value: _config.enableTapReaction,
                onChanged: (v) =>
                    _updateConfig(_config.copyWith(enableTapReaction: v)),
              ),
              _buildGestureToggle(
                theme: theme,
                icon: Icons.ads_click,
                title: '더블 탭',
                subtitle: '화면을 빠르게 두 번 터치',
                value: _config.enableDoubleTapReaction,
                onChanged: (v) =>
                    _updateConfig(_config.copyWith(enableDoubleTapReaction: v)),
              ),
              _buildGestureToggle(
                theme: theme,
                icon: Icons.pan_tool,
                title: '롱프레스',
                subtitle: '화면을 길게 누름',
                value: _config.enableLongPressReaction,
                onChanged: (v) =>
                    _updateConfig(_config.copyWith(enableLongPressReaction: v)),
              ),

              const Divider(indent: 16, endIndent: 16),

              _buildSectionHeader(theme, '제스처 동작 매핑',
                  '각 제스처에 수행할 동작을 설정하세요'),
              
              _buildMappingTile(
                theme: theme,
                gesture: InteractionType.tap,
                name: '탭',
                icon: Icons.touch_app,
                enabled: _config.enableTapReaction,
              ),
              _buildMappingTile(
                theme: theme,
                gesture: InteractionType.doubleTap,
                name: '더블 탭',
                icon: Icons.ads_click,
                enabled: _config.enableDoubleTapReaction,
              ),
              _buildMappingTile(
                theme: theme,
                gesture: InteractionType.longPress,
                name: '롱프레스',
                icon: Icons.pan_tool,
                enabled: _config.enableLongPressReaction,
              ),
              _buildMappingTile(
                theme: theme,
                gesture: InteractionType.swipeLeft,
                name: '왼쪽 스와이프',
                icon: Icons.swipe_left,
                enabled: true,
              ),
              _buildMappingTile(
                theme: theme,
                gesture: InteractionType.swipeRight,
                name: '오른쪽 스와이프',
                icon: Icons.swipe_right,
                enabled: true,
              ),
              _buildMappingTile(
                theme: theme,
                gesture: InteractionType.headPat,
                name: '머리 쓰다듬기',
                icon: Icons.pets,
                enabled: true,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSectionHeader(ThemeData theme, String title, String subtitle) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: theme.textTheme.titleMedium?.copyWith(
              color: theme.colorScheme.primary,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGestureToggle({
    required ThemeData theme,
    required IconData icon,
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return SwitchListTile(
      secondary: Icon(icon, color: value ? theme.colorScheme.primary : null),
      title: Text(title),
      subtitle: Text(subtitle),
      value: value,
      onChanged: onChanged,
    );
  }

  Widget _buildMappingTile({
    required ThemeData theme,
    required InteractionType gesture,
    required String name,
    required IconData icon,
    required bool enabled,
  }) {
    final mapping = _config.getMappingFor(gesture);
    final description = _getMappingDescription(mapping);

    return ListTile(
      leading: Icon(icon,
          color: enabled ? theme.colorScheme.primary : theme.disabledColor),
      title: Text(name),
      subtitle: Text(
        description,
        style: TextStyle(
          color: enabled ? null : theme.disabledColor,
        ),
      ),
      trailing: const Icon(Icons.chevron_right),
      enabled: enabled,
      onTap: enabled ? () => _showMappingDialog(gesture, name) : null,
    );
  }

  String _getMappingDescription(GestureActionMapping? mapping) {
    if (mapping == null) return '동작 없음';
    switch (mapping.actionType) {
      case GestureActionType.playMotion:
        return '모션: ${mapping.motionGroup ?? "?"}[${mapping.motionIndex ?? 0}]';
      case GestureActionType.setExpression:
        return '표정: ${mapping.expressionId ?? "?"}';
      case GestureActionType.randomExpression:
        return '랜덤 표정';
      case GestureActionType.sendSignal:
        return '신호: ${mapping.signalName ?? "?"}';
      case GestureActionType.none:
        return '동작 없음';
    }
  }

  void _showMappingDialog(InteractionType gesture, String gestureName) {
    final currentMapping = _config.getMappingFor(gesture);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => _InteractionMappingSheet(
        gesture: gesture,
        gestureName: gestureName,
        currentMapping: currentMapping,
        motionGroups: _motionGroups,
        motionCounts: _motionCounts,
        expressions: _expressions,
        onSave: (mapping) {
          final newMappings = List<GestureActionMapping>.from(
              _config.actionMappings);
          newMappings.removeWhere((m) => m.gesture == gesture);
          if (mapping != null &&
              mapping.actionType != GestureActionType.none) {
            newMappings.add(mapping);
          }
          _updateConfig(_config.copyWith(actionMappings: newMappings));
        },
      ),
    );
  }
}

// ============================================================================
// ============================================================================

class _InteractionMappingSheet extends StatefulWidget {
  final InteractionType gesture;
  final String gestureName;
  final GestureActionMapping? currentMapping;
  final List<String> motionGroups;
  final Map<String, int> motionCounts;
  final List<String> expressions;
  final ValueChanged<GestureActionMapping?> onSave;

  const _InteractionMappingSheet({
    required this.gesture,
    required this.gestureName,
    required this.currentMapping,
    required this.motionGroups,
    required this.motionCounts,
    required this.expressions,
    required this.onSave,
  });

  @override
  State<_InteractionMappingSheet> createState() =>
      _InteractionMappingSheetState();
}

class _InteractionMappingSheetState extends State<_InteractionMappingSheet> {
  late GestureActionType _selectedActionType;
  String? _selectedMotionGroup;
  int _selectedMotionIndex = 0;
  String? _selectedExpressionId;

  @override
  void initState() {
    super.initState();
    _selectedActionType =
        widget.currentMapping?.actionType ?? GestureActionType.none;
    _selectedMotionGroup = widget.currentMapping?.motionGroup ??
        (widget.motionGroups.isNotEmpty ? widget.motionGroups.first : null);
    _selectedMotionIndex = widget.currentMapping?.motionIndex ?? 0;
    _selectedExpressionId = widget.currentMapping?.expressionId ??
        (widget.expressions.isNotEmpty ? widget.expressions.first : null);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return DraggableScrollableSheet(
      initialChildSize: 0.7,
      minChildSize: 0.4,
      maxChildSize: 0.95,
      expand: false,
      builder: (context, scrollController) {
        return Container(
          decoration: BoxDecoration(
            color: theme.colorScheme.surface,
            borderRadius:
                const BorderRadius.vertical(top: Radius.circular(16)),
          ),
          child: Column(
            children: [
              Container(
                margin: const EdgeInsets.only(top: 8),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color:
                      theme.colorScheme.onSurfaceVariant.withOpacity(0.4),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),

              Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        '${widget.gestureName} 동작 설정',
                        style: theme.textTheme.titleLarge,
                      ),
                    ),
                    TextButton(
                      onPressed: () {
                        _save();
                        Navigator.pop(context);
                      },
                      child: const Text('저장'),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),

              Expanded(
                child: ListView(
                  controller: scrollController,
                  children: [
                    _buildSectionTitle(theme, '동작 유형'),

                    RadioListTile<GestureActionType>(
                      title: const Text('동작 없음'),
                      value: GestureActionType.none,
                      groupValue: _selectedActionType,
                      onChanged: (v) =>
                          setState(() => _selectedActionType = v!),
                    ),
                    RadioListTile<GestureActionType>(
                      title: const Text('모션 재생'),
                      subtitle: const Text('지정한 모션을 재생합니다'),
                      value: GestureActionType.playMotion,
                      groupValue: _selectedActionType,
                      onChanged: (v) =>
                          setState(() => _selectedActionType = v!),
                    ),
                    RadioListTile<GestureActionType>(
                      title: const Text('표정 설정'),
                      subtitle: const Text('지정한 표정으로 변경합니다'),
                      value: GestureActionType.setExpression,
                      groupValue: _selectedActionType,
                      onChanged: (v) =>
                          setState(() => _selectedActionType = v!),
                    ),
                    RadioListTile<GestureActionType>(
                      title: const Text('랜덤 표정'),
                      subtitle: const Text('무작위 표정으로 변경합니다'),
                      value: GestureActionType.randomExpression,
                      groupValue: _selectedActionType,
                      onChanged: (v) =>
                          setState(() => _selectedActionType = v!),
                    ),

                    if (_selectedActionType == GestureActionType.playMotion) ...[
                      const Divider(),
                      _buildSectionTitle(theme, '모션 선택'),
                      if (widget.motionGroups.isEmpty)
                        const Padding(
                          padding: EdgeInsets.all(16),
                          child: Text('사용 가능한 모션 그룹이 없습니다.\n모델을 먼저 로드해주세요.'),
                        )
                      else ...[
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          child: DropdownButtonFormField<String>(
                            decoration: const InputDecoration(
                              labelText: '모션 그룹',
                              border: OutlineInputBorder(),
                            ),
                            value: _selectedMotionGroup,
                            items: widget.motionGroups
                                .map((g) => DropdownMenuItem(
                                      value: g,
                                      child: Text(
                                        '$g (${widget.motionCounts[g] ?? 0}개)',
                                      ),
                                    ))
                                .toList(),
                            onChanged: (v) {
                              setState(() {
                                _selectedMotionGroup = v;
                                _selectedMotionIndex = 0;
                              });
                            },
                          ),
                        ),
                        if (_selectedMotionGroup != null) ...[
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  '모션 인덱스: $_selectedMotionIndex',
                                  style: theme.textTheme.bodyMedium,
                                ),
                                Slider(
                                  value: _selectedMotionIndex.toDouble(),
                                  min: 0,
                                  max: ((widget.motionCounts[_selectedMotionGroup] ?? 1) - 1)
                                      .toDouble()
                                      .clamp(0, double.infinity),
                                  divisions: ((widget.motionCounts[_selectedMotionGroup] ?? 1) - 1)
                                      .clamp(1, 100),
                                  label: '$_selectedMotionIndex',
                                  onChanged: (v) {
                                    setState(() =>
                                        _selectedMotionIndex = v.toInt());
                                  },
                                ),
                              ],
                            ),
                          ),
                        ],
                      ],
                    ],

                    if (_selectedActionType ==
                        GestureActionType.setExpression) ...[
                      const Divider(),
                      _buildSectionTitle(theme, '표정 선택'),
                      if (widget.expressions.isEmpty)
                        const Padding(
                          padding: EdgeInsets.all(16),
                          child: Text('사용 가능한 표정이 없습니다.\n모델을 먼저 로드해주세요.'),
                        )
                      else
                        ...widget.expressions.map((expr) =>
                            RadioListTile<String>(
                              title: Text(expr),
                              value: expr,
                              groupValue: _selectedExpressionId,
                              onChanged: (v) =>
                                  setState(() => _selectedExpressionId = v),
                            )),
                    ],

                    const SizedBox(height: 32),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildSectionTitle(ThemeData theme, String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      child: Text(
        title,
        style: theme.textTheme.titleSmall?.copyWith(
          color: theme.colorScheme.primary,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  void _save() {
    GestureActionMapping? mapping;

    switch (_selectedActionType) {
      case GestureActionType.playMotion:
        if (_selectedMotionGroup != null) {
          mapping = GestureActionMapping.motion(
            gesture: widget.gesture,
            group: _selectedMotionGroup!,
            index: _selectedMotionIndex,
          );
        }
        break;
      case GestureActionType.setExpression:
        if (_selectedExpressionId != null) {
          mapping = GestureActionMapping.expression(
            gesture: widget.gesture,
            expressionId: _selectedExpressionId!,
          );
        }
        break;
      case GestureActionType.randomExpression:
        mapping = GestureActionMapping(
          gesture: widget.gesture,
          actionType: GestureActionType.randomExpression,
        );
        break;
      case GestureActionType.sendSignal:
      case GestureActionType.none:
        mapping = null;
        break;
    }

    widget.onSave(mapping);
  }
}

// ============================================================================
// ============================================================================

class _AutoBehaviorTab extends StatefulWidget {
  const _AutoBehaviorTab();

  @override
  State<_AutoBehaviorTab> createState() => _AutoBehaviorTabState();
}

class _AutoBehaviorTabState extends State<_AutoBehaviorTab>
    with AutomaticKeepAliveClientMixin {
  final Live2DNativeBridge _bridge = Live2DNativeBridge();
  final InteractionConfigService _configService = InteractionConfigService();
  
  AutoBehaviorSettings _settings = const AutoBehaviorSettings();
  bool _isLoading = true;
  bool _hasChanges = false;
  bool _autoMotionEnabled = true;
  
  List<Map<String, dynamic>> _accessories = [];

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    setState(() => _isLoading = true);
    _settings = await _configService.loadAutoBehaviorSettings();
    _accessories = await _bridge.getAccessories();
    if (mounted) {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _saveSettings() async {
    await _configService.saveAutoBehaviorSettings(_settings);

    await _bridge.setEyeBlink(_settings.eyeBlinkEnabled);
    await _bridge.setBreathing(_settings.breathingEnabled);
    await _bridge.setLookAt(_settings.lookAtEnabled);

    setState(() => _hasChanges = false);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('설정이 저장되었습니다')),
      );
    }
  }

  void _updateSettings(AutoBehaviorSettings newSettings) {
    setState(() {
      _settings = newSettings;
      _hasChanges = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final theme = Theme.of(context);

    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    return Column(
      children: [
        if (_hasChanges)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            color: theme.colorScheme.primaryContainer,
            child: Row(
              children: [
                Icon(Icons.info_outline, size: 18,
                    color: theme.colorScheme.onPrimaryContainer),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '변경사항이 있습니다',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onPrimaryContainer,
                    ),
                  ),
                ),
                FilledButton.tonal(
                  onPressed: _saveSettings,
                  child: const Text('저장'),
                ),
              ],
            ),
          ),
        
        Expanded(
          child: ListView(
            padding: const EdgeInsets.only(bottom: 32),
            children: [
              _buildSectionHeader(theme, Icons.visibility, '눈 깜빡임'),
              SwitchListTile(
                secondary: const Icon(Icons.remove_red_eye),
                title: const Text('자동 눈 깜빡임'),
                subtitle: const Text('캐릭터가 자연스럽게 눈을 깜빡입니다'),
                value: _settings.eyeBlinkEnabled,
                onChanged: (v) =>
                    _updateSettings(_settings.copyWith(eyeBlinkEnabled: v)),
              ),
              if (_settings.eyeBlinkEnabled)
                _buildSliderSetting(
                  theme: theme,
                  label: '깜빡임 간격',
                  value: _settings.eyeBlinkInterval,
                  min: 1.0,
                  max: 10.0,
                  divisions: 18,
                  displayValue: '${_settings.eyeBlinkInterval.toStringAsFixed(1)}초',
                  onChanged: (v) =>
                      _updateSettings(_settings.copyWith(eyeBlinkInterval: v)),
                ),

              const Divider(indent: 16, endIndent: 16),

              _buildSectionHeader(theme, Icons.air, '호흡'),
              SwitchListTile(
                secondary: const Icon(Icons.air),
                title: const Text('자동 호흡'),
                subtitle: const Text('캐릭터가 자연스럽게 숨을 쉽니다'),
                value: _settings.breathingEnabled,
                onChanged: (v) =>
                    _updateSettings(_settings.copyWith(breathingEnabled: v)),
              ),
              if (_settings.breathingEnabled)
                _buildSliderSetting(
                  theme: theme,
                  label: '호흡 속도',
                  value: _settings.breathingSpeed,
                  min: 0.5,
                  max: 2.0,
                  divisions: 15,
                  displayValue:
                      '${(_settings.breathingSpeed * 100).toInt()}%',
                  onChanged: (v) =>
                      _updateSettings(_settings.copyWith(breathingSpeed: v)),
                ),

              const Divider(indent: 16, endIndent: 16),

              _buildSectionHeader(theme, Icons.track_changes, '시선 추적'),
              SwitchListTile(
                secondary: const Icon(Icons.remove_red_eye_outlined),
                title: const Text('시선 추적'),
                subtitle: const Text('터치 위치를 따라 시선이 움직입니다'),
                value: _settings.lookAtEnabled,
                onChanged: (v) =>
                    _updateSettings(_settings.copyWith(lookAtEnabled: v)),
              ),
              if (_settings.lookAtEnabled)
                _buildSliderSetting(
                  theme: theme,
                  label: '민감도',
                  value: _settings.lookAtSensitivity,
                  min: 0.1,
                  max: 1.0,
                  divisions: 9,
                  displayValue:
                      '${(_settings.lookAtSensitivity * 100).toInt()}%',
                  onChanged: (v) => _updateSettings(
                      _settings.copyWith(lookAtSensitivity: v)),
                ),

              const Divider(indent: 16, endIndent: 16),

              _buildSectionHeader(theme, Icons.animation, '자동 모션'),
              SwitchListTile(
                secondary: const Icon(Icons.play_circle_outline),
                title: const Text('자동 모션 (Idle)'),
                subtitle: const Text('대기 중 자동으로 아이들 모션을 재생합니다'),
                value: _autoMotionEnabled,
                onChanged: (v) async {
                  await _bridge.setAutoMotion(v);
                  setState(() => _autoMotionEnabled = v);
                },
              ),

              if (_accessories.isNotEmpty) ...[
                const Divider(indent: 16, endIndent: 16),
                _buildSectionHeader(theme, Icons.checkroom, '액세서리'),
                ..._accessories.map((acc) {
                  final id = acc['id'] as String? ?? '';
                  final name = acc['name'] as String? ?? id;
                  final enabled = acc['enabled'] as bool? ?? false;
                  return SwitchListTile(
                    secondary: const Icon(Icons.auto_awesome),
                    title: Text(name),
                    value: enabled,
                    onChanged: (v) async {
                      await _bridge.setAccessory(id, v);
                      _accessories = await _bridge.getAccessories();
                      if (mounted) setState(() {});
                    },
                  );
                }),
              ],

              const SizedBox(height: 16),

              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: OutlinedButton.icon(
                  onPressed: () {
                    _updateSettings(const AutoBehaviorSettings());
                  },
                  icon: const Icon(Icons.refresh),
                  label: const Text('기본값으로 초기화'),
                ),
              ),

              const SizedBox(height: 16),

              Card(
                margin: const EdgeInsets.symmetric(horizontal: 16),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.info_outline,
                              size: 20, color: theme.colorScheme.primary),
                          const SizedBox(width: 8),
                          Text('안내',
                              style: theme.textTheme.titleSmall),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '• 자동 동작은 모델이 지원하는 경우에만 작동합니다.\n'
                        '• 시선 추적은 화면 터치 시 활성화됩니다.\n'
                        '• 배터리 소모를 줄이려면 불필요한 기능을 끄세요.',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSectionHeader(ThemeData theme, IconData icon, String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Row(
        children: [
          Icon(icon, size: 20, color: theme.colorScheme.primary),
          const SizedBox(width: 8),
          Text(
            title,
            style: theme.textTheme.titleMedium?.copyWith(
              color: theme.colorScheme.primary,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSliderSetting({
    required ThemeData theme,
    required String label,
    required double value,
    required double min,
    required double max,
    required int divisions,
    required String displayValue,
    required ValueChanged<double> onChanged,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '$label: $displayValue',
            style: theme.textTheme.bodyMedium,
          ),
          Slider(
            value: value,
            min: min,
            max: max,
            divisions: divisions,
            label: displayValue,
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }
}
