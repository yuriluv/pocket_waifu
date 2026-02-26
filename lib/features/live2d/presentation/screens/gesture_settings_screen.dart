// ============================================================================
// ============================================================================
// ============================================================================

import 'package:flutter/material.dart';
import '../../domain/entities/gesture_config.dart';
import '../../domain/entities/interaction_event.dart';
import '../../data/services/interaction_config_service.dart';

class GestureSettingsScreen extends StatefulWidget {
  const GestureSettingsScreen({super.key});

  @override
  State<GestureSettingsScreen> createState() => _GestureSettingsScreenState();
}

class _GestureSettingsScreenState extends State<GestureSettingsScreen> {
  final InteractionConfigService _configService = InteractionConfigService();
  GestureConfig _config = GestureConfig.defaults();
  bool _isLoading = true;
  bool _hasChanges = false;

  @override
  void initState() {
    super.initState();
    _loadConfig();
  }

  Future<void> _loadConfig() async {
    setState(() => _isLoading = true);
    _config = await _configService.loadGestureConfig();
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
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('제스처 설정'),
        actions: [
          if (_hasChanges)
            IconButton(
              icon: const Icon(Icons.save),
              tooltip: '저장',
              onPressed: _saveConfig,
            ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              children: [
                _SectionHeader(
                  title: '제스처 활성화',
                  subtitle: '인식할 제스처를 선택하세요',
                ),
                
                SwitchListTile(
                  title: const Text('탭'),
                  subtitle: const Text('화면을 한 번 터치'),
                  secondary: const Icon(Icons.touch_app),
                  value: _config.enableTapReaction,
                  onChanged: (value) {
                    _updateConfig(_config.copyWith(enableTapReaction: value));
                  },
                ),
                
                SwitchListTile(
                  title: const Text('더블탭'),
                  subtitle: const Text('화면을 빠르게 두 번 터치'),
                  secondary: const Icon(Icons.ads_click),
                  value: _config.enableDoubleTapReaction,
                  onChanged: (value) {
                    _updateConfig(_config.copyWith(enableDoubleTapReaction: value));
                  },
                ),
                
                SwitchListTile(
                  title: const Text('롱프레스'),
                  subtitle: const Text('화면을 길게 누름'),
                  secondary: const Icon(Icons.pan_tool),
                  value: _config.enableLongPressReaction,
                  onChanged: (value) {
                    _updateConfig(_config.copyWith(enableLongPressReaction: value));
                  },
                ),
                
                const Divider(),
                
                _SectionHeader(
                  title: '제스처 동작 매핑',
                  subtitle: '각 제스처에 동작을 연결하세요',
                ),
                
                _GestureMappingTile(
                  gesture: InteractionType.tap,
                  gestureName: '탭',
                  icon: Icons.touch_app,
                  mapping: _config.getMappingFor(InteractionType.tap),
                  enabled: _config.enableTapReaction,
                  onMappingChanged: (mapping) => _updateMapping(InteractionType.tap, mapping),
                ),
                
                _GestureMappingTile(
                  gesture: InteractionType.doubleTap,
                  gestureName: '더블탭',
                  icon: Icons.ads_click,
                  mapping: _config.getMappingFor(InteractionType.doubleTap),
                  enabled: _config.enableDoubleTapReaction,
                  onMappingChanged: (mapping) => _updateMapping(InteractionType.doubleTap, mapping),
                ),
                
                _GestureMappingTile(
                  gesture: InteractionType.longPress,
                  gestureName: '롱프레스',
                  icon: Icons.pan_tool,
                  mapping: _config.getMappingFor(InteractionType.longPress),
                  enabled: _config.enableLongPressReaction,
                  onMappingChanged: (mapping) => _updateMapping(InteractionType.longPress, mapping),
                ),
                
                _GestureMappingTile(
                  gesture: InteractionType.swipeLeft,
                  gestureName: '왼쪽 스와이프',
                  icon: Icons.swipe_left,
                  mapping: _config.getMappingFor(InteractionType.swipeLeft),
                  enabled: true,
                  onMappingChanged: (mapping) => _updateMapping(InteractionType.swipeLeft, mapping),
                ),
                
                _GestureMappingTile(
                  gesture: InteractionType.swipeRight,
                  gestureName: '오른쪽 스와이프',
                  icon: Icons.swipe_right,
                  mapping: _config.getMappingFor(InteractionType.swipeRight),
                  enabled: true,
                  onMappingChanged: (mapping) => _updateMapping(InteractionType.swipeRight, mapping),
                ),
                
                _GestureMappingTile(
                  gesture: InteractionType.headPat,
                  gestureName: '머리 쓰다듬기',
                  icon: Icons.pets,
                  mapping: _config.getMappingFor(InteractionType.headPat),
                  enabled: true,
                  onMappingChanged: (mapping) => _updateMapping(InteractionType.headPat, mapping),
                ),
                
                const SizedBox(height: 16),
                
                Card(
                  margin: const EdgeInsets.all(16),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.info_outline, 
                              color: theme.colorScheme.primary),
                            const SizedBox(width: 8),
                            Text('안내', 
                              style: theme.textTheme.titleMedium),
                          ],
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          '• 오버레이가 활성화된 상태에서 제스처를 테스트할 수 있습니다.\n'
                          '• 모션 그룹과 표정은 로드된 모델에 따라 다릅니다.\n'
                          '• 설정 변경 후 저장 버튼을 눌러주세요.',
                        ),
                      ],
                    ),
                  ),
                ),
                
                const SizedBox(height: 32),
              ],
            ),
    );
  }

  void _updateMapping(InteractionType gesture, GestureActionMapping? mapping) {
    final List<GestureActionMapping> newMappings = List.from(_config.actionMappings);
    
    newMappings.removeWhere((m) => m.gesture == gesture);
    
    if (mapping != null && mapping.actionType != GestureActionType.none) {
      newMappings.add(mapping);
    }
    
    _updateConfig(_config.copyWith(actionMappings: newMappings));
  }
}

// ============================================================================
// ============================================================================

class _SectionHeader extends StatelessWidget {
  final String title;
  final String? subtitle;

  const _SectionHeader({
    required this.title,
    this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
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
          if (subtitle != null) ...[
            const SizedBox(height: 4),
            Text(
              subtitle!,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ============================================================================
// ============================================================================

class _GestureMappingTile extends StatelessWidget {
  final InteractionType gesture;
  final String gestureName;
  final IconData icon;
  final GestureActionMapping? mapping;
  final bool enabled;
  final ValueChanged<GestureActionMapping?> onMappingChanged;

  const _GestureMappingTile({
    required this.gesture,
    required this.gestureName,
    required this.icon,
    required this.mapping,
    required this.enabled,
    required this.onMappingChanged,
  });

  String _getActionDescription() {
    if (mapping == null) return '동작 없음';
    
    switch (mapping!.actionType) {
      case GestureActionType.playMotion:
        return '모션: ${mapping!.motionGroup}[${mapping!.motionIndex}]';
      case GestureActionType.setExpression:
        return '표정: ${mapping!.expressionId}';
      case GestureActionType.randomExpression:
        return '랜덤 표정';
      case GestureActionType.sendSignal:
        return '신호: ${mapping!.signalName}';
      case GestureActionType.none:
        return '동작 없음';
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return ListTile(
      leading: Icon(icon, 
        color: enabled ? theme.colorScheme.primary : theme.disabledColor),
      title: Text(gestureName),
      subtitle: Text(
        _getActionDescription(),
        style: TextStyle(
          color: enabled ? null : theme.disabledColor,
        ),
      ),
      trailing: const Icon(Icons.chevron_right),
      enabled: enabled,
      onTap: enabled ? () => _showMappingDialog(context) : null,
    );
  }

  void _showMappingDialog(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => _GestureMappingBottomSheet(
        gesture: gesture,
        gestureName: gestureName,
        currentMapping: mapping,
        onSave: onMappingChanged,
      ),
    );
  }
}

// ============================================================================
// ============================================================================

class _GestureMappingBottomSheet extends StatefulWidget {
  final InteractionType gesture;
  final String gestureName;
  final GestureActionMapping? currentMapping;
  final ValueChanged<GestureActionMapping?> onSave;

  const _GestureMappingBottomSheet({
    required this.gesture,
    required this.gestureName,
    required this.currentMapping,
    required this.onSave,
  });

  @override
  State<_GestureMappingBottomSheet> createState() => _GestureMappingBottomSheetState();
}

class _GestureMappingBottomSheetState extends State<_GestureMappingBottomSheet> {
  late GestureActionType _selectedActionType;
  String _motionGroup = 'tap';
  int _motionIndex = 0;
  String _expressionId = '';

  @override
  void initState() {
    super.initState();
    _selectedActionType = widget.currentMapping?.actionType ?? GestureActionType.none;
    _motionGroup = widget.currentMapping?.motionGroup ?? 'tap';
    _motionIndex = widget.currentMapping?.motionIndex ?? 0;
    _expressionId = widget.currentMapping?.expressionId ?? '';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return DraggableScrollableSheet(
      initialChildSize: 0.6,
      minChildSize: 0.4,
      maxChildSize: 0.9,
      expand: false,
      builder: (context, scrollController) {
        return Container(
          decoration: BoxDecoration(
            color: theme.colorScheme.surface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
          ),
          child: Column(
            children: [
              Container(
                margin: const EdgeInsets.only(top: 8),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: theme.colorScheme.onSurfaceVariant.withOpacity(0.4),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              
              Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Text(
                      '${widget.gestureName} 동작 설정',
                      style: theme.textTheme.titleLarge,
                    ),
                    const Spacer(),
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
              
              const Divider(),
              
              Expanded(
                child: ListView(
                  controller: scrollController,
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: Text('동작 유형', style: theme.textTheme.titleSmall),
                    ),
                    
                    RadioListTile<GestureActionType>(
                      title: const Text('동작 없음'),
                      value: GestureActionType.none,
                      groupValue: _selectedActionType,
                      onChanged: (v) => setState(() => _selectedActionType = v!),
                    ),
                    
                    RadioListTile<GestureActionType>(
                      title: const Text('모션 재생'),
                      subtitle: const Text('지정한 모션을 재생합니다'),
                      value: GestureActionType.playMotion,
                      groupValue: _selectedActionType,
                      onChanged: (v) => setState(() => _selectedActionType = v!),
                    ),
                    
                    RadioListTile<GestureActionType>(
                      title: const Text('표정 설정'),
                      subtitle: const Text('지정한 표정으로 변경합니다'),
                      value: GestureActionType.setExpression,
                      groupValue: _selectedActionType,
                      onChanged: (v) => setState(() => _selectedActionType = v!),
                    ),
                    
                    RadioListTile<GestureActionType>(
                      title: const Text('랜덤 표정'),
                      subtitle: const Text('무작위 표정으로 변경합니다'),
                      value: GestureActionType.randomExpression,
                      groupValue: _selectedActionType,
                      onChanged: (v) => setState(() => _selectedActionType = v!),
                    ),
                    
                    if (_selectedActionType == GestureActionType.playMotion) ...[
                      const Divider(),
                      Padding(
                        padding: const EdgeInsets.all(16),
                        child: Text('모션 설정', style: theme.textTheme.titleSmall),
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: TextField(
                          decoration: const InputDecoration(
                            labelText: '모션 그룹',
                            hintText: 'tap, idle, flick 등',
                            border: OutlineInputBorder(),
                          ),
                          controller: TextEditingController(text: _motionGroup),
                          onChanged: (v) => _motionGroup = v,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: TextField(
                          decoration: const InputDecoration(
                            labelText: '모션 인덱스',
                            hintText: '0, 1, 2 ...',
                            border: OutlineInputBorder(),
                          ),
                          keyboardType: TextInputType.number,
                          controller: TextEditingController(text: _motionIndex.toString()),
                          onChanged: (v) => _motionIndex = int.tryParse(v) ?? 0,
                        ),
                      ),
                    ],
                    
                    if (_selectedActionType == GestureActionType.setExpression) ...[
                      const Divider(),
                      Padding(
                        padding: const EdgeInsets.all(16),
                        child: Text('표정 설정', style: theme.textTheme.titleSmall),
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: TextField(
                          decoration: const InputDecoration(
                            labelText: '표정 ID',
                            hintText: 'happy, sad, angry 등',
                            border: OutlineInputBorder(),
                          ),
                          controller: TextEditingController(text: _expressionId),
                          onChanged: (v) => _expressionId = v,
                        ),
                      ),
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

  void _save() {
    GestureActionMapping? mapping;
    
    switch (_selectedActionType) {
      case GestureActionType.playMotion:
        mapping = GestureActionMapping.motion(
          gesture: widget.gesture,
          group: _motionGroup,
          index: _motionIndex,
        );
        break;
      case GestureActionType.setExpression:
        mapping = GestureActionMapping.expression(
          gesture: widget.gesture,
          expressionId: _expressionId,
        );
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
