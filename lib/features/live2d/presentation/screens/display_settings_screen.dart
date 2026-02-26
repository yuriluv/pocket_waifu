// ============================================================================
// ============================================================================
// ============================================================================

import 'package:flutter/material.dart';
import '../../data/services/live2d_native_bridge.dart';
import '../../data/models/live2d_settings.dart';

class DisplaySettingsScreen extends StatefulWidget {
  const DisplaySettingsScreen({super.key});

  @override
  State<DisplaySettingsScreen> createState() => _DisplaySettingsScreenState();
}

class _DisplaySettingsScreenState extends State<DisplaySettingsScreen> {
  final Live2DNativeBridge _bridge = Live2DNativeBridge();
  
  double _scale = 1.0;
  double _opacity = 1.0;
  double _positionX = 0.5;
  double _positionY = 0.5;
  bool _isLoading = true;
  bool _hasChanges = false;
  bool _isOverlayActive = false;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    setState(() => _isLoading = true);
    
    final settings = await Live2DSettings.load();
    _scale = settings.scale;
    _opacity = settings.opacity;
    _positionX = settings.positionX;
    _positionY = settings.positionY;
    _isOverlayActive = await _bridge.isOverlayVisible();
    
    if (mounted) {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _saveSettings() async {
    final settings = await Live2DSettings.load();
    final newSettings = settings.copyWith(
      scale: _scale,
      opacity: _opacity,
      positionX: _positionX,
      positionY: _positionY,
    );
    await newSettings.save();
    
    setState(() => _hasChanges = false);
    
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('설정이 저장되었습니다')),
      );
    }
  }

  Future<void> _applyScale(double value) async {
    setState(() {
      _scale = value;
      _hasChanges = true;
    });
    
    if (_isOverlayActive) {
      await _bridge.setScale(value);
    }
  }

  Future<void> _applyOpacity(double value) async {
    setState(() {
      _opacity = value;
      _hasChanges = true;
    });
    
    if (_isOverlayActive) {
      await _bridge.setCharacterOpacity(value);
    }
  }

  Future<void> _applyPosition(double x, double y) async {
    setState(() {
      _positionX = x;
      _positionY = y;
      _hasChanges = true;
    });
    
    if (_isOverlayActive) {
      await _bridge.setPosition(x, y);
    }
  }

  Future<void> _resetToDefaults() async {
    await _applyScale(1.0);
    await _applyOpacity(1.0);
    await _applyPosition(0.5, 0.5);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('디스플레이 설정'),
        actions: [
          if (_hasChanges)
            IconButton(
              icon: const Icon(Icons.save),
              tooltip: '저장',
              onPressed: _saveSettings,
            ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              children: [
                if (!_isOverlayActive)
                  Container(
                    margin: const EdgeInsets.all(16),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.secondaryContainer,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.info_outline, 
                          color: theme.colorScheme.onSecondaryContainer),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            '오버레이가 비활성화 상태입니다. 설정은 저장되지만 바로 적용되지 않습니다.',
                            style: TextStyle(
                              color: theme.colorScheme.onSecondaryContainer,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                
                _SectionHeader(
                  title: '크기',
                  icon: Icons.photo_size_select_large,
                ),
                
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            '크기: ${(_scale * 100).toInt()}%',
                            style: theme.textTheme.bodyLarge,
                          ),
                          _PresetButtons(
                            values: const [0.5, 0.75, 1.0, 1.25, 1.5],
                            labels: const ['50%', '75%', '100%', '125%', '150%'],
                            currentValue: _scale,
                            onSelected: _applyScale,
                          ),
                        ],
                      ),
                      Slider(
                        value: _scale,
                        min: 0.3,
                        max: 2.0,
                        divisions: 17,
                        label: '${(_scale * 100).toInt()}%',
                        onChanged: _applyScale,
                      ),
                      Text(
                        '작은 값: 작은 캐릭터 / 큰 값: 큰 캐릭터',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                
                const Divider(height: 32),
                
                _SectionHeader(
                  title: '캐릭터 투명도',
                  icon: Icons.opacity,
                ),
                
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            '캐릭터 투명도: ${(_opacity * 100).toInt()}%',
                            style: theme.textTheme.bodyLarge,
                          ),
                          _PresetButtons(
                            values: const [0.0, 0.25, 0.5, 0.75, 1.0],
                            labels: const ['0%', '25%', '50%', '75%', '100%'],
                            currentValue: _opacity,
                            onSelected: _applyOpacity,
                          ),
                        ],
                      ),
                      Slider(
                        value: _opacity,
                        min: 0.0,
                        max: 1.0,
                        divisions: 20,
                        label: '${(_opacity * 100).toInt()}%',
                        onChanged: _applyOpacity,
                      ),
                      Text(
                        '캐릭터 시각적 투명도 (터치스루 알파와 완전 독립)\n0%: 완전 투명 / 100%: 완전 불투명',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                
                const Divider(height: 32),
                
                _SectionHeader(
                  title: '기본 위치',
                  icon: Icons.open_with,
                ),
                
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      AspectRatio(
                        aspectRatio: 9 / 16,
                        child: Container(
                          decoration: BoxDecoration(
                            border: Border.all(
                              color: theme.colorScheme.outline,
                            ),
                            borderRadius: BorderRadius.circular(8),
                            color: theme.colorScheme.surfaceContainerHighest,
                          ),
                          child: Stack(
                            children: [
                              Positioned(
                                left: _positionX * 0.8 * MediaQuery.of(context).size.width * 0.3,
                                top: _positionY * 0.8 * MediaQuery.of(context).size.width * 0.3 * (16/9),
                                child: GestureDetector(
                                  onPanUpdate: (details) {
                                    final box = context.findRenderObject() as RenderBox?;
                                    if (box != null) {
                                      final localPosition = box.globalToLocal(details.globalPosition);
                                      final newX = (localPosition.dx / box.size.width).clamp(0.0, 1.0);
                                      final newY = (localPosition.dy / box.size.height).clamp(0.0, 1.0);
                                      _applyPosition(newX, newY);
                                    }
                                  },
                                  child: Container(
                                    width: 60,
                                    height: 80,
                                    decoration: BoxDecoration(
                                      color: theme.colorScheme.primary.withOpacity(0.3),
                                      border: Border.all(
                                        color: theme.colorScheme.primary,
                                        width: 2,
                                      ),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Icon(
                                      Icons.person,
                                      color: theme.colorScheme.primary,
                                    ),
                                  ),
                                ),
                              ),
                              
                              Positioned(
                                bottom: 8,
                                left: 0,
                                right: 0,
                                child: Center(
                                  child: Text(
                                    '드래그하여 위치 조정',
                                    style: theme.textTheme.bodySmall?.copyWith(
                                      color: theme.colorScheme.onSurfaceVariant,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      
                      const SizedBox(height: 16),
                      
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        alignment: WrapAlignment.center,
                        children: [
                          _PositionButton(
                            label: '좌상단',
                            icon: Icons.north_west,
                            onTap: () => _applyPosition(0.1, 0.1),
                            isSelected: _positionX < 0.3 && _positionY < 0.3,
                          ),
                          _PositionButton(
                            label: '우상단',
                            icon: Icons.north_east,
                            onTap: () => _applyPosition(0.9, 0.1),
                            isSelected: _positionX > 0.7 && _positionY < 0.3,
                          ),
                          _PositionButton(
                            label: '중앙',
                            icon: Icons.center_focus_strong,
                            onTap: () => _applyPosition(0.5, 0.5),
                            isSelected: _positionX > 0.3 && _positionX < 0.7 && 
                                       _positionY > 0.3 && _positionY < 0.7,
                          ),
                          _PositionButton(
                            label: '좌하단',
                            icon: Icons.south_west,
                            onTap: () => _applyPosition(0.1, 0.9),
                            isSelected: _positionX < 0.3 && _positionY > 0.7,
                          ),
                          _PositionButton(
                            label: '우하단',
                            icon: Icons.south_east,
                            onTap: () => _applyPosition(0.9, 0.9),
                            isSelected: _positionX > 0.7 && _positionY > 0.7,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                
                const Divider(height: 32),
                
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: OutlinedButton.icon(
                    onPressed: _resetToDefaults,
                    icon: const Icon(Icons.refresh),
                    label: const Text('기본값으로 초기화'),
                  ),
                ),
                
                const SizedBox(height: 32),
              ],
            ),
    );
  }
}

// ============================================================================
// ============================================================================

class _SectionHeader extends StatelessWidget {
  final String title;
  final IconData icon;

  const _SectionHeader({
    required this.title,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
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
}

// ============================================================================
// ============================================================================

class _PresetButtons extends StatelessWidget {
  final List<double> values;
  final List<String> labels;
  final double currentValue;
  final ValueChanged<double> onSelected;

  const _PresetButtons({
    required this.values,
    required this.labels,
    required this.currentValue,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 4,
      children: List.generate(values.length, (index) {
        final isSelected = (currentValue - values[index]).abs() < 0.01;
        return InkWell(
          onTap: () => onSelected(values[index]),
          borderRadius: BorderRadius.circular(4),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: isSelected 
                  ? Theme.of(context).colorScheme.primaryContainer
                  : null,
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              labels[index],
              style: TextStyle(
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.bold : null,
                color: isSelected 
                    ? Theme.of(context).colorScheme.onPrimaryContainer
                    : null,
              ),
            ),
          ),
        );
      }),
    );
  }
}

// ============================================================================
// ============================================================================

class _PositionButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback onTap;
  final bool isSelected;

  const _PositionButton({
    required this.label,
    required this.icon,
    required this.onTap,
    required this.isSelected,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return Material(
      color: isSelected 
          ? theme.colorScheme.primaryContainer
          : theme.colorScheme.surfaceContainerHighest,
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 16,
                color: isSelected 
                    ? theme.colorScheme.onPrimaryContainer
                    : theme.colorScheme.onSurfaceVariant),
              const SizedBox(width: 4),
              Text(
                label,
                style: TextStyle(
                  color: isSelected 
                      ? theme.colorScheme.onPrimaryContainer
                      : theme.colorScheme.onSurfaceVariant,
                  fontWeight: isSelected ? FontWeight.bold : null,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
