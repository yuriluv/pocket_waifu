// ============================================================================
// ============================================================================
// ============================================================================

import 'package:flutter/material.dart';

class OverlayToggleTile extends StatelessWidget {
  final bool isEnabled;
  final bool canEnable;
  final String? disabledReason;
  final ValueChanged<bool> onChanged;
  final bool isLoading;

  const OverlayToggleTile({
    super.key,
    required this.isEnabled,
    required this.canEnable,
    this.disabledReason,
    required this.onChanged,
    this.isLoading = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDisabled = !canEnable && !isEnabled;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      color: isEnabled
          ? theme.colorScheme.primaryContainer
          : theme.colorScheme.surface,
      child: InkWell(
        onTap: isLoading || isDisabled
            ? null
            : () => onChanged(!isEnabled),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              Row(
                children: [
                  Container(
                    width: 56,
                    height: 56,
                    decoration: BoxDecoration(
                      color: isEnabled
                          ? theme.colorScheme.primary
                          : theme.colorScheme.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: isLoading
                        ? Center(
                            child: SizedBox(
                              width: 24,
                              height: 24,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: isEnabled
                                    ? theme.colorScheme.onPrimary
                                    : theme.colorScheme.primary,
                              ),
                            ),
                          )
                        : Icon(
                            isEnabled ? Icons.visibility : Icons.visibility_off,
                            size: 28,
                            color: isEnabled
                                ? theme.colorScheme.onPrimary
                                : theme.colorScheme.onSurfaceVariant,
                          ),
                  ),
                  
                  const SizedBox(width: 16),
                  
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '플로팅 뷰어',
                          style: theme.textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: isEnabled
                                ? theme.colorScheme.onPrimaryContainer
                                : theme.colorScheme.onSurface,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          isEnabled
                              ? '캐릭터가 화면 위에 표시됩니다'
                              : '캐릭터를 화면 위에 표시합니다',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: isEnabled
                                ? theme.colorScheme.onPrimaryContainer
                                    .withValues(alpha: 0.8)
                                : theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                  
                  Transform.scale(
                    scale: 1.2,
                    child: Switch(
                      value: isEnabled,
                      onChanged: isLoading || isDisabled
                          ? null
                          : onChanged,
                    ),
                  ),
                ],
              ),
              
              if (isDisabled && disabledReason != null) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.errorContainer.withValues(alpha: 0.5),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.warning_amber,
                        size: 20,
                        color: theme.colorScheme.error,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          disabledReason!,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.error,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
