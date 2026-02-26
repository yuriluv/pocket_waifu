// ============================================================================
// ============================================================================
// ============================================================================

import 'package:flutter/material.dart';

class FolderPickerTile extends StatelessWidget {
  final String? currentPath;
  final String? displayName;
  final bool isLoading;
  final VoidCallback onPickFolder;
  final VoidCallback? onClearFolder;
  final VoidCallback? onValidateFolder;

  const FolderPickerTile({
    super.key,
    this.currentPath,
    this.displayName,
    this.isLoading = false,
    required this.onPickFolder,
    this.onClearFolder,
    this.onValidateFolder,
  });

  bool get hasFolder => currentPath != null;

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
            Row(
              children: [
                Icon(
                  Icons.folder,
                  color: hasFolder
                      ? theme.colorScheme.primary
                      : theme.colorScheme.onSurfaceVariant,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '데이터 폴더',
                        style: theme.textTheme.titleMedium,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        hasFolder
                            ? displayName ?? currentPath!
                            : '폴더를 선택해주세요',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: hasFolder
                              ? theme.colorScheme.onSurfaceVariant
                              : theme.colorScheme.error,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ],
            ),
            
            if (hasFolder && currentPath != null) ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.location_on,
                      size: 16,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        currentPath!,
                        style: theme.textTheme.bodySmall?.copyWith(
                          fontFamily: 'monospace',
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
            ],
            
            const SizedBox(height: 12),
            
            Row(
              children: [
                Expanded(
                  child: FilledButton.icon(
                    onPressed: isLoading ? null : onPickFolder,
                    icon: isLoading
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                            ),
                          )
                        : const Icon(Icons.folder_open),
                    label: Text(hasFolder ? '폴더 변경' : '폴더 선택'),
                  ),
                ),
              ],
            ),
            if (hasFolder) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  if (onValidateFolder != null)
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: isLoading ? null : onValidateFolder,
                        icon: const Icon(Icons.check_circle_outline),
                        label: const Text('폴더 검증'),
                      ),
                    ),
                  if (onValidateFolder != null && onClearFolder != null)
                    const SizedBox(width: 8),
                  if (onClearFolder != null)
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: isLoading ? null : onClearFolder,
                        icon: const Icon(Icons.clear),
                        label: const Text('초기화'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: theme.colorScheme.error,
                        ),
                      ),
                    ),
                ],
              ),
            ],
            
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
                    'Live2D 모델이 있는 폴더를 선택하세요.\n폴더 내 Live2D/ 서브폴더 또는 직접 모델 폴더를 스캔합니다.',
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
