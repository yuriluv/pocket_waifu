// ============================================================================
// Live2D 컨트롤러 (Live2D Controller)
// ============================================================================
// Live2D 기능의 상태를 관리하는 컨트롤러입니다.
// Provider 패턴을 사용하여 UI와 비즈니스 로직을 분리합니다.
// ============================================================================

import 'package:flutter/foundation.dart';
import '../../data/models/live2d_model_info.dart';
import '../../data/models/live2d_settings.dart';
import '../../data/repositories/live2d_repository.dart';
import '../../data/services/live2d_log_service.dart';
import '../../data/services/live2d_storage_service.dart';
import '../../data/services/live2d_local_server_service.dart';
import '../../data/services/live2d_overlay_service.dart';

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
  final Live2DLocalServerService _serverService = Live2DLocalServerService();
  final Live2DOverlayService _overlayService = Live2DOverlayService();

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

  // === Getter: 서버 ===
  bool get isServerRunning => _serverService.isRunning;
  String get serverUrl => _serverService.serverUrl;

  // === Getter: 오버레이 ===
  bool get isOverlayVisible => _overlayService.isOverlayVisible;
  bool get isEnabled => _settings.isEnabled;

  // === Getter: 권한 ===
  Future<bool> get hasOverlayPermission => _overlayService.hasOverlayPermission();
  Future<bool> get hasStoragePermission => _overlayService.hasStoragePermission();

  /// 초기화
  Future<void> initialize() async {
    if (_state == Live2DControllerState.loading) return;
    
    _setState(Live2DControllerState.loading);
    live2dLog.info(_tag, '컨트롤러 초기화 시작');

    try {
      // 1. 설정 로드
      _settings = await Live2DSettings.load();
      live2dLog.debug(_tag, '설정 로드됨', details: _settings.toString());

      // 2. 저장소 서비스에 폴더 정보 복원
      _storageService.restoreFromSettings(_settings);

      // 3. 폴더가 유효한지 확인
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

      // 4. 오버레이가 활성화 상태였다면 복원
      if (_settings.isEnabled && selectedModel != null) {
        await _startOverlayIfNeeded();
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

    // 서버 중지
    await _serverService.stopServer();

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
    _overlayService.setScale(scale);
    await _settings.save();
    notifyListeners();
  }

  /// 투명도 설정
  Future<void> setOpacity(double opacity) async {
    _settings = _settings.copyWith(opacity: opacity);
    _overlayService.setOpacity(opacity);
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
    await _overlayService.setPosition(0, 100);
    notifyListeners();
  }

  /// 플로팅 뷰어 활성화/비활성화
  Future<bool> setEnabled(bool enabled) async {
    live2dLog.info(_tag, '플로팅 뷰어 ${enabled ? '활성화' : '비활성화'} 요청');

    if (enabled) {
      // 활성화 조건 확인
      if (!await _overlayService.hasOverlayPermission()) {
        live2dLog.warning(_tag, '오버레이 권한 없음');
        _setError('오버레이 권한이 필요합니다');
        return false;
      }

      if (selectedModel == null) {
        live2dLog.warning(_tag, '모델이 선택되지 않음');
        _setError('먼저 모델을 선택해주세요');
        return false;
      }

      // 서버 시작
      final rootPath = await _storageService.getModelRootPath();
      if (rootPath == null) {
        _setError('모델 폴더가 설정되지 않았습니다');
        return false;
      }

      final serverStarted = await _serverService.startServer(rootPath);
      if (!serverStarted) {
        _setError('로컬 서버 시작 실패');
        return false;
      }

      // 오버레이 표시
      _overlayService.setScale(_settings.scale);
      _overlayService.setOpacity(_settings.opacity);
      
      final overlayShown = await _overlayService.showOverlay();
      if (!overlayShown) {
        _setError('오버레이 표시 실패');
        return false;
      }

      // 모델 로드
      await _loadModelToOverlay(selectedModel!);

      _settings = _settings.copyWith(isEnabled: true);
      await _settings.save();
      
      live2dLog.info(_tag, '플로팅 뷰어 활성화됨');
    } else {
      // 비활성화
      await _overlayService.hideOverlay();
      await _serverService.stopServer();

      _settings = _settings.copyWith(isEnabled: false);
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
    return _overlayService.requestOverlayPermission();
  }

  /// 저장소 권한 요청
  Future<bool> requestStoragePermission() async {
    return _overlayService.requestStoragePermission();
  }

  /// 필요시 오버레이 시작 (앱 시작시 복원용)
  Future<void> _startOverlayIfNeeded() async {
    if (!_settings.isEnabled) return;
    if (selectedModel == null) return;

    live2dLog.info(_tag, '오버레이 상태 복원 시도');
    
    try {
      // 서버 시작
      final rootPath = await _storageService.getModelRootPath();
      if (rootPath == null) return;

      await _serverService.startServer(rootPath);

      // 오버레이는 수동으로 활성화해야 함 (백그라운드에서 자동 시작 방지)
      // 사용자가 앱을 열면 토글로 활성화
      live2dLog.info(_tag, '오버레이 복원 대기 (수동 활성화 필요)');
    } catch (e) {
      live2dLog.error(_tag, '오버레이 복원 실패', error: e);
    }
  }

  /// 모델을 오버레이에 로드
  Future<void> _loadModelToOverlay(Live2DModelInfo model) async {
    final url = _serverService.getWebViewUrl(model.relativePath);
    await _overlayService.sendModelUrl(url);
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

  @override
  void dispose() {
    _overlayService.dispose();
    super.dispose();
  }
}
