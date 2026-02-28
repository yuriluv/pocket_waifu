// ============================================================================
// ============================================================================
// ============================================================================

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../../services/model_scanner_service.dart';
import '../../../../utils/ui_feedback.dart';
import '../../utils/folder_validator.dart';
import '../../data/services/live2d_storage_service.dart';
import '../controllers/live2d_controller.dart';
import '../widgets/permission_status_tile.dart';
import '../widgets/folder_picker_tile.dart';
import '../widgets/model_list_tile.dart';
import '../widgets/size_slider_tile.dart';
import '../widgets/overlay_toggle_tile.dart';
import '../widgets/log_viewer_widget.dart';
import '../../data/controllers/live2d_overlay_controller.dart';
import '../../data/models/display_preset.dart';
import '../../data/services/live2d_log_service.dart';
import '../../data/services/interaction_manager.dart';
import '../../domain/entities/interaction_event.dart';
import 'gesture_settings_screen.dart';
import 'auto_behavior_settings_screen.dart';
import 'display_settings_screen.dart';
import 'interaction_settings_screen.dart';
import 'live2d_pipeline_prototype_screen.dart';
import '../../../../widgets/empty_state_view.dart';

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
          IconButton(
            icon: const Icon(Icons.bug_report),
            tooltip: '로그 보기',
            onPressed: () => showLive2DLogViewer(context),
          ),
        ],
      ),
      body: Consumer<Live2DController>(
        builder: (context, controller, _) {
          if (controller.state == Live2DControllerState.initial ||
              (controller.isLoading && !controller.hasFolderSelected)) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const CircularProgressIndicator(),
                  const SizedBox(height: 12),
                  Text(
                    '초기화 중...',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            );
          }

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

                _SectionHeader(title: '권한', icon: Icons.security),
                PermissionStatusTile(
                  hasOverlayPermission: _hasOverlayPermission,
                  hasStoragePermission: _hasStoragePermission,
                  onRequestOverlayPermission: _requestOverlayPermission,
                  onRequestStoragePermission: _requestStoragePermission,
                  isLoading: _isCheckingPermissions,
                ),

                _SectionHeader(title: '데이터 폴더', icon: Icons.folder),
                FolderPickerTile(
                  currentPath: controller.folderPath,
                  displayName: controller.folderDisplayName,
                  isLoading: controller.isLoading,
                  onPickFolder: () => controller.selectFolder(),
                  onValidateFolder: controller.hasFolderSelected
                      ? () => _validateCurrentFolder(context, controller)
                      : null,
                  onClearFolder: controller.hasFolderSelected
                      ? () => _showClearFolderDialog(context, controller)
                      : null,
                ),

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
                        onTap: () =>
                            controller.selectModel(isSelected ? null : model),
                      );
                    }),
                ],

                _SectionHeader(title: '표시 설정', icon: Icons.tune),
                SizeSliderTile(
                  scale: controller.settings.scale,
                  opacity: controller.settings.opacity,
                  onScaleChanged: controller.setScale,
                  onOpacityChanged: controller.setOpacity,
                  onResetPosition: controller.resetPosition,
                  enabled: controller.hasFolderSelected,
                ),

                _SectionHeader(title: '터치스루', icon: Icons.touch_app),
                _TouchThroughTile(
                  enabled: controller.settings.touchThroughEnabled,
                  alpha: controller.settings.touchThroughAlpha,
                  onEnabledChanged: controller.setTouchThroughEnabled,
                  onAlphaChanged: controller.setTouchThroughAlpha,
                  isActive: controller.hasFolderSelected,
                ),

                _SectionHeader(title: '플로팅 뷰어', icon: Icons.visibility),
                OverlayToggleTile(
                  isEnabled: controller.isEnabled,
                  canEnable:
                      _hasOverlayPermission &&
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

                _SectionHeader(title: '고급 설정', icon: Icons.settings),
                _AdvancedSettingsMenu(),

                _SectionHeader(title: '편집 모드', icon: Icons.edit),
                _EditModeTile(
                  isEnabled: controller.settings.editModeEnabled,
                  canEnable: controller.isEnabled,
                  selectedModelName: controller.selectedModel?.name,
                  onChanged: controller.setEditMode,
                ),

                _SectionHeader(title: '🎮 상호작용 테스트', icon: Icons.touch_app),
                _InteractionTestTile(
                  hasOverlayPermission: _hasOverlayPermission,
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

  Future<void> _validateCurrentFolder(
    BuildContext context,
    Live2DController controller,
  ) async {
    final folderPath = controller.folderPath;
    if (folderPath == null) return;

    final storageService = Live2DStorageService();
    final rootPath = await storageService.getModelRootPath() ?? folderPath;
    final scanner = ModelScannerService();

    final (result, count) = await FolderValidator.validate(
      rootPath,
      (path) => scanner.scanModelsRecursive(path),
    );

    if (!context.mounted) return;

    switch (result) {
      case FolderValidationResult.pathMissing:
        context.showErrorSnackBar('경로 오류: 선택한 폴더가 기기에 존재하지 않습니다.');
        break;
      case FolderValidationResult.permissionDenied:
        context.showErrorSnackBar('권한 오류: 폴더에 접근할 수 없습니다. 권한을 확인해주세요.');
        break;
      case FolderValidationResult.noModel:
        context.showErrorSnackBar('검증 실패: .model3.json 파일을 찾을 수 없습니다.');
        break;
      case FolderValidationResult.valid:
        context.showInfoSnackBar('검증 완료: 정상적인 모델 폴더입니다. ($count개 모델 포함)');
        break;
    }
  }
}

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
          Icon(icon, size: 18, color: theme.colorScheme.primary),
          const SizedBox(width: 8),
          Text(
            title,
            style: theme.textTheme.titleSmall?.copyWith(
              color: theme.colorScheme.primary,
              fontWeight: FontWeight.bold,
              letterSpacing: 0.5,
            ),
          ),
          if (trailing != null) ...[const Spacer(), trailing!],
        ],
      ),
    );
  }
}

class _EmptyModelList extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: SizedBox(
        height: 260,
        child: EmptyStateView(
          icon: Icons.folder_open,
          title: '모델을 찾을 수 없습니다',
          subtitle:
              '선택한 폴더에 Live2D 모델이 없습니다.\n'
              '.model3.json 또는 .model.json 파일이 있는 폴더를 선택해주세요.',
        ),
      ),
    );
  }
}

class _InteractionTestTile extends StatefulWidget {
  final bool hasOverlayPermission;

  const _InteractionTestTile({required this.hasOverlayPermission});

  @override
  State<_InteractionTestTile> createState() => _InteractionTestTileState();
}

class _InteractionTestTileState extends State<_InteractionTestTile> {
  final List<String> _receivedEvents = [];
  late final _overlayController = Live2DOverlayController();
  StreamSubscription<InteractionEvent>? _eventSubscription;
  bool _isListening = false;

  @override
  void initState() {
    super.initState();
    _overlayController.initialize().then((_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _stopListening();
    _overlayController.dispose();
    super.dispose();
  }

  void _startListening() async {
    if (_isListening) return;

    final manager = InteractionManager();
    await manager.initialize();

    _eventSubscription = manager.eventStream.listen((event) {
      if (mounted) {
        setState(() {
          _receivedEvents.insert(
            0,
            '${DateTime.now().toString().substring(11, 19)} - ${event.type.name}'
            '${event.position != null ? " (${event.position!.dx.toInt()}, ${event.position!.dy.toInt()})" : ""}',
          );
          if (_receivedEvents.length > 20) {
            _receivedEvents.removeLast();
          }
        });
      }
    });

    setState(() => _isListening = true);
    live2dLog.info('InteractionTest', '이벤트 수신 시작');
  }

  void _stopListening() {
    _eventSubscription?.cancel();
    _eventSubscription = null;
    if (mounted) {
      setState(() => _isListening = false);
    }
    live2dLog.info('InteractionTest', '이벤트 수신 중지');
  }

  void _clearEvents() {
    setState(() => _receivedEvents.clear());
  }

  Future<void> _testTriggerHappy() async {
    final manager = InteractionManager();
    await manager.triggerEmotion('happy');
    live2dLog.info('InteractionTest', '감정 트리거: happy');
  }

  Future<void> _testTriggerMotion() async {
    final manager = InteractionManager();
    await manager.triggerMotion('tap');
    live2dLog.info('InteractionTest', '모션 트리거: tap');
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final canTest = widget.hasOverlayPermission;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.gamepad, color: theme.colorScheme.secondary),
                const SizedBox(width: 8),
                Text(
                  '상호작용 시스템 테스트',
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              '오버레이를 표시한 후 터치/제스처를 수행하여 이벤트를 테스트합니다.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 16),

            Row(
              children: [
                Expanded(
                  child: FilledButton.tonalIcon(
                    onPressed: canTest
                        ? (_isListening ? _stopListening : _startListening)
                        : null,
                    icon: Icon(_isListening ? Icons.stop : Icons.play_arrow),
                    label: Text(_isListening ? '이벤트 수신 중지' : '이벤트 수신 시작'),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton.outlined(
                  onPressed: _receivedEvents.isNotEmpty ? _clearEvents : null,
                  icon: const Icon(Icons.clear_all),
                  tooltip: '이벤트 기록 삭제',
                ),
              ],
            ),

            const SizedBox(height: 12),

            Text(
              '외부 트리거 테스트',
              style: theme.textTheme.labelMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: canTest ? _testTriggerHappy : null,
                    icon: const Icon(Icons.mood, size: 18),
                    label: const Text('Happy 표정'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: canTest ? _testTriggerMotion : null,
                    icon: const Icon(Icons.animation, size: 18),
                    label: const Text('Tap 모션'),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 12),

            Text(
              '수신된 이벤트 (${_receivedEvents.length})',
              style: theme.textTheme.labelMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Container(
              height: 150,
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(8),
              ),
              child: _receivedEvents.isEmpty
                  ? Center(
                      child: Text(
                        _isListening
                            ? '오버레이에서 터치/제스처를 수행하세요...'
                            : '이벤트 수신을 시작하세요',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    )
                  : ListView.builder(
                      itemCount: _receivedEvents.length,
                      itemBuilder: (context, index) {
                        return Text(
                          _receivedEvents[index],
                          style: theme.textTheme.bodySmall?.copyWith(
                            fontFamily: 'monospace',
                            fontSize: 11,
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

// ============================================================================
// ============================================================================

class _AdvancedSettingsMenu extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        ListTile(
          leading: const Icon(Icons.sports_esports),
          title: const Text('상호작용 설정'),
          subtitle: const Text('모션/표정 테스트, 제스처 매핑, 자동 동작'),
          trailing: const Icon(Icons.chevron_right),
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => const InteractionSettingsScreen(),
              ),
            );
          },
        ),

        ListTile(
          leading: const Icon(Icons.touch_app),
          title: const Text('제스처 설정'),
          subtitle: const Text('제스처별 모션/표정 매핑'),
          trailing: const Icon(Icons.chevron_right),
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const GestureSettingsScreen()),
            );
          },
        ),

        ListTile(
          leading: const Icon(Icons.auto_awesome),
          title: const Text('자동 동작 설정'),
          subtitle: const Text('눈 깜박임, 호흡, 시선 추적'),
          trailing: const Icon(Icons.chevron_right),
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => const AutoBehaviorSettingsScreen(),
              ),
            );
          },
        ),

        ListTile(
          leading: const Icon(Icons.display_settings),
          title: const Text('디스플레이 설정'),
          subtitle: const Text('크기, 투명도, 위치 상세 설정'),
          trailing: const Icon(Icons.chevron_right),
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const DisplaySettingsScreen()),
            );
          },
        ),
        ListTile(
          leading: const Icon(Icons.account_tree),
          title: const Text('Lua/Regex 파이프라인 (시안)'),
          subtitle: const Text('스크립트/정규식/Live2D 지시어 UX 프로토타입'),
          trailing: const Icon(Icons.chevron_right),
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => const Live2DPipelinePrototypeScreen(),
              ),
            );
          },
        ),
      ],
    );
  }
}

// ============================================================================
// ============================================================================

class _TouchThroughTile extends StatefulWidget {
  final bool enabled;
  final int alpha;
  final ValueChanged<bool> onEnabledChanged;
  final ValueChanged<int> onAlphaChanged;
  final bool isActive;

  const _TouchThroughTile({
    required this.enabled,
    required this.alpha,
    required this.onEnabledChanged,
    required this.onAlphaChanged,
    required this.isActive,
  });

  @override
  State<_TouchThroughTile> createState() => _TouchThroughTileState();
}

class _TouchThroughTileState extends State<_TouchThroughTile> {
  late TextEditingController _alphaController;

  @override
  void initState() {
    super.initState();
    _alphaController = TextEditingController(text: widget.alpha.toString());
  }

  @override
  void didUpdateWidget(covariant _TouchThroughTile oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.alpha != widget.alpha) {
      _alphaController.text = widget.alpha.toString();
    }
  }

  @override
  void dispose() {
    _alphaController.dispose();
    super.dispose();
  }

  void _onAlphaSubmitted(String value) {
    final parsed = int.tryParse(value);
    if (parsed != null) {
      final clamped = parsed.clamp(0, 100);
      widget.onAlphaChanged(clamped);
      _alphaController.text = clamped.toString();
    } else {
      _alphaController.text = widget.alpha.toString();
    }
  }

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
                  Icons.touch_app,
                  color: widget.isActive
                      ? theme.colorScheme.primary
                      : theme.colorScheme.onSurfaceVariant,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('터치스루 모드', style: theme.textTheme.titleMedium),
                      Text(
                        'ON: 앱 외부에서 터치 통과 + 반투명, 앱 내부에서 드래그 가능',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                Switch(
                  value: widget.enabled,
                  onChanged: widget.isActive ? widget.onEnabledChanged : null,
                ),
              ],
            ),

            if (widget.enabled) ...[
              const SizedBox(height: 16),
              const Divider(height: 1),
              const SizedBox(height: 12),

              Row(
                children: [
                  Icon(
                    Icons.opacity,
                    size: 18,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '배경 시 캐릭터 투명도: ${widget.alpha}%',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 12),

              Row(
                children: [
                  Expanded(
                    child: Text('배경 시 투명도', style: theme.textTheme.bodyMedium),
                  ),
                  SizedBox(
                    width: 80,
                    height: 40,
                    child: TextField(
                      controller: _alphaController,
                      keyboardType: TextInputType.number,
                      textAlign: TextAlign.center,
                      decoration: InputDecoration(
                        suffixText: '%',
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 8,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        isDense: true,
                      ),
                      onSubmitted: _onAlphaSubmitted,
                      onEditingComplete: () {
                        _onAlphaSubmitted(_alphaController.text);
                      },
                      enabled: widget.isActive,
                    ),
                  ),
                ],
              ),

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
                      '앱 외부 사용 시 캐릭터가 이 투명도로 표시됩니다',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ============================================================================
// ============================================================================

class _EditModeTile extends StatelessWidget {
  final bool isEnabled;
  final bool canEnable;
  final String? selectedModelName;
  final ValueChanged<bool> onChanged;

  const _EditModeTile({
    required this.isEnabled,
    required this.canEnable,
    required this.selectedModelName,
    required this.onChanged,
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
            Row(
              children: [
                Icon(
                  Icons.edit,
                  color: canEnable
                      ? theme.colorScheme.primary
                      : theme.colorScheme.onSurfaceVariant,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('디스플레이 편집 모드', style: theme.textTheme.titleMedium),
                      Text(
                        '캐릭터 위치, 크기, 회전을 편집합니다',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                Switch(
                  value: isEnabled,
                  onChanged: canEnable ? onChanged : null,
                ),
              ],
            ),

            if (isEnabled) ...[
              const SizedBox(height: 10),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: theme.colorScheme.primaryContainer.withValues(
                    alpha: 0.4,
                  ),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: theme.colorScheme.primary.withValues(alpha: 0.5),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.radio_button_checked,
                      size: 14,
                      color: theme.colorScheme.primary,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        selectedModelName != null
                            ? '편집 모드 ON · 모델: $selectedModelName'
                            : '편집 모드 ON · 모델을 선택하면 저장/초기화가 활성화됩니다',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onPrimaryContainer,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],

            if (!canEnable) ...[
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
                      '플로팅 뷰어가 활성화된 상태에서만 사용 가능합니다',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                ],
              ),
            ],

            if (isEnabled) ...[
              const SizedBox(height: 12),
              const Divider(height: 1),
              const SizedBox(height: 12),
              const _EditModeControlPanel(),
            ],
          ],
        ),
      ),
    );
  }
}

// ============================================================================
// ============================================================================

class _EditModeControlPanel extends StatelessWidget {
  const _EditModeControlPanel();

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<Live2DController>();
    final settings = controller.settings;
    final theme = Theme.of(context);
    final hasSelectedModel = controller.selectedModel != null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(
              Icons.edit_attributes,
              size: 20,
              color: theme.colorScheme.primary,
            ),
            const SizedBox(width: 8),
            Text(
              '편집 모드 활성',
              style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: theme.colorScheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '편집 제스처 가이드',
                style: theme.textTheme.bodySmall?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                '핀치: 모델 크기 · 드래그: 위치 · 모서리 드래그: 컨테이너 크기',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        _buildToggleTile(
          theme: theme,
          icon: Icons.push_pin,
          title: '캐릭터 고정',
          subtitle: settings.characterPinned
              ? '투명상자만 이동/리사이즈 가능'
              : '캐릭터와 투명상자가 함께 이동',
          value: settings.characterPinned,
          onChanged: controller.setCharacterPinned,
        ),

        const SizedBox(height: 12),

        Text(
          '캐릭터 상대 크기',
          style: theme.textTheme.bodyMedium?.copyWith(
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 4),
        Row(
          children: [
            const Text('0.1x'),
            Expanded(
              child: Slider(
                value: settings.relativeCharacterScale.clamp(0.1, 3.0),
                min: 0.1,
                max: 3.0,
                divisions: 29,
                label: '${settings.relativeCharacterScale.toStringAsFixed(1)}x',
                onChanged: controller.setRelativeCharacterScale,
              ),
            ),
            const Text('3.0x'),
          ],
        ),
        Center(
          child: Text(
            '현재: ${settings.relativeCharacterScale.toStringAsFixed(1)}x',
            style: theme.textTheme.bodySmall,
          ),
        ),

        const SizedBox(height: 12),
        _buildDimensionSlider(
          theme: theme,
          title: '컨테이너 너비',
          value: settings.overlayWidth.clamp(120, 1920).toDouble(),
          min: 120,
          max: 1920,
          onChanged: (value) {
            controller.setOverlaySize(value.round(), settings.overlayHeight);
          },
        ),
        const SizedBox(height: 8),
        _buildDimensionSlider(
          theme: theme,
          title: '컨테이너 높이',
          value: settings.overlayHeight.clamp(160, 2160).toDouble(),
          min: 160,
          max: 2160,
          onChanged: (value) {
            controller.setOverlaySize(settings.overlayWidth, value.round());
          },
        ),

        const SizedBox(height: 12),
        Row(
          children: [
            Icon(Icons.tune, size: 20, color: theme.colorScheme.primary),
            const SizedBox(width: 8),
            Text(
              '모델 오프셋',
              style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w500,
              ),
            ),
            const Spacer(),
            Text(
              'X:${settings.characterOffsetX.toStringAsFixed(0)} / '
              'Y:${settings.characterOffsetY.toStringAsFixed(0)}',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        _buildOffsetSlider(
          label: 'X',
          value: settings.characterOffsetX.clamp(-400.0, 400.0),
          onChanged: (value) {
            controller.setCharacterOffset(value, settings.characterOffsetY);
          },
        ),
        _buildOffsetSlider(
          label: 'Y',
          value: settings.characterOffsetY.clamp(-400.0, 400.0),
          onChanged: (value) {
            controller.setCharacterOffset(settings.characterOffsetX, value);
          },
        ),
        Align(
          alignment: Alignment.centerRight,
          child: TextButton.icon(
            onPressed: () => controller.setCharacterOffset(0, 0),
            icon: const Icon(Icons.center_focus_strong, size: 18),
            label: const Text('오프셋 초기화'),
          ),
        ),

        const SizedBox(height: 12),

        Row(
          children: [
            Icon(
              Icons.rotate_right,
              size: 20,
              color: theme.colorScheme.primary,
            ),
            const SizedBox(width: 8),
            Text(
              '캐릭터 회전',
              style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w500,
              ),
            ),
            const Spacer(),
            SizedBox(
              width: 80,
              height: 40,
              child: _RotationInput(
                value: settings.characterRotation,
                onChanged: controller.setCharacterRotation,
              ),
            ),
            const SizedBox(width: 4),
            const Text('°'),
          ],
        ),

        const SizedBox(height: 12),
        Row(
          children: [
            Icon(Icons.save, size: 20, color: theme.colorScheme.primary),
            const SizedBox(width: 8),
            Text(
              '레이아웃 저장',
              style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w500,
              ),
            ),
            const Spacer(),
            TextButton.icon(
              onPressed: !hasSelectedModel
                  ? null
                  : () => controller.saveDisplayConfigForModel(
                      controller.selectedModel!.id,
                    ),
              icon: const Icon(Icons.save, size: 18),
              label: const Text('저장'),
            ),
            TextButton.icon(
              onPressed: !hasSelectedModel
                  ? null
                  : () => controller.resetDisplayConfigForModel(
                      controller.selectedModel!.id,
                    ),
              icon: const Icon(Icons.refresh, size: 18),
              label: const Text('초기화'),
            ),
          ],
        ),
        if (!hasSelectedModel)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              '모델을 선택하면 현재 편집값을 모델별로 저장/초기화할 수 있습니다.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),

        const SizedBox(height: 16),
        const Divider(height: 1),
        const SizedBox(height: 12),

        Row(
          children: [
            Icon(Icons.bookmark, size: 20, color: theme.colorScheme.primary),
            const SizedBox(width: 8),
            Text(
              '디스플레이 프리셋',
              style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w500,
              ),
            ),
            const Spacer(),
            TextButton.icon(
              onPressed: () => _showSavePresetDialog(context, controller),
              icon: const Icon(Icons.save, size: 18),
              label: const Text('저장'),
            ),
            TextButton.icon(
              onPressed: () => _showPresetsDialog(context, controller),
              icon: const Icon(Icons.list, size: 18),
              label: const Text('보기'),
            ),
          ],
        ),
        if (controller.presets.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              '저장된 프리셋: ${controller.presets.length}개',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildDimensionSlider({
    required ThemeData theme,
    required String title,
    required double value,
    required double min,
    required double max,
    required ValueChanged<double> onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              title,
              style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w500,
              ),
            ),
            const Spacer(),
            Text(
              '${value.round()}px',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
        Slider(
          value: value.clamp(min, max),
          min: min,
          max: max,
          divisions: ((max - min) / 10).round(),
          label: '${value.round()}px',
          onChanged: onChanged,
        ),
      ],
    );
  }

  Widget _buildOffsetSlider({
    required String label,
    required double value,
    required ValueChanged<double> onChanged,
  }) {
    return Row(
      children: [
        SizedBox(width: 22, child: Text(label, textAlign: TextAlign.center)),
        Expanded(
          child: Slider(
            value: value.clamp(-400.0, 400.0),
            min: -400,
            max: 400,
            divisions: 160,
            label: value.toStringAsFixed(0),
            onChanged: onChanged,
          ),
        ),
      ],
    );
  }

  Widget _buildToggleTile({
    required ThemeData theme,
    required IconData icon,
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return Row(
      children: [
        Icon(
          icon,
          size: 20,
          color: value
              ? theme.colorScheme.primary
              : theme.colorScheme.onSurfaceVariant,
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w500,
                ),
              ),
              Text(
                subtitle,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
        Switch(value: value, onChanged: onChanged),
      ],
    );
  }

  void _showSavePresetDialog(
    BuildContext context,
    Live2DController controller,
  ) {
    final nameController = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('프리셋 저장'),
        content: TextField(
          controller: nameController,
          decoration: const InputDecoration(
            labelText: '프리셋 이름',
            hintText: '예: 기본 설정',
            border: OutlineInputBorder(),
          ),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('취소'),
          ),
          FilledButton(
            onPressed: () {
              final name = nameController.text.trim();
              if (name.isNotEmpty) {
                controller.savePreset(name);
                Navigator.pop(ctx);
                ScaffoldMessenger.of(
                  context,
                ).showSnackBar(SnackBar(content: Text('프리셋 "$name" 저장됨')));
              }
            },
            child: const Text('저장'),
          ),
        ],
      ),
    );
  }

  void _showPresetsDialog(BuildContext context, Live2DController controller) {
    showDialog(
      context: context,
      builder: (ctx) => _PresetsDialog(controller: controller),
    );
  }
}

// ============================================================================
// ============================================================================

class _RotationInput extends StatefulWidget {
  final int value;
  final ValueChanged<int> onChanged;

  const _RotationInput({required this.value, required this.onChanged});

  @override
  State<_RotationInput> createState() => _RotationInputState();
}

class _RotationInputState extends State<_RotationInput> {
  late TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.value.toString());
  }

  @override
  void didUpdateWidget(covariant _RotationInput oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.value != widget.value) {
      _controller.text = widget.value.toString();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onSubmitted(String val) {
    final parsed = int.tryParse(val);
    if (parsed != null) {
      widget.onChanged(parsed % 360);
    } else {
      _controller.text = widget.value.toString();
    }
  }

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: _controller,
      keyboardType: TextInputType.number,
      textAlign: TextAlign.center,
      decoration: InputDecoration(
        contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
        isDense: true,
      ),
      onSubmitted: _onSubmitted,
      onEditingComplete: () => _onSubmitted(_controller.text),
    );
  }
}

// ============================================================================
// ============================================================================

class _PresetsDialog extends StatefulWidget {
  final Live2DController controller;

  const _PresetsDialog({required this.controller});

  @override
  State<_PresetsDialog> createState() => _PresetsDialogState();
}

class _PresetsDialogState extends State<_PresetsDialog> {
  @override
  Widget build(BuildContext context) {
    final presets = widget.controller.presets;
    final theme = Theme.of(context);

    return AlertDialog(
      title: const Text('디스플레이 프리셋'),
      content: SizedBox(
        width: double.maxFinite,
        child: presets.isEmpty
            ? const Padding(
                padding: EdgeInsets.all(16),
                child: Text('저장된 프리셋이 없습니다.\n편집 모드에서 프리셋을 저장하세요.'),
              )
            : ListView.builder(
                shrinkWrap: true,
                itemCount: presets.length,
                itemBuilder: (ctx, index) {
                  final preset = presets[index];
                  return Card(
                    child: ListTile(
                      title: Text(preset.name),
                      subtitle: Text(
                        '크기: ${preset.relativeCharacterScale.toStringAsFixed(1)}x, '
                        '회전: ${preset.characterRotation}°'
                        '${preset.linkedModelFolder != null ? '\n링크: ${preset.linkedModelFolder}' : ''}',
                        style: theme.textTheme.bodySmall,
                      ),
                      isThreeLine: preset.linkedModelFolder != null,
                      trailing: PopupMenuButton<String>(
                        onSelected: (action) =>
                            _handlePresetAction(action, preset),
                        itemBuilder: (_) => [
                          const PopupMenuItem(
                            value: 'load',
                            child: Text('불러오기'),
                          ),
                          const PopupMenuItem(value: 'link', child: Text('링크')),
                          if (preset.linkedModelFolder != null)
                            const PopupMenuItem(
                              value: 'unlink',
                              child: Text('링크 해제'),
                            ),
                          const PopupMenuItem(
                            value: 'delete',
                            child: Text('삭제'),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('닫기'),
        ),
      ],
    );
  }

  void _handlePresetAction(String action, DisplayPreset preset) async {
    switch (action) {
      case 'load':
        await widget.controller.loadPreset(preset);
        if (mounted) {
          Navigator.pop(context);
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text('프리셋 "${preset.name}" 적용됨')));
        }
        break;
      case 'delete':
        await widget.controller.deletePreset(preset.id);
        if (mounted) setState(() {});
        break;
      case 'link':
        if (mounted) _showModelLinkDialog(preset);
        break;
      case 'unlink':
        await widget.controller.unlinkPreset(preset.id);
        if (mounted) setState(() {});
        break;
    }
  }

  void _showModelLinkDialog(DisplayPreset preset) {
    final models = widget.controller.models;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('모델 링크'),
        content: SizedBox(
          width: double.maxFinite,
          child: models.isEmpty
              ? const Text('검색 가능한 모델이 없습니다.')
              : ListView.builder(
                  shrinkWrap: true,
                  itemCount: models.length,
                  itemBuilder: (_, index) {
                    final model = models[index];
                    final folderKey = model.linkFolderKey;
                    return ListTile(
                      title: Text(model.name),
                      subtitle: Text(folderKey),
                      onTap: () {
                        widget.controller.linkPresetToModel(
                          preset.id,
                          folderKey,
                          model.id,
                        );
                        Navigator.pop(ctx);
                        setState(() {});
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              '"${preset.name}" → ${model.name} 링크됨',
                            ),
                          ),
                        );
                      },
                    );
                  },
                ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('취소'),
          ),
        ],
      ),
    );
  }
}
