// ============================================================================
// Live2D 모듈 (Live2D Module)
// ============================================================================
// Live2D 기능의 진입점입니다.
// 이 파일에서 모든 Live2D 관련 export를 관리합니다.
// v2.1: Native OpenGL 방식으로 전환 - WebView 관련 코드 제거
// ============================================================================

// === Domain Entities (Native 상호작용 시스템) ===
export 'domain/entities/interaction_event.dart';
export 'domain/entities/gesture_config.dart';

// === Data Models ===
export 'data/models/live2d_model_info.dart';
export 'data/models/live2d_settings.dart';

// === Services (Native 방식) ===
export 'data/services/live2d_log_service.dart';
export 'data/services/live2d_storage_service.dart';
export 'data/services/live2d_native_bridge.dart';
export 'data/services/interaction_manager.dart';
export 'data/services/interaction_config_service.dart';

// === Controllers (Native 오버레이) ===
export 'data/controllers/live2d_overlay_controller.dart';

// === Repository ===
export 'data/repositories/live2d_repository.dart';

// === Controller ===
export 'presentation/controllers/live2d_controller.dart';

// === Screens ===
export 'presentation/screens/live2d_settings_screen.dart';
export 'presentation/screens/gesture_settings_screen.dart';
export 'presentation/screens/auto_behavior_settings_screen.dart';
export 'presentation/screens/display_settings_screen.dart';

// === Widgets ===
export 'presentation/widgets/model_list_tile.dart';
export 'presentation/widgets/folder_picker_tile.dart';
export 'presentation/widgets/size_slider_tile.dart';
export 'presentation/widgets/overlay_toggle_tile.dart';
export 'presentation/widgets/permission_status_tile.dart';
export 'presentation/widgets/log_viewer_widget.dart';
