// ============================================================================
// 상호작용 설정 서비스 (Interaction Config Service)
// ============================================================================
// 상호작용 설정을 저장하고 불러오는 서비스입니다.
// SharedPreferences를 사용하여 설정을 영구 저장합니다.
// ============================================================================

import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/interaction_config.dart';
import '../../domain/entities/gesture_config.dart';
import '../../presentation/screens/auto_behavior_settings_screen.dart';
import 'live2d_log_service.dart';

/// 상호작용 설정 서비스
class InteractionConfigService {
  static const String _tag = 'InteractionConfigService';
  static const String _prefsKey = 'live2d_interaction_config';
  
  // 싱글톤
  static final InteractionConfigService _instance = InteractionConfigService._internal();
  factory InteractionConfigService() => _instance;
  InteractionConfigService._internal();
  
  InteractionConfig? _cachedConfig;
  
  /// 설정 로드
  Future<InteractionConfig> loadConfig() async {
    if (_cachedConfig != null) {
      return _cachedConfig!;
    }
    
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonString = prefs.getString(_prefsKey);
      
      if (jsonString != null) {
        final json = jsonDecode(jsonString) as Map<String, dynamic>;
        _cachedConfig = InteractionConfig.fromJson(json);
        live2dLog.info(_tag, '설정 로드 완료', details: '매핑 수: ${_cachedConfig!.mappings.length}');
        return _cachedConfig!;
      }
    } catch (e) {
      live2dLog.error(_tag, '설정 로드 실패', error: e);
    }
    
    // 기본 설정 반환
    _cachedConfig = InteractionConfig.defaults();
    live2dLog.info(_tag, '기본 설정 사용');
    return _cachedConfig!;
  }
  
  /// 설정 저장
  Future<bool> saveConfig(InteractionConfig config) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonString = jsonEncode(config.toJson());
      await prefs.setString(_prefsKey, jsonString);
      
      _cachedConfig = config;
      live2dLog.info(_tag, '설정 저장 완료');
      return true;
    } catch (e) {
      live2dLog.error(_tag, '설정 저장 실패', error: e);
      return false;
    }
  }
  
  /// 설정 초기화
  Future<bool> resetConfig() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_prefsKey);
      _cachedConfig = null;
      live2dLog.info(_tag, '설정 초기화됨');
      return true;
    } catch (e) {
      live2dLog.error(_tag, '설정 초기화 실패', error: e);
      return false;
    }
  }
  
  /// 캐시된 설정 가져오기 (동기)
  InteractionConfig? getCachedConfig() => _cachedConfig;
  
  /// 설정 내보내기 (JSON 문자열)
  Future<String?> exportConfig() async {
    try {
      final config = await loadConfig();
      return jsonEncode(config.toJson());
    } catch (e) {
      live2dLog.error(_tag, '설정 내보내기 실패', error: e);
      return null;
    }
  }
  
  /// 설정 가져오기 (JSON 문자열)
  Future<bool> importConfig(String jsonString) async {
    try {
      final json = jsonDecode(jsonString) as Map<String, dynamic>;
      final config = InteractionConfig.fromJson(json);
      return await saveConfig(config);
    } catch (e) {
      live2dLog.error(_tag, '설정 가져오기 실패', error: e);
      return false;
    }
  }
  
  // ============================================================================
  // GestureConfig 관련
  // ============================================================================
  
  static const String _gestureConfigKey = 'live2d_gesture_config';
  GestureConfig? _cachedGestureConfig;
  
  /// 제스처 설정 로드
  Future<GestureConfig> loadGestureConfig() async {
    if (_cachedGestureConfig != null) {
      return _cachedGestureConfig!;
    }
    
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonString = prefs.getString(_gestureConfigKey);
      
      if (jsonString != null) {
        final json = jsonDecode(jsonString) as Map<String, dynamic>;
        _cachedGestureConfig = GestureConfig.fromJson(json);
        live2dLog.info(_tag, '제스처 설정 로드 완료');
        return _cachedGestureConfig!;
      }
    } catch (e) {
      live2dLog.error(_tag, '제스처 설정 로드 실패', error: e);
    }
    
    _cachedGestureConfig = GestureConfig.defaults();
    return _cachedGestureConfig!;
  }
  
  /// 제스처 설정 저장
  Future<bool> saveGestureConfig(GestureConfig config) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonString = jsonEncode(config.toJson());
      await prefs.setString(_gestureConfigKey, jsonString);
      
      _cachedGestureConfig = config;
      live2dLog.info(_tag, '제스처 설정 저장 완료');
      return true;
    } catch (e) {
      live2dLog.error(_tag, '제스처 설정 저장 실패', error: e);
      return false;
    }
  }
  
  // ============================================================================
  // AutoBehaviorSettings 관련
  // ============================================================================
  
  static const String _autoBehaviorKey = 'live2d_auto_behavior';
  AutoBehaviorSettings? _cachedAutoBehavior;
  
  /// 자동 동작 설정 로드
  Future<AutoBehaviorSettings> loadAutoBehaviorSettings() async {
    if (_cachedAutoBehavior != null) {
      return _cachedAutoBehavior!;
    }
    
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonString = prefs.getString(_autoBehaviorKey);
      
      if (jsonString != null) {
        final json = jsonDecode(jsonString) as Map<String, dynamic>;
        _cachedAutoBehavior = AutoBehaviorSettings.fromJson(json);
        live2dLog.info(_tag, '자동 동작 설정 로드 완료');
        return _cachedAutoBehavior!;
      }
    } catch (e) {
      live2dLog.error(_tag, '자동 동작 설정 로드 실패', error: e);
    }
    
    _cachedAutoBehavior = const AutoBehaviorSettings();
    return _cachedAutoBehavior!;
  }
  
  /// 자동 동작 설정 저장
  Future<bool> saveAutoBehaviorSettings(AutoBehaviorSettings settings) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonString = jsonEncode(settings.toJson());
      await prefs.setString(_autoBehaviorKey, jsonString);
      
      _cachedAutoBehavior = settings;
      live2dLog.info(_tag, '자동 동작 설정 저장 완료');
      return true;
    } catch (e) {
      live2dLog.error(_tag, '자동 동작 설정 저장 실패', error: e);
      return false;
    }
  }
  
  // ============================================================================
  // 오버레이 상태 저장/복원
  // ============================================================================
  
  static const String _overlayStateKey = 'live2d_overlay_state';
  
  /// 오버레이 상태 저장
  Future<bool> saveOverlayState({
    required String? modelPath,
    required double scale,
    required double opacity,
    required int positionX,
    required int positionY,
    required int width,
    required int height,
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final state = {
        'modelPath': modelPath,
        'scale': scale,
        'opacity': opacity,
        'positionX': positionX,
        'positionY': positionY,
        'width': width,
        'height': height,
        'savedAt': DateTime.now().toIso8601String(),
      };
      await prefs.setString(_overlayStateKey, jsonEncode(state));
      live2dLog.info(_tag, '오버레이 상태 저장됨');
      return true;
    } catch (e) {
      live2dLog.error(_tag, '오버레이 상태 저장 실패', error: e);
      return false;
    }
  }
  
  /// 오버레이 상태 복원
  Future<Map<String, dynamic>?> loadOverlayState() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonString = prefs.getString(_overlayStateKey);
      
      if (jsonString != null) {
        final state = jsonDecode(jsonString) as Map<String, dynamic>;
        live2dLog.info(_tag, '오버레이 상태 복원됨');
        return state;
      }
    } catch (e) {
      live2dLog.error(_tag, '오버레이 상태 복원 실패', error: e);
    }
    return null;
  }
  
  /// 오버레이 상태 초기화
  Future<void> clearOverlayState() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_overlayStateKey);
      live2dLog.info(_tag, '오버레이 상태 초기화됨');
    } catch (e) {
      live2dLog.error(_tag, '오버레이 상태 초기화 실패', error: e);
    }
  }
  
  // ============================================================================
  // 렌더링 설정
  // ============================================================================
  
  static const String _renderSettingsKey = 'live2d_render_settings';
  
  /// 렌더링 설정 저장
  Future<bool> saveRenderSettings({
    required int targetFps,
    required bool lowPowerMode,
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final settings = {
        'targetFps': targetFps,
        'lowPowerMode': lowPowerMode,
      };
      await prefs.setString(_renderSettingsKey, jsonEncode(settings));
      return true;
    } catch (e) {
      live2dLog.error(_tag, '렌더링 설정 저장 실패', error: e);
      return false;
    }
  }
  
  /// 렌더링 설정 로드
  Future<Map<String, dynamic>> loadRenderSettings() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonString = prefs.getString(_renderSettingsKey);
      
      if (jsonString != null) {
        return jsonDecode(jsonString) as Map<String, dynamic>;
      }
    } catch (e) {
      live2dLog.error(_tag, '렌더링 설정 로드 실패', error: e);
    }
    
    // 기본값
    return {
      'targetFps': 60,
      'lowPowerMode': false,
    };
  }
}
