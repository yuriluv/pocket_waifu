// ============================================================================
// 크기 슬라이더 타일 위젯 (Size Slider Tile Widget)
// ============================================================================
// Live2D 오버레이의 크기를 조절하는 슬라이더 위젯입니다.
// ============================================================================

import 'package:flutter/material.dart';

/// 크기 슬라이더 타일 위젯
class SizeSliderTile extends StatelessWidget {
  final double scale;
  final double opacity;
  final ValueChanged<double> onScaleChanged;
  final ValueChanged<double> onOpacityChanged;
  final VoidCallback onResetPosition;
  final bool enabled;

  const SizeSliderTile({
    super.key,
    required this.scale,
    required this.opacity,
    required this.onScaleChanged,
    required this.onOpacityChanged,
    required this.onResetPosition,
    this.enabled = true,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 헤더
            Row(
              children: [
                Icon(
                  Icons.tune,
                  color: enabled
                      ? theme.colorScheme.primary
                      : theme.colorScheme.onSurfaceVariant,
                ),
                const SizedBox(width: 12),
                Text(
                  '표시 설정',
                  style: theme.textTheme.titleMedium,
                ),
              ],
            ),
            
            const SizedBox(height: 16),
            
            // 크기 슬라이더
            _SliderRow(
              icon: Icons.aspect_ratio,
              label: '크기',
              value: scale,
              min: 0.5,
              max: 2.0,
              divisions: 15,
              formatValue: (v) => '${(v * 100).toInt()}%',
              onChanged: enabled ? onScaleChanged : null,
            ),
            
            const SizedBox(height: 16),
            
            // 투명도 슬라이더
            _SliderRow(
              icon: Icons.opacity,
              label: '투명도',
              value: opacity,
              min: 0.3,
              max: 1.0,
              divisions: 14,
              formatValue: (v) => '${(v * 100).toInt()}%',
              onChanged: enabled ? onOpacityChanged : null,
            ),
            
            const SizedBox(height: 16),
            
            // 위치 초기화 버튼
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: enabled ? onResetPosition : null,
                icon: const Icon(Icons.center_focus_strong),
                label: const Text('위치 초기화'),
              ),
            ),
            
            // 안내 메시지
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(
                  Icons.info_outline,
                  size: 14,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    '오버레이를 드래그하여 위치를 조절할 수 있습니다.',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// 슬라이더 행 위젯
class _SliderRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final double value;
  final double min;
  final double max;
  final int divisions;
  final String Function(double) formatValue;
  final ValueChanged<double>? onChanged;

  const _SliderRow({
    required this.icon,
    required this.label,
    required this.value,
    required this.min,
    required this.max,
    required this.divisions,
    required this.formatValue,
    this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final enabled = onChanged != null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(
              icon,
              size: 18,
              color: enabled
                  ? theme.colorScheme.onSurface
                  : theme.colorScheme.onSurfaceVariant,
            ),
            const SizedBox(width: 8),
            Text(
              label,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: enabled
                    ? theme.colorScheme.onSurface
                    : theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const Spacer(),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: theme.colorScheme.primaryContainer,
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                formatValue(value),
                style: theme.textTheme.labelMedium?.copyWith(
                  color: theme.colorScheme.onPrimaryContainer,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
        SliderTheme(
          data: SliderTheme.of(context).copyWith(
            trackHeight: 4,
            thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 8),
          ),
          child: Slider(
            value: value.clamp(min, max),
            min: min,
            max: max,
            divisions: divisions,
            onChanged: onChanged,
          ),
        ),
      ],
    );
  }
}
