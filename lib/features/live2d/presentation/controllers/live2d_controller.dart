// ============================================================================
// Live2D 컨트롤러 (Live2D Controller)
// ============================================================================
// Live2D 기능의 상태를 관리하는 컨트롤러입니다.
// Provider 패턴을 사용하여 UI와 비즈니스 로직을 분리합니다.
// v2.1: Native OpenGL 방식으로 전환
// ============================================================================

import 'package:flutter/foundation.dart';
import '../../data/models/live2d_model_info.dart';
import '../../data/models/live2d_settings.dart';
import '../../data/repositories/live2d_repository.dart';
import '../../data/services/live2d_log_service.dart';
import '../../data/services/live2d_storage_service.dart';
import '../../data/services/live2d_native_bridge.dart';
import '../../data/services/interaction_manager.dart';

/// Live2D 컨트롤러의 상태
enum Live2DControllerState {
  initial,
  loading,
  ready,
  error,
}

/// Live2D 컨트롤러 (ChangeNotifier)
class Live2DController extends ChangeNotifier {
  static const String _tag = 'Controller';

  // === 서비스 인스턴스 ===
  final Live2DRepository _repository = Live2DRepository();
  final Live2DStorageService _storageService = Live2DStorageService();
  final Live2DNativeBridge _nativeBridge = Live2DNativeBridge();
  final InteractionManager _interactionManager = InteractionManager();

  // === 상태 변수 ===
  Live2DControllerState _state = Live2DControllerState.initial;
  Live2DSettings _settings = Live2DSettings.defaults();
  String? _errorMessage;

  // === Getter: 상태 ===
  Live2DControllerState get state => _state;
  Live2DSettings get settings => _settings;
  String? get errorMessage => _errorMessage;
  bool get isLoading => _state == Live2DControllerState.loading;
  bool get isReady => _state == Live2DControllerState.ready;
  bool get hasError => _state == Live2DControllerState.error;

  // === Getter: 모델 ===
  List<Live2DModelInfo> get models => _repository.models;
  int get modelCount => _repository.modelCount;
  bool get hasModels => _repository.hasModels;

  /// 현재 선택된 모델
  Live2DModelInfo? get selectedModel {
    if (_settings.selectedModelId == null) return null;
    return _repository.getModelById(_settings.selectedModelId!);
  }

  // === Getter: 폴더 ===
  bool get hasFolderSelected => _storageService.hasFolderSelected;
  String? get folderPath => _storageService.currentFolderPath;
  String? get folderDisplayName => _storageService.folderDisplayName;

  // === Getter: 오버레이 (Native) ===
  bool get isOverlayVisible => _settings.isEnabled;  // Native 상태 추적
  bool get isEnabled => _settings.isEnabled;
  
  // === Getter: 상호작용 매니저 ===
  InteractionManager get interactionManager => _interactionManager;

  // === Getter: 권한 (Native 브릿지 통해 확인) ===
  Future<bool> get hasOverlayPermission => _nativeBridge.hasOverlayPermission();
  Future<bool> get hasStoragePermission => _nativeBridge.hasStoragePermission();

  /// 초기화
  Future<void> initialize() async {
    if (_state == Live2DControllerState.loading) return;
    
    _setState(Live2DControllerState.loading);
    live2dLog.info(_tag, '컨트롤러 초기화 시작');

    try {
      // 1. Native 브릿지 초기화
      await _nativeBridge.initialize();
      
      // 2. 상호작용 매니저 초기화 (이벤트 핸들러 등록)
      _interactionManager.initialize();
      
      // 3. 설정 로드
      _settings = await Live2DSettings.load();
      live2dLog.debug(_tag, '설정 로드됨', details: _settings.toString());

      // 4. 저장소 서비스에 폴더 정보 복원
      _storageService.restoreFromSettings(_settings);

      // 5. Native 상태 동기화 콜백 등록
      _nativeBridge.setStateSyncCallback(_handleNativeStateSync);

      // 6. Native 오버레이 실제 상태 동기화
      await _syncOverlayStateFromNative();

      // 7. 폴더가 유효한지 확인
      if (_storageService.hasFolderSelected) {
        final isValid = await _storageService.validateCurrentFolder();
        
        if (!isValid) {
          // 폴더가 더 이상 유효하지 않으면 설정 초기화
          _settings = _settings.copyWith(clearDataFolder: true, clearSelectedModel: true);
          await _settings.save();
          live2dLog.warning(_tag, '저장된 폴더가 유효하지 않아 초기화됨');
        } else {
          // 모델 스캔
          await _scanModels();
          
          // 선택된 모델이 유효한지 확인
          if (_settings.selectedModelId != null) {
            final model = _repository.getModelById(_settings.selectedModelId!);
            if (model == null) {
              _settings = _settings.copyWith(clearSelectedModel: true);
              await _settings.save();
              live2dLog.warning(_tag, '선택된 모델이 더 이상 존재하지 않아 초기화됨');
            }
          }
        }
      }

      _setState(Live2DControllerState.ready);
      live2dLog.info(_tag, '컨트롤러 초기화 완료');
    } catch (e, stack) {
      _setError('초기화 실패: $e');
      live2dLog.error(_tag, '초기화 실패', error: e, stackTrace: stack);
    }
  }

  /// 폴더 선택
  Future<bool> selectFolder() async {
    live2dLog.info(_tag, '폴더 선택 시작');

    try {
      final folderPath = await _storageService.pickFolder();
      
      if (folderPath == null) {
        live2dLog.info(_tag, '폴더 선택 취소됨');
        return false;
      }

      // 설정 업데이트
      _settings = _settings.copyWith(
        dataFolderPath: folderPath,
        dataFolderUri: folderPath,
        clearSelectedModel: true, // 폴더 변경 시 모델 선택 초기화
      );
      await _settings.save();

      // 모델 스캔
      await _scanModels();

      notifyListeners();
      return true;
    } catch (e, stack) {
      live2dLog.error(_tag, '폴더 선택 실패', error: e, stackTrace: stack);
      return false;
    }
  }

  /// 폴더 초기화
  Future<void> clearFolder() async {
    live2dLog.info(_tag, '폴더 초기화');

    // 오버레이 중지
    if (_settings.isEnabled) {
      await setEnabled(false);
    }

    // 스토리지 초기화
    _storageService.clearFolder();

    // 캐시 클리어
    _repository.clearCache();

    // 설정 초기화
    _settings = _settings.copyWith(
      clearDataFolder: true,
      clearSelectedModel: true,
      isEnabled: false,
    );
    await _settings.save();

    notifyListeners();
  }

  /// 모델 스캔
  Future<void> _scanModels() async {
    final rootPath = await _storageService.getModelRootPath();
    if (rootPath == null) {
      live2dLog.warning(_tag, '모델 루트 경로 없음');
      return;
    }

    live2dLog.info(_tag, '모델 스캔 시작', details: rootPath);
    await _repository.scanModels(rootPath);
    live2dLog.info(_tag, '모델 스캔 완료', details: '${_repository.modelCount}개 발견');
  }

  /// 모델 새로고침
  Future<void> refreshModels() async {
    if (!_storageService.hasFolderSelected) {
      live2dLog.warning(_tag, '폴더가 선택되지 않음');
      return;
    }

    _setState(Live2DControllerState.loading);
    
    await _scanModels();
    
    // 선택된 모델이 여전히 유효한지 확인
    if (_settings.selectedModelId != null) {
      final model = _repository.getModelById(_settings.selectedModelId!);
      if (model == null) {
        _settings = _settings.copyWith(clearSelectedModel: true);
        await _settings.save();
      }
    }

    _setState(Live2DControllerState.ready);
  }

  /// 모델 선택
  Future<void> selectModel(Live2DModelInfo? model) async {
    if (model == null) {
      _settings = _settings.copyWith(clearSelectedModel: true);
    } else {
      _settings = _settings.copyWith(
        selectedModelId: model.id,
        selectedModelPath: model.relativePath,
      );
    }
    
    await _settings.save();
    live2dLog.info(_tag, '모델 선택됨', details: model?.name ?? 'none');

    // 오버레이가 활성화 상태면 모델 업데이트
    if (_settings.isEnabled && model != null) {
      await _loadModelToOverlay(model);
    }

    notifyListeners();
  }

  /// 크기 설정
  Future<void> setScale(double scale) async {
    _settings = _settings.copyWith(scale: scale);
    await _nativeBridge.setScale(scale);
    await _settings.save();
    notifyListeners();
  }

  /// 투명도 설정 (캐릭터 GL 시각적 투명도)
  Future<void> setOpacity(double opacity) async {
    _settings = _settings.copyWith(opacity: opacity);
    await _nativeBridge.setCharacterOpacity(opacity);
    await _settings.save();
    notifyListeners();
  }

  /// 터치스루 토글 설정
  Future<void> setTouchThroughEnabled(bool enabled) async {
    _settings = _settings.copyWith(touchThroughEnabled: enabled);
    await _nativeBridge.setTouchThroughEnabled(enabled);
    await _settings.save();
    notifyListeners();
  }

  /// 터치스루 윈도우 알파 설정 (0~100 정수)
  Future<void> setTouchThroughAlpha(int alpha) async {
    _settings = _settings.copyWith(touchThroughAlpha: alpha);
    await _nativeBridge.setTouchThroughAlpha(alpha);
    await _settings.save();
    notifyListeners();
  }

  /// 위치 설정
  Future<void> setPosition(double x, double y) async {
    _settings = _settings.copyWith(positionX: x, positionY: y);
    await _nativeBridge.setPosition(x, y);
    await _settings.save();
    notifyListeners();
  }

  /// 위치 초기화
  Future<void> resetPosition() async {
    _settings = _settings.copyWith(
      positionX: 0.5,
      positionY: 0.5,
    );
    await _settings.save();
    await _nativeBridge.setPosition(0.5, 0.5);
    notifyListeners();
  }

  /// 편집 모드 설정
  Future<void> setEditMode(bool enabled) async {
    _settings = _settings.copyWith(editModeEnabled: enabled);
    await _nativeBridge.setEditMode(enabled);
    await _settings.save();
    notifyListeners();
  }

  /// 플로팅 뷰어 활성화/비활성화 (Native 방식)
  Future<bool> setEnabled(bool enabled) async {
    live2dLog.info(_tag, '플로팅 뷰어 ${enabled ? '활성화' : '비활성화'} 요청');

    if (enabled) {
      // 활성화 조건 확인
      if (!await _nativeBridge.hasOverlayPermission()) {
        live2dLog.warning(_tag, '오버레이 권한 없음');
        _setError('오버레이 권한이 필요합니다');
        return false;
      }

      if (selectedModel == null) {
        live2dLog.warning(_tag, '모델이 선택되지 않음');
        _setError('먼저 모델을 선택해주세요');
        return false;
      }

      // Native 오버레이 표시
      final overlayShown = await _nativeBridge.showOverlay();
      if (!overlayShown) {
        _setError('오버레이 표시 실패');
        return false;
      }

      // 크기, 투명도, 터치스루, 편집 모드 설정
      await _nativeBridge.setScale(_settings.scale);
      await _nativeBridge.setCharacterOpacity(_settings.opacity);
      await _nativeBridge.setTouchThroughEnabled(_settings.touchThroughEnabled);
      await _nativeBridge.setTouchThroughAlpha(_settings.touchThroughAlpha);
      await _nativeBridge.setEditMode(_settings.editModeEnabled);

      // 모델 로드
      await _loadModelToOverlay(selectedModel!);

      _settings = _settings.copyWith(isEnabled: true);
      await _settings.save();
      
      live2dLog.info(_tag, '플로팅 뷰어 활성화됨 (Native)');
    } else {
      // 비활성화
      await _nativeBridge.hideOverlay();

      _settings = _settings.copyWith(isEnabled: false, editModeEnabled: false);
      await _settings.save();
      
      live2dLog.info(_tag, '플로팅 뷰어 비활성화됨');
    }

    notifyListeners();
    return true;
  }

  /// 오버레이 토글
  Future<bool> toggleEnabled() async {
    return setEnabled(!_settings.isEnabled);
  }

  /// 오버레이 권한 요청
  Future<bool> requestOverlayPermission() async {
    return _nativeBridge.requestOverlayPermission();
  }

  /// 저장소 권한 요청
  Future<bool> requestStoragePermission() async {
    return _nativeBridge.requestStoragePermission();
  }

  /// 모델을 오버레이에 로드 (Native)
  Future<void> _loadModelToOverlay(Live2DModelInfo model) async {
    await _nativeBridge.loadModel(model.modelFilePath);
  }

  /// 상태 변경
  void _setState(Live2DControllerState newState) {
    _state = newState;
    _errorMessage = null;
    notifyListeners();
  }

  /// 에러 설정
  void _setError(String message) {
    _state = Live2DControllerState.error;
    _errorMessage = message;
    live2dLog.error(_tag, message);
    notifyListeners();
  }

  /// 에러 클리어
  void clearError() {
    if (_state == Live2DControllerState.error) {
      _state = Live2DControllerState.ready;
      _errorMessage = null;
      notifyListeners();
    }
  }

  /// Native 오버레이 실제 상태와 동기화
  Future<void> _syncOverlayStateFromNative() async {
    try {
      final isActuallyVisible = await _nativeBridge.isOverlayVisible();
      if (_settings.isEnabled != isActuallyVisible) {
        live2dLog.info(_tag, '오버레이 상태 불일치 수정',
            details: 'settings=${_settings.isEnabled}, actual=$isActuallyVisible');
        _settings = _settings.copyWith(isEnabled: isActuallyVisible);
        await _settings.save();
        notifyListeners();
      }
    } catch (e) {
      live2dLog.warning(_tag, 'Native 상태 동기화 실패', details: '$e');
    }
  }

  /// Native 상태 동기화 콜백
  void _handleNativeStateSync(Map<String, dynamic> data) {
    final isRunning = data['isRunning'] as bool? ?? false;
    if (_settings.isEnabled != isRunning) {
      live2dLog.info(_tag, '상태 동기화: isEnabled=$isRunning');
      _settings = _settings.copyWith(isEnabled: isRunning);
      _settings.save();
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _nativeBridge.setStateSyncCallback(null);
    _interactionManager.dispose();
    _nativeBridge.dispose();
    super.dispose();
  }
}
