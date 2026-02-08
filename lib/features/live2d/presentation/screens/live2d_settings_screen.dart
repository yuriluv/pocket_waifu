// ============================================================================
// Live2D 설정 화면 (Live2D Settings Screen)
// ============================================================================
// Live2D 플로팅 뷰어의 설정을 관리하는 화면입니다.
// ============================================================================

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../controllers/live2d_controller.dart';
import '../widgets/permission_status_tile.dart';
import '../widgets/folder_picker_tile.dart';
import '../widgets/model_list_tile.dart';
import '../widgets/size_slider_tile.dart';
import '../widgets/overlay_toggle_tile.dart';
import '../widgets/log_viewer_widget.dart';
import '../../data/controllers/live2d_overlay_controller.dart';
import '../../data/services/live2d_log_service.dart';
import '../../data/services/interaction_manager.dart';
import '../../domain/entities/interaction_event.dart';
import 'gesture_settings_screen.dart';
import 'auto_behavior_settings_screen.dart';
import 'display_settings_screen.dart';

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

                // === 4.5. 터치스루 설정 섹션 ===
                _SectionHeader(
                  title: '터치스루',
                  icon: Icons.touch_app,
                ),
                _TouchThroughTile(
                  enabled: controller.settings.touchThroughEnabled,
                  alpha: controller.settings.touchThroughAlpha,
                  onEnabledChanged: controller.setTouchThroughEnabled,
                  onAlphaChanged: controller.setTouchThroughAlpha,
                  isActive: controller.hasFolderSelected,
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
                
                // === 6. 고급 설정 메뉴 ===
                _SectionHeader(
                  title: '고급 설정',
                  icon: Icons.settings,
                ),
                _AdvancedSettingsMenu(),
                
                // === 6.5. 편집 모드 ===
                _SectionHeader(
                  title: '편집 모드',
                  icon: Icons.edit,
                ),
                _EditModeTile(
                  isEnabled: controller.settings.editModeEnabled,
                  canEnable: controller.isEnabled,
                  onChanged: controller.setEditMode,
                ),
                
                // === 7. 상호작용 테스트 (개발용) ===
                _SectionHeader(
                  title: '🎮 상호작용 테스트',
                  icon: Icons.touch_app,
                ),
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
/// 상호작용 테스트 타일
class _InteractionTestTile extends StatefulWidget {
  final bool hasOverlayPermission;

  const _InteractionTestTile({
    required this.hasOverlayPermission,
  });

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
    
    // InteractionManager 사용
    final manager = InteractionManager();
    await manager.initialize();
    
    _eventSubscription = manager.eventStream.listen((event) {
      if (mounted) {
        setState(() {
          _receivedEvents.insert(0, 
            '${DateTime.now().toString().substring(11, 19)} - ${event.type.name}'
            '${event.position != null ? " (${event.position!.dx.toInt()}, ${event.position!.dy.toInt()})" : ""}'
          );
          // 최대 20개만 유지
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
            // 제목
            Row(
              children: [
                Icon(
                  Icons.gamepad,
                  color: theme.colorScheme.secondary,
                ),
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
            
            // 이벤트 리스닝 토글
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
            
            // 외부 트리거 테스트
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
            
            // 수신된 이벤트 목록
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
// 고급 설정 메뉴
// ============================================================================

class _AdvancedSettingsMenu extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        ListTile(
          leading: const Icon(Icons.touch_app),
          title: const Text('제스처 설정'),
          subtitle: const Text('제스처별 모션/표정 매핑'),
          trailing: const Icon(Icons.chevron_right),
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => const GestureSettingsScreen(),
              ),
            );
          },
        ),
        
        ListTile(
          leading: const Icon(Icons.auto_awesome),
          title: const Text('자동 동작 설정'),
          subtitle: const Text('눈 깜빡임, 호흡, 시선 추적'),
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
              MaterialPageRoute(
                builder: (_) => const DisplaySettingsScreen(),
              ),
            );
          },
        ),
      ],
    );
  }
}

// ============================================================================
// 터치스루 설정 타일
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
      final clamped = parsed.clamp(0, 80);
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
            // 터치스루 토글
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
                      Text(
                        '터치스루 모드',
                        style: theme.textTheme.titleMedium,
                      ),
                      Text(
                        'ON: 앱 외부에서 터치 통과, 앱 내부에서 드래그 가능',
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

              // 현재 알파값 표시
              Row(
                children: [
                  Icon(
                    Icons.opacity,
                    size: 18,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '현재 윈도우 알파: ${widget.alpha}%',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 12),

              // 터치스루 알파 입력
              Row(
                children: [
                  Expanded(
                    child: Text(
                      '터치스루 투명도',
                      style: theme.textTheme.bodyMedium,
                    ),
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

              // 안내 메시지
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
                      'Android 12+: 최대 80% (터치 패스스루 정책)',
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
// 편집 모드 타일
// ============================================================================

class _EditModeTile extends StatelessWidget {
  final bool isEnabled;
  final bool canEnable;
  final ValueChanged<bool> onChanged;

  const _EditModeTile({
    required this.isEnabled,
    required this.canEnable,
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
            // 편집 모드 토글
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
                      Text(
                        '디스플레이 편집 모드',
                        style: theme.textTheme.titleMedium,
                      ),
                      Text(
                        '활성화 시 투명상자 테두리가 표시됩니다',
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
              
              // 편집 모드 안내
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: theme.colorScheme.primaryContainer.withOpacity(0.3),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: theme.colorScheme.primary.withOpacity(0.3),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.border_style,
                      color: theme.colorScheme.primary,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        '파란색 테두리가 투명상자 영역을 표시합니다.\n이후 투명상자에 대한 추가 설정이 여기에 추가됩니다.',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurface,
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
