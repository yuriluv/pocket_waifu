// ============================================================================
// Live2D 설정 화면 (Live2D Settings Screen)
// ============================================================================
// Live2D 플로팅 뷰어의 설정을 관리하는 화면입니다.
// ============================================================================

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../controllers/live2d_controller.dart';
import '../widgets/permission_status_tile.dart';
import '../widgets/folder_picker_tile.dart';
import '../widgets/model_list_tile.dart';
import '../widgets/size_slider_tile.dart';
import '../widgets/overlay_toggle_tile.dart';
import '../widgets/log_viewer_widget.dart';

/// Live2D 설정 화면
class Live2DSettingsScreen extends StatelessWidget {
  const Live2DSettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => Live2DController()..initialize(),
      child: const _Live2DSettingsScreenContent(),
    );
  }
}

class _Live2DSettingsScreenContent extends StatefulWidget {
  const _Live2DSettingsScreenContent();

  @override
  State<_Live2DSettingsScreenContent> createState() =>
      _Live2DSettingsScreenContentState();
}

class _Live2DSettingsScreenContentState
    extends State<_Live2DSettingsScreenContent> {
  bool _hasOverlayPermission = false;
  bool _hasStoragePermission = false;
  bool _isCheckingPermissions = true;
  bool _isTogglingOverlay = false;

  @override
  void initState() {
    super.initState();
    _checkPermissions();
  }

  Future<void> _checkPermissions() async {
    setState(() => _isCheckingPermissions = true);
    
    final controller = context.read<Live2DController>();
    _hasOverlayPermission = await controller.hasOverlayPermission;
    _hasStoragePermission = await controller.hasStoragePermission;
    
    if (mounted) {
      setState(() => _isCheckingPermissions = false);
    }
  }

  Future<void> _requestOverlayPermission() async {
    final controller = context.read<Live2DController>();
    await controller.requestOverlayPermission();
    await _checkPermissions();
  }

  Future<void> _requestStoragePermission() async {
    final controller = context.read<Live2DController>();
    await controller.requestStoragePermission();
    await _checkPermissions();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Live2D 설정'),
        actions: [
          // 새로고침 버튼
          Consumer<Live2DController>(
            builder: (context, controller, _) {
              return IconButton(
                icon: controller.isLoading
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.refresh),
                tooltip: '새로고침',
                onPressed: controller.isLoading
                    ? null
                    : () async {
                        await _checkPermissions();
                        if (controller.hasFolderSelected) {
                          await controller.refreshModels();
                        }
                      },
              );
            },
          ),
          // 로그 버튼
          IconButton(
            icon: const Icon(Icons.bug_report),
            tooltip: '로그 보기',
            onPressed: () => showLive2DLogViewer(context),
          ),
        ],
      ),
      body: Consumer<Live2DController>(
        builder: (context, controller, _) {
          // 로딩 중
          if (controller.state == Live2DControllerState.initial ||
              (controller.isLoading && !controller.hasFolderSelected)) {
            return const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text('초기화 중...'),
                ],
              ),
            );
          }

          // 에러 표시
          if (controller.hasError) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(controller.errorMessage ?? '오류가 발생했습니다'),
                  backgroundColor: theme.colorScheme.error,
                  action: SnackBarAction(
                    label: '확인',
                    textColor: theme.colorScheme.onError,
                    onPressed: () => controller.clearError(),
                  ),
                ),
              );
              controller.clearError();
            });
          }

          return RefreshIndicator(
            onRefresh: () async {
              await _checkPermissions();
              if (controller.hasFolderSelected) {
                await controller.refreshModels();
              }
            },
            child: ListView(
              children: [
                const SizedBox(height: 8),

                // === 1. 권한 섹션 ===
                _SectionHeader(
                  title: '권한',
                  icon: Icons.security,
                ),
                PermissionStatusTile(
                  hasOverlayPermission: _hasOverlayPermission,
                  hasStoragePermission: _hasStoragePermission,
                  onRequestOverlayPermission: _requestOverlayPermission,
                  onRequestStoragePermission: _requestStoragePermission,
                  isLoading: _isCheckingPermissions,
                ),

                // === 2. 데이터 폴더 섹션 ===
                _SectionHeader(
                  title: '데이터 폴더',
                  icon: Icons.folder,
                ),
                FolderPickerTile(
                  currentPath: controller.folderPath,
                  displayName: controller.folderDisplayName,
                  isLoading: controller.isLoading,
                  onPickFolder: () => controller.selectFolder(),
                  onClearFolder: controller.hasFolderSelected
                      ? () => _showClearFolderDialog(context, controller)
                      : null,
                ),

                // === 3. 모델 목록 섹션 ===
                if (controller.hasFolderSelected) ...[
                  _SectionHeader(
                    title: '모델 목록',
                    icon: Icons.face,
                    trailing: Text(
                      '${controller.modelCount}개',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                  
                  if (controller.modelCount == 0)
                    _EmptyModelList()
                  else
                    ...controller.models.map((model) {
                      final selectedModelId = controller.selectedModel?.id;
                      final isSelected = selectedModelId == model.id;
                      return ModelListTile(
                        model: model,
                        isSelected: isSelected,
                        onTap: () => controller.selectModel(
                          isSelected ? null : model,
                        ),
                      );
                    }),
                ],

                // === 4. 표시 설정 섹션 ===
                _SectionHeader(
                  title: '표시 설정',
                  icon: Icons.tune,
                ),
                SizeSliderTile(
                  scale: controller.settings.scale,
                  opacity: controller.settings.opacity,
                  onScaleChanged: controller.setScale,
                  onOpacityChanged: controller.setOpacity,
                  onResetPosition: controller.resetPosition,
                  enabled: controller.hasFolderSelected,
                ),

                // === 5. 플로팅 뷰어 토글 ===
                _SectionHeader(
                  title: '플로팅 뷰어',
                  icon: Icons.visibility,
                ),
                OverlayToggleTile(
                  isEnabled: controller.isEnabled,
                  canEnable: _hasOverlayPermission &&
                      controller.hasFolderSelected &&
                      controller.selectedModel != null,
                  disabledReason: _getDisabledReason(controller),
                  isLoading: _isTogglingOverlay,
                  onChanged: (enabled) async {
                    setState(() => _isTogglingOverlay = true);
                    await controller.setEnabled(enabled);
                    if (mounted) {
                      setState(() => _isTogglingOverlay = false);
                    }
                  },
                ),

                const SizedBox(height: 32),
              ],
            ),
          );
        },
      ),
    );
  }

  String? _getDisabledReason(Live2DController controller) {
    if (!_hasOverlayPermission) {
      return '오버레이 권한이 필요합니다';
    }
    if (!controller.hasFolderSelected) {
      return '데이터 폴더를 선택해주세요';
    }
    if (controller.selectedModel == null) {
      return '모델을 선택해주세요';
    }
    return null;
  }

  void _showClearFolderDialog(
    BuildContext context,
    Live2DController controller,
  ) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('폴더 초기화'),
        content: const Text(
          '폴더 설정을 초기화하시겠습니까?\n'
          '선택한 모델과 오버레이 설정이 모두 초기화됩니다.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('취소'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.pop(context);
              controller.clearFolder();
            },
            child: const Text('초기화'),
          ),
        ],
      ),
    );
  }
}

/// 섹션 헤더 위젯
class _SectionHeader extends StatelessWidget {
  final String title;
  final IconData icon;
  final Widget? trailing;

  const _SectionHeader({
    required this.title,
    required this.icon,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Row(
        children: [
          Icon(
            icon,
            size: 18,
            color: theme.colorScheme.primary,
          ),
          const SizedBox(width: 8),
          Text(
            title,
            style: theme.textTheme.titleSmall?.copyWith(
              color: theme.colorScheme.primary,
              fontWeight: FontWeight.bold,
              letterSpacing: 0.5,
            ),
          ),
          if (trailing != null) ...[
            const Spacer(),
            trailing!,
          ],
        ],
      ),
    );
  }
}

/// 빈 모델 목록 위젯
class _EmptyModelList extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          children: [
            Icon(
              Icons.folder_open,
              size: 48,
              color: theme.colorScheme.onSurfaceVariant,
            ),
            const SizedBox(height: 16),
            Text(
              '모델을 찾을 수 없습니다',
              style: theme.textTheme.titleMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '선택한 폴더에 Live2D 모델이 없습니다.\n'
              '.model3.json 또는 .model.json 파일이 있는\n'
              '폴더를 선택해주세요.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
