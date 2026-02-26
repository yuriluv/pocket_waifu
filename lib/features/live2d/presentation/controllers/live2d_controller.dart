// ============================================================================
// ============================================================================
// ============================================================================

import 'package:flutter/foundation.dart';
import '../../data/models/live2d_model_info.dart';
import '../../data/models/live2d_settings.dart';
import '../../data/models/display_preset.dart';
import '../../data/repositories/live2d_repository.dart';
import '../../data/services/live2d_log_service.dart';
import '../../data/services/live2d_storage_service.dart';
import '../../data/services/live2d_native_bridge.dart';
import '../../data/services/interaction_manager.dart';

enum Live2DControllerState {
  initial,
  loading,
  ready,
  error,
}

class Live2DController extends ChangeNotifier {
  static const String _tag = 'Controller';

  final Live2DRepository _repository = Live2DRepository();
  final Live2DStorageService _storageService = Live2DStorageService();
  final Live2DNativeBridge _nativeBridge = Live2DNativeBridge();
  final InteractionManager _interactionManager = InteractionManager();

  Live2DControllerState _state = Live2DControllerState.initial;
  Live2DSettings _settings = Live2DSettings.defaults();
  String? _errorMessage;
  List<DisplayPreset> _presets = [];

  Live2DControllerState get state => _state;
  Live2DSettings get settings => _settings;
  String? get errorMessage => _errorMessage;
  bool get isLoading => _state == Live2DControllerState.loading;
  bool get isReady => _state == Live2DControllerState.ready;
  bool get hasError => _state == Live2DControllerState.error;

  List<DisplayPreset> get presets => _presets;

  List<Live2DModelInfo> get models => _repository.models;
  int get modelCount => _repository.modelCount;
  bool get hasModels => _repository.hasModels;

  Live2DModelInfo? get selectedModel {
    if (_settings.selectedModelId == null) return null;
    return _repository.getModelById(_settings.selectedModelId!);
  }

  bool get hasFolderSelected => _storageService.hasFolderSelected;
  String? get folderPath => _storageService.currentFolderPath;
  String? get folderDisplayName => _storageService.folderDisplayName;

  bool get isOverlayVisible => _settings.isEnabled;
  bool get isEnabled => _settings.isEnabled;
  
  InteractionManager get interactionManager => _interactionManager;

  Future<bool> get hasOverlayPermission => _nativeBridge.hasOverlayPermission();
  Future<bool> get hasStoragePermission => _nativeBridge.hasStoragePermission();

  Future<void> initialize() async {
    if (_state == Live2DControllerState.loading) return;
    
    _setState(Live2DControllerState.loading);
    live2dLog.info(_tag, '컨트롤러 초기화 시작');

    try {
      await _nativeBridge.initialize();
      
      _interactionManager.initialize();
      
      _settings = await Live2DSettings.load();
      live2dLog.debug(_tag, '설정 로드됨', details: _settings.toString());

      _storageService.restoreFromSettings(_settings);

      _nativeBridge.setStateSyncCallback(_handleNativeStateSync);

      await _syncOverlayStateFromNative();

      if (_storageService.hasFolderSelected) {
        final isValid = await _storageService.validateCurrentFolder();
        
        if (!isValid) {
          _settings = _settings.copyWith(clearDataFolder: true, clearSelectedModel: true);
          await _settings.save();
          live2dLog.warning(_tag, '저장된 폴더가 유효하지 않아 초기화됨');
        } else {
          await _scanModels();
          
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
      
      _presets = await DisplayPresetManager.loadAll();
      
      live2dLog.info(_tag, '컨트롤러 초기화 완료');
    } catch (e, stack) {
      _setError('초기화 실패: $e');
      live2dLog.error(_tag, '초기화 실패', error: e, stackTrace: stack);
    }
  }

  Future<bool> selectFolder() async {
    live2dLog.info(_tag, '폴더 선택 시작');

    try {
      final folderPath = await _storageService.pickFolder();
      
      if (folderPath == null) {
        live2dLog.info(_tag, '폴더 선택 취소됨');
        return false;
      }

      _settings = _settings.copyWith(
        dataFolderPath: folderPath,
        dataFolderUri: folderPath,
        clearSelectedModel: true,
      );
      await _settings.save();

      await _scanModels();

      notifyListeners();
      return true;
    } catch (e, stack) {
      live2dLog.error(_tag, '폴더 선택 실패', error: e, stackTrace: stack);
      return false;
    }
  }

  Future<void> clearFolder() async {
    live2dLog.info(_tag, '폴더 초기화');

    if (_settings.isEnabled) {
      await setEnabled(false);
    }

    _storageService.clearFolder();

    _repository.clearCache();

    _settings = _settings.copyWith(
      clearDataFolder: true,
      clearSelectedModel: true,
      isEnabled: false,
    );
    await _settings.save();

    notifyListeners();
  }

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

  Future<void> refreshModels() async {
    if (!_storageService.hasFolderSelected) {
      live2dLog.warning(_tag, '폴더가 선택되지 않음');
      return;
    }

    _setState(Live2DControllerState.loading);
    
    await _scanModels();
    
    if (_settings.selectedModelId != null) {
      final model = _repository.getModelById(_settings.selectedModelId!);
      if (model == null) {
        _settings = _settings.copyWith(clearSelectedModel: true);
        await _settings.save();
      }
    }

    _setState(Live2DControllerState.ready);
  }

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

    if (model != null) {
      final folderName = model.relativePath.split('/').first;
      final linkedPreset = await DisplayPresetManager.findLinkedPresetForModel(
        folderName, model.id,
      );
      if (linkedPreset != null) {
        live2dLog.info(_tag, '링크된 프리셋 적용', details: linkedPreset.name);
        await loadPreset(linkedPreset);
      }
    }

    if (_settings.isEnabled && model != null) {
      await _loadModelToOverlay(model);
    }

    notifyListeners();
  }

  Future<void> setScale(double scale) async {
    _settings = _settings.copyWith(scale: scale);
    await _nativeBridge.setScale(scale);
    await _settings.save();
    notifyListeners();
  }

  Future<void> setOpacity(double opacity) async {
    _settings = _settings.copyWith(opacity: opacity);
    await _nativeBridge.setCharacterOpacity(opacity);
    await _settings.save();
    notifyListeners();
  }

  Future<void> setTouchThroughEnabled(bool enabled) async {
    _settings = _settings.copyWith(touchThroughEnabled: enabled);
    await _nativeBridge.setTouchThroughEnabled(enabled);
    await _settings.save();
    notifyListeners();
  }

  Future<void> setTouchThroughAlpha(int alpha) async {
    _settings = _settings.copyWith(touchThroughAlpha: alpha);
    await _nativeBridge.setTouchThroughAlpha(alpha);
    await _settings.save();
    notifyListeners();
  }

  Future<void> setPosition(double x, double y) async {
    _settings = _settings.copyWith(positionX: x, positionY: y);
    await _nativeBridge.setPosition(x, y);
    await _settings.save();
    notifyListeners();
  }

  Future<void> resetPosition() async {
    _settings = _settings.copyWith(
      positionX: 0.5,
      positionY: 0.5,
    );
    await _settings.save();
    await _nativeBridge.setPosition(0.5, 0.5);
    notifyListeners();
  }

  Future<void> setEditMode(bool enabled) async {
    _settings = _settings.copyWith(editModeEnabled: enabled);
    await _nativeBridge.setEditMode(enabled);
    if (!enabled) {
      _settings = _settings.copyWith(characterPinned: false);
      await _nativeBridge.setCharacterPinned(false);
    }
    await _settings.save();
    notifyListeners();
  }

  Future<void> setCharacterPinned(bool enabled) async {
    _settings = _settings.copyWith(characterPinned: enabled);
    await _nativeBridge.setCharacterPinned(enabled);
    await _settings.save();
    notifyListeners();
  }

  Future<void> setRelativeCharacterScale(double scale) async {
    _settings = _settings.copyWith(relativeCharacterScale: scale);
    await _nativeBridge.setRelativeScale(scale);
    await _settings.save();
    notifyListeners();
  }

  Future<void> setCharacterOffset(double x, double y) async {
    _settings = _settings.copyWith(characterOffsetX: x, characterOffsetY: y);
    await _nativeBridge.setCharacterOffset(x, y);
    await _settings.save();
    notifyListeners();
  }

  Future<void> setCharacterRotation(int degrees) async {
    _settings = _settings.copyWith(characterRotation: degrees);
    await _nativeBridge.setCharacterRotation(degrees);
    await _settings.save();
    notifyListeners();
  }

  // ============================================================================
  // ============================================================================

  Future<void> loadPresets() async {
    _presets = await DisplayPresetManager.loadAll();
    notifyListeners();
  }

  /// 
  Future<void> savePreset(String name) async {
    final overlaySize = await _nativeBridge.getOverlaySize();
    final currentWidth = overlaySize['width'] ?? _settings.overlayWidth;
    final currentHeight = overlaySize['height'] ?? _settings.overlayHeight;
    
    _settings = _settings.copyWith(
      overlayWidth: currentWidth,
      overlayHeight: currentHeight,
    );
    await _settings.save();
    
    final preset = DisplayPreset(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      name: name,
      relativeCharacterScale: _settings.relativeCharacterScale,
      characterOffsetX: _settings.characterOffsetX,
      characterOffsetY: _settings.characterOffsetY,
      characterRotation: _settings.characterRotation,
      overlayWidth: currentWidth,
      overlayHeight: currentHeight,
      positionX: _settings.positionX,
      positionY: _settings.positionY,
      scale: _settings.scale,
    );
    await DisplayPresetManager.add(preset);
    _presets = await DisplayPresetManager.loadAll();
    live2dLog.info(_tag, '프리셋 저장됨', details: 'name=$name, overlaySize=${currentWidth}x$currentHeight');
    notifyListeners();
  }

  /// 
  Future<void> loadPreset(DisplayPreset preset) async {
    _settings = _settings.copyWith(
      relativeCharacterScale: preset.relativeCharacterScale,
      characterOffsetX: preset.characterOffsetX,
      characterOffsetY: preset.characterOffsetY,
      characterRotation: preset.characterRotation,
      overlayWidth: preset.overlayWidth,
      overlayHeight: preset.overlayHeight,
      scale: preset.scale,
      positionX: preset.positionX,
      positionY: preset.positionY,
    );
    await _settings.save();
    
    await _nativeBridge.setSize(preset.overlayWidth, preset.overlayHeight);
    await _nativeBridge.setRelativeScale(preset.relativeCharacterScale);
    await _nativeBridge.setCharacterOffset(preset.characterOffsetX, preset.characterOffsetY);
    await _nativeBridge.setCharacterRotation(preset.characterRotation);
    await _nativeBridge.setScale(preset.scale);
    await _nativeBridge.setPosition(preset.positionX, preset.positionY);
    
    live2dLog.info(_tag, '프리셋 불러옴', details: 'name=${preset.name}, overlaySize=${preset.overlayWidth}x${preset.overlayHeight}');
    notifyListeners();
  }

  Future<void> deletePreset(String presetId) async {
    await DisplayPresetManager.delete(presetId);
    _presets = await DisplayPresetManager.loadAll();
    notifyListeners();
  }

  Future<void> linkPresetToModel(String presetId, String modelFolder, String? modelId) async {
    final index = _presets.indexWhere((p) => p.id == presetId);
    if (index < 0) return;
    final updated = _presets[index].copyWith(
      linkedModelFolder: modelFolder,
      linkedModelId: modelId,
    );
    await DisplayPresetManager.update(updated);
    _presets = await DisplayPresetManager.loadAll();
    notifyListeners();
  }

  Future<void> unlinkPreset(String presetId) async {
    final index = _presets.indexWhere((p) => p.id == presetId);
    if (index < 0) return;
    final updated = _presets[index].copyWith(clearLink: true);
    await DisplayPresetManager.update(updated);
    _presets = await DisplayPresetManager.loadAll();
    notifyListeners();
  }

  Future<bool> setEnabled(bool enabled) async {
    live2dLog.info(_tag, '플로팅 뷰어 ${enabled ? '활성화' : '비활성화'} 요청');

    if (enabled) {
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

      final overlayShown = await _nativeBridge.showOverlay();
      if (!overlayShown) {
        _setError('오버레이 표시 실패');
        return false;
      }

      await _nativeBridge.setScale(_settings.scale);
      await _nativeBridge.setCharacterOpacity(_settings.opacity);
      await _nativeBridge.setTouchThroughEnabled(_settings.touchThroughEnabled);
      await _nativeBridge.setTouchThroughAlpha(_settings.touchThroughAlpha);
      await _nativeBridge.setEditMode(_settings.editModeEnabled);
      
      await _nativeBridge.setRelativeScale(_settings.relativeCharacterScale);
      await _nativeBridge.setCharacterOffset(_settings.characterOffsetX, _settings.characterOffsetY);
      await _nativeBridge.setCharacterRotation(_settings.characterRotation);

      await _loadModelToOverlay(selectedModel!);

      _settings = _settings.copyWith(isEnabled: true);
      await _settings.save();
      
      live2dLog.info(_tag, '플로팅 뷰어 활성화됨 (Native)');
    } else {
      await _nativeBridge.hideOverlay();

      _settings = _settings.copyWith(isEnabled: false, editModeEnabled: false);
      await _settings.save();
      
      live2dLog.info(_tag, '플로팅 뷰어 비활성화됨');
    }

    notifyListeners();
    return true;
  }

  Future<bool> toggleEnabled() async {
    return setEnabled(!_settings.isEnabled);
  }

  Future<bool> requestOverlayPermission() async {
    return _nativeBridge.requestOverlayPermission();
  }

  Future<bool> requestStoragePermission() async {
    return _nativeBridge.requestStoragePermission();
  }

  Future<void> _loadModelToOverlay(Live2DModelInfo model) async {
    await _nativeBridge.loadModel(model.modelFilePath);
  }

  void _setState(Live2DControllerState newState) {
    _state = newState;
    _errorMessage = null;
    notifyListeners();
  }

  void _setError(String message) {
    _state = Live2DControllerState.error;
    _errorMessage = message;
    live2dLog.error(_tag, message);
    notifyListeners();
  }

  void clearError() {
    if (_state == Live2DControllerState.error) {
      _state = Live2DControllerState.ready;
      _errorMessage = null;
      notifyListeners();
    }
  }

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
