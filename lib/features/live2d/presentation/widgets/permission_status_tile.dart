// ============================================================================
// ============================================================================
// ============================================================================

import 'package:flutter/material.dart';

class PermissionStatusTile extends StatelessWidget {
  final bool hasOverlayPermission;
  final bool hasStoragePermission;
  final VoidCallback onRequestOverlayPermission;
  final VoidCallback onRequestStoragePermission;
  final bool isLoading;

  const PermissionStatusTile({
    super.key,
    required this.hasOverlayPermission,
    required this.hasStoragePermission,
    required this.onRequestOverlayPermission,
    required this.onRequestStoragePermission,
    this.isLoading = false,
  });

  bool get allPermissionsGranted =>
      hasOverlayPermission && hasStoragePermission;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      color: allPermissionsGranted
          ? theme.colorScheme.primaryContainer.withOpacity(0.3)
          : theme.colorScheme.errorContainer.withOpacity(0.3),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  allPermissionsGranted ? Icons.verified_user : Icons.security,
                  color: allPermissionsGranted
                      ? theme.colorScheme.primary
                      : theme.colorScheme.error,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '권한 상태',
                        style: theme.textTheme.titleMedium,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        allPermissionsGranted
                            ? '모든 권한이 허용되었습니다'
                            : '필요한 권한을 허용해주세요',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: allPermissionsGranted
                              ? theme.colorScheme.primary
                              : theme.colorScheme.error,
                        ),
                      ),
                    ],
                  ),
                ),
                if (allPermissionsGranted)
                  const Icon(Icons.check_circle, color: Colors.green),
              ],
            ),

            const SizedBox(height: 16),

            _PermissionRow(
              icon: Icons.picture_in_picture,
              title: '오버레이 권한',
              description: '다른 앱 위에 표시',
              isGranted: hasOverlayPermission,
              onRequest: hasOverlayPermission ? null : onRequestOverlayPermission,
              isLoading: isLoading,
            ),

            const SizedBox(height: 12),

            _PermissionRow(
              icon: Icons.folder,
              title: '저장소 권한',
              description: 'Live2D 모델 파일 접근',
              isGranted: hasStoragePermission,
              onRequest: hasStoragePermission ? null : onRequestStoragePermission,
              isLoading: isLoading,
            ),

            if (!allPermissionsGranted) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      Icons.info_outline,
                      size: 16,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        '권한 요청 버튼을 누르면 시스템 설정으로 이동합니다. '
                        '권한을 허용한 후 앱으로 돌아와주세요.',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
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
    );
  }
}

class _PermissionRow extends StatelessWidget {
  final IconData icon;
  final String title;
  final String description;
  final bool isGranted;
  final VoidCallback? onRequest;
  final bool isLoading;

  const _PermissionRow({
    required this.icon,
    required this.title,
    required this.description,
    required this.isGranted,
    this.onRequest,
    this.isLoading = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isGranted
              ? Colors.green.withOpacity(0.5)
              : theme.colorScheme.error.withOpacity(0.5),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: isGranted
                  ? Colors.green.withOpacity(0.2)
                  : theme.colorScheme.errorContainer,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              icon,
              color: isGranted ? Colors.green : theme.colorScheme.error,
            ),
          ),

          const SizedBox(width: 12),

          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      title,
                      style: theme.textTheme.titleSmall,
                    ),
                    const SizedBox(width: 8),
                    if (isGranted)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.green.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          '허용됨',
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: Colors.green,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      )
                    else
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.errorContainer,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          '필요함',
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: theme.colorScheme.error,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  description,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),

          if (!isGranted)
            FilledButton.tonal(
              onPressed: isLoading ? null : onRequest,
              child: isLoading
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('허용'),
            ),
        ],
      ),
    );
  }
}
