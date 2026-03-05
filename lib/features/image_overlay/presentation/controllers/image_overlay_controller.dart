import 'package:flutter/foundation.dart';

import '../../../live2d/data/models/live2d_settings.dart';
import '../../../live2d/data/services/live2d_native_bridge.dart';
import '../../../../providers/settings_provider.dart';
import '../../data/models/image_overlay_character.dart';
import '../../data/models/image_overlay_preset.dart';
import '../../data/models/image_overlay_settings.dart';
import '../../data/services/image_overlay_native_bridge.dart';
import '../../data/services/image_overlay_storage_service.dart';

enum ImageOverlayControllerState { initial, loading, ready, error }

class ImageOverlayController extends ChangeNotifier {
  final Live2DNativeBridge _live2dBridge = Live2DNativeBridge();
  final ImageOverlayNativeBridge _imageBridge =
      ImageOverlayNativeBridge.instance;
  final ImageOverlayStorageService _storage =
      ImageOverlayStorageService.instance;
  final SettingsProvider? _settingsProvider;

  ImageOverlayController({SettingsProvider? settingsProvider})
    : _settingsProvider = settingsProvider;

  ImageOverlayControllerState _state = ImageOverlayControllerState.initial;
  ImageOverlaySettings _settings = const ImageOverlaySettings();
  List<ImageOverlayCharacter> _characters = const [];
  List<ImageOverlayPreset> _presets = const [];
  String? _errorMessage;
  bool _hitboxEditMode = false;

  ImageOverlayControllerState get state => _state;
  ImageOverlaySettings get settings => _settings;
  List<ImageOverlayCharacter> get characters => _characters;
  List<ImageOverlayPreset> get presets => _presets;
  bool get hitboxEditMode => _hitboxEditMode;
  bool get isBasicOverlayMode =>
      _settings.overlayInteractionMode == ImageOverlaySettings.overlayModeBasic;
  bool get isAdvancedOverlayMode => !isBasicOverlayMode;
  bool get isLoading => _state == ImageOverlayControllerState.loading;
  String? get errorMessage => _errorMessage;

  bool get hasFolderSelected => _storage.hasFolderSelected;
  String? get folderPath => _storage.rootPath;

  ImageOverlayCharacter? get selectedCharacter {
    final selected = _settings.selectedCharacterFolder;
    if (selected == null) {
      return null;
    }
    for (final c in _characters) {
      if (c.folderPath == selected) {
        return c;
      }
    }
    return null;
  }

  ImageOverlayEmotion? get selectedEmotion {
    final selected = _settings.selectedEmotionFile;
    if (selected == null) {
      return null;
    }
    final character = selectedCharacter;
    if (character == null) {
      return null;
    }
    for (final emotion in character.emotions) {
      if (emotion.filePath == selected) {
        return emotion;
      }
    }
    return null;
  }

  Future<void> initialize() async {
    _setState(ImageOverlayControllerState.loading);
    try {
      _settings = await ImageOverlaySettings.load();
      _storage.restoreRootPath(_settings.dataFolderPath);
      _characters = await _storage.scanCharacters();
      _presets = await ImageOverlayPresetStore.loadAll();
      _settings = _sanitizeSelection(_settings);

      if (_settings.isEnabled) {
        await _ensureImageOverlayVisible();
      }

      _setState(ImageOverlayControllerState.ready);
      notifyListeners();
    } catch (e) {
      _errorMessage = '이미지 오버레이 초기화 실패: $e';
      _setState(ImageOverlayControllerState.error);
    }
  }

  Future<void> refreshCharacters() async {
    _characters = await _storage.scanCharacters();
    _settings = _sanitizeSelection(_settings);
    await _settings.save();
    notifyListeners();
  }

  Future<void> pickFolder() async {
    final picked = await _storage.pickRootFolder();
    if (picked == null) {
      return;
    }
    _characters = await _storage.scanCharacters();
    _settings = _settings.copyWith(
      dataFolderPath: picked,
      clearSelection: _characters.isEmpty,
    );
    if (_characters.isNotEmpty) {
      final first = _characters.first;
      _settings = _settings.copyWith(
        selectedCharacterFolder: first.folderPath,
        selectedEmotionFile: first.emotions.first.filePath,
      );
    }
    await _settings.save();
    if (_settings.syncCharacterNameWithSession && _characters.isNotEmpty) {
      await _syncCharacterNameToApp(_characters.first.name);
    }
    if (_settings.isEnabled) {
      await _ensureImageOverlayVisible();
    }
    notifyListeners();
  }

  Future<void> clearFolder() async {
    await setEnabled(false);
    _storage.clear();
    _characters = const [];
    _settings = _settings.copyWith(clearDataFolder: true, clearSelection: true);
    await _settings.save();
    notifyListeners();
  }

  Future<void> selectCharacter(ImageOverlayCharacter? character) async {
    if (character == null) {
      _settings = _settings.copyWith(clearSelection: true);
      await _settings.save();
      notifyListeners();
      return;
    }

    final linkedPreset = _findLinkedPreset(character.folderPath);
    if (linkedPreset != null) {
      await loadPreset(linkedPreset);
    }

    _settings = _settings.copyWith(
      selectedCharacterFolder: character.folderPath,
      selectedEmotionFile: character.emotions.isNotEmpty
          ? character.emotions.first.filePath
          : null,
    );
    await _settings.save();

    if (_settings.syncCharacterNameWithSession) {
      await _syncCharacterNameToApp(character.name);
    }

    if (_settings.isEnabled && _settings.selectedEmotionFile != null) {
      await _imageBridge.loadOverlayImage(_settings.selectedEmotionFile!);
    }
    notifyListeners();
  }

  Future<void> selectEmotion(ImageOverlayEmotion emotion) async {
    _settings = _settings.copyWith(selectedEmotionFile: emotion.filePath);
    await _settings.save();
    if (_settings.isEnabled) {
      await _imageBridge.loadOverlayImage(emotion.filePath);
    }
    notifyListeners();
  }

  Future<bool> renameEmotion(
    ImageOverlayEmotion emotion,
    String nextName,
  ) async {
    final ok = await _storage.renameEmotionFile(
      originalPath: emotion.filePath,
      nextName: nextName,
    );
    if (!ok) {
      return false;
    }
    await refreshCharacters();
    if (_settings.isEnabled && _settings.selectedEmotionFile != null) {
      await _imageBridge.loadOverlayImage(_settings.selectedEmotionFile!);
    }
    return true;
  }

  Future<void> setOpacity(double value) async {
    _settings = _settings.copyWith(opacity: value);
    await _settings.save();
    await _live2dBridge.setCharacterOpacity(_settings.opacity);
    notifyListeners();
  }

  Future<void> setTouchThroughEnabled(bool enabled) async {
    _settings = _settings.copyWith(touchThroughEnabled: enabled);
    await _settings.save();
    await _live2dBridge.setTouchThroughEnabled(enabled);
    notifyListeners();
  }

  Future<void> setTouchThroughAlpha(int alpha) async {
    _settings = _settings.copyWith(touchThroughAlpha: alpha);
    await _settings.save();
    await _live2dBridge.setTouchThroughAlpha(_settings.touchThroughAlpha);
    notifyListeners();
  }

  Future<void> setOverlaySize(int width, int height) async {
    final prevWidth = _settings.overlayWidth;
    final prevHeight = _settings.overlayHeight;

    var nextScale = _settings.imageScale;
    if (prevWidth > 0 && prevHeight > 0) {
      final widthRatio = width / prevWidth;
      final heightRatio = height / prevHeight;
      final ratio = (widthRatio + heightRatio) / 2;
      nextScale = (nextScale * ratio).clamp(
        ImageOverlaySettings.minScale,
        ImageOverlaySettings.maxScale,
      );
    }

    _settings = _settings.copyWith(
      overlayWidth: width,
      overlayHeight: height,
      hitboxWidth: isBasicOverlayMode ? width : null,
      hitboxHeight: isBasicOverlayMode ? height : null,
      imageScale: nextScale,
    );
    await _settings.save();
    if (_settings.isEnabled) {
      await _applyOverlayGeometryToNative();
    }
    notifyListeners();
  }

  Future<void> setImageScale(double scale) async {
    final clampedScale = scale.clamp(
      ImageOverlaySettings.minScale,
      ImageOverlaySettings.maxScale,
    );
    final previousScale = _settings.imageScale <= 0
        ? 1.0
        : _settings.imageScale;
    final ratio = clampedScale / previousScale;

    final width = (_settings.overlayWidth * ratio).round();
    final height = (_settings.overlayHeight * ratio).round();

    _settings = _settings.copyWith(
      imageScale: clampedScale,
      overlayWidth: width,
      overlayHeight: height,
      hitboxWidth: isBasicOverlayMode ? width : null,
      hitboxHeight: isBasicOverlayMode ? height : null,
    );
    await _settings.save();
    if (_settings.isEnabled) {
      await _applyOverlayGeometryToNative();
    }
    notifyListeners();
  }

  Future<void> setOverlayInteractionMode(String mode) async {
    final normalized = mode == ImageOverlaySettings.overlayModeBasic
        ? ImageOverlaySettings.overlayModeBasic
        : ImageOverlaySettings.overlayModeAdvanced;

    if (normalized == _settings.overlayInteractionMode) {
      return;
    }

    if (normalized == ImageOverlaySettings.overlayModeBasic &&
        _hitboxEditMode) {
      _hitboxEditMode = false;
      await _live2dBridge.setCharacterPinned(false);
      await _live2dBridge.setEditMode(false);
    }

    _settings = _settings.copyWith(
      overlayInteractionMode: normalized,
      hitboxWidth: normalized == ImageOverlaySettings.overlayModeBasic
          ? _settings.overlayWidth
          : null,
      hitboxHeight: normalized == ImageOverlaySettings.overlayModeBasic
          ? _settings.overlayHeight
          : null,
    );
    await _settings.save();

    if (_settings.isEnabled) {
      await _ensureImageOverlayVisible();
    }
    notifyListeners();
  }

  Future<void> setOverlayPosition(double xRatio, double yRatio) async {
    _settings = _settings.copyWith(positionX: xRatio, positionY: yRatio);
    await _settings.save();
    if (_settings.isEnabled) {
      await _applyOverlayGeometryToNative();
    }
    notifyListeners();
  }

  Future<void> setHitboxEditMode(bool enabled) async {
    if (enabled && isBasicOverlayMode) {
      return;
    }
    _hitboxEditMode = enabled;
    await _live2dBridge.setEditMode(enabled);
    await _live2dBridge.setCharacterPinned(enabled);
    if (!enabled) {
      await syncHitboxFromRuntime();
    }
    notifyListeners();
  }

  Future<void> syncHitboxFromRuntime() async {
    final state = await _live2dBridge.getDisplayState();
    final screenWidth = _readInt(state, 'screenWidth', 0);
    final screenHeight = _readInt(state, 'screenHeight', 0);
    final containerWidth = _readInt(
      state,
      'containerWidth',
      _settings.hitboxWidth,
    );
    final containerHeight = _readInt(
      state,
      'containerHeight',
      _settings.hitboxHeight,
    );
    final containerX = _readInt(state, 'containerX', 0);
    final containerY = _readInt(state, 'containerY', 0);

    if (screenWidth <= 0 || screenHeight <= 0) {
      return;
    }

    final maxX = (screenWidth - containerWidth)
        .clamp(0, screenWidth)
        .toDouble();
    final maxY = (screenHeight - containerHeight)
        .clamp(0, screenHeight)
        .toDouble();

    final ratioX = maxX <= 0 ? 0.0 : (containerX / maxX).clamp(0.0, 1.0);
    final ratioY = maxY <= 0 ? 0.0 : (containerY / maxY).clamp(0.0, 1.0);

    _settings = _settings.copyWith(
      hitboxWidth: containerWidth,
      hitboxHeight: containerHeight,
      positionX: ratioX,
      positionY: ratioY,
    );
    await _settings.save();
  }

  Future<void> setEnabled(bool enabled) async {
    if (enabled == _settings.isEnabled) {
      return;
    }
    if (enabled) {
      final live2dSettings = await Live2DSettings.load();
      if (live2dSettings.isEnabled) {
        await live2dSettings.copyWith(isEnabled: false).save();
      }

      if (isBasicOverlayMode && _hitboxEditMode) {
        _hitboxEditMode = false;
      }

      await _ensureImageOverlayVisible();
      _settings = _settings.copyWith(isEnabled: true);
      await _settings.save();
      notifyListeners();
      return;
    }

    if (_hitboxEditMode) {
      _hitboxEditMode = false;
      await _live2dBridge.setCharacterPinned(false);
      await _live2dBridge.setEditMode(false);
    }
    await _live2dBridge.hideOverlay();
    _settings = _settings.copyWith(isEnabled: false);
    await _settings.save();
    notifyListeners();
  }

  Future<void> setSyncCharacterNameWithSession(bool enabled) async {
    _settings = _settings.copyWith(syncCharacterNameWithSession: enabled);
    await _settings.save();
    if (enabled && selectedCharacter != null) {
      await _syncCharacterNameToApp(selectedCharacter!.name);
    }
    notifyListeners();
  }

  Future<void> syncCharacterName(String characterName) async {
    if (!_settings.syncCharacterNameWithSession) {
      return;
    }
    final lowered = characterName.trim().toLowerCase();
    if (lowered.isEmpty) {
      return;
    }
    for (final character in _characters) {
      if (character.name.toLowerCase() == lowered) {
        await selectCharacter(character);
        return;
      }
    }
  }

  Future<void> savePreset(String name) async {
    await syncHitboxFromRuntime();

    final next = List<ImageOverlayPreset>.from(_presets)
      ..add(
        ImageOverlayPreset(
          id: DateTime.now().microsecondsSinceEpoch.toString(),
          name: name,
          overlayWidth: _settings.hitboxWidth,
          overlayHeight: _settings.hitboxHeight,
          positionX: _settings.positionX,
          positionY: _settings.positionY,
          imageScale: _settings.imageScale,
          linkedCharacterFolder: _settings.selectedCharacterFolder,
        ),
      );
    _presets = next;
    await ImageOverlayPresetStore.saveAll(_presets);
    notifyListeners();
  }

  Future<void> loadPreset(ImageOverlayPreset preset) async {
    ImageOverlayCharacter? linkedCharacter;
    final previousScale = _settings.imageScale <= 0
        ? 1.0
        : _settings.imageScale;
    final ratio = preset.imageScale / previousScale;
    final scaledWidth = (_settings.overlayWidth * ratio).round();
    final scaledHeight = (_settings.overlayHeight * ratio).round();

    if (preset.linkedCharacterFolder != null) {
      for (final character in _characters) {
        if (character.folderPath == preset.linkedCharacterFolder) {
          linkedCharacter = character;
          break;
        }
      }
    }

    _settings = _settings.copyWith(
      overlayWidth: scaledWidth,
      overlayHeight: scaledHeight,
      hitboxWidth: preset.overlayWidth,
      hitboxHeight: preset.overlayHeight,
      imageScale: preset.imageScale,
      positionX: preset.positionX,
      positionY: preset.positionY,
      selectedCharacterFolder: linkedCharacter?.folderPath,
      selectedEmotionFile:
          linkedCharacter != null && linkedCharacter.emotions.isNotEmpty
          ? linkedCharacter.emotions.first.filePath
          : _settings.selectedEmotionFile,
    );

    await _settings.save();

    if (_settings.isEnabled) {
      await _applyOverlayGeometryToNative();
      final selectedFile = _settings.selectedEmotionFile;
      if (selectedFile != null) {
        await _imageBridge.loadOverlayImage(selectedFile);
      }
    }
    if (_settings.syncCharacterNameWithSession && linkedCharacter != null) {
      await _syncCharacterNameToApp(linkedCharacter.name);
    }
    notifyListeners();
  }

  Future<void> deletePreset(String presetId) async {
    _presets = _presets.where((e) => e.id != presetId).toList(growable: false);
    await ImageOverlayPresetStore.saveAll(_presets);
    notifyListeners();
  }

  Future<void> linkPresetToCharacter(String presetId, String folderPath) async {
    final next = <ImageOverlayPreset>[];
    for (final preset in _presets) {
      if (preset.id == presetId) {
        next.add(preset.copyWith(linkedCharacterFolder: folderPath));
      } else {
        next.add(preset);
      }
    }
    _presets = next;
    await ImageOverlayPresetStore.saveAll(_presets);
    notifyListeners();
  }

  Future<void> unlinkPreset(String presetId) async {
    final next = <ImageOverlayPreset>[];
    for (final preset in _presets) {
      if (preset.id == presetId) {
        next.add(preset.copyWith(clearLink: true));
      } else {
        next.add(preset);
      }
    }
    _presets = next;
    await ImageOverlayPresetStore.saveAll(_presets);
    notifyListeners();
  }

  ImageOverlayPreset? _findLinkedPreset(String characterFolder) {
    for (final preset in _presets) {
      if (preset.linkedCharacterFolder == characterFolder) {
        return preset;
      }
    }
    return null;
  }

  Future<void> _ensureImageOverlayVisible() async {
    await _imageBridge.setOverlayMode(
      isBasicOverlayMode ? 'image_basic' : 'image',
    );
    await _live2dBridge.showOverlay();
    if (isBasicOverlayMode) {
      await _live2dBridge.setCharacterPinned(false);
      await _live2dBridge.setEditMode(false);
    }
    await _applyOverlayGeometryToNative();
    await _live2dBridge.setCharacterOpacity(_settings.opacity);
    await _live2dBridge.setTouchThroughEnabled(_settings.touchThroughEnabled);
    await _live2dBridge.setTouchThroughAlpha(_settings.touchThroughAlpha);
    final imagePath = _settings.selectedEmotionFile;
    if (imagePath != null) {
      await _imageBridge.loadOverlayImage(imagePath);
    }
  }

  Future<void> _applyOverlayGeometryToNative() async {
    await _live2dBridge.setSize(
      _settings.overlayWidth,
      _settings.overlayHeight,
    );
    await _live2dBridge.setHitboxSize(
      isBasicOverlayMode ? _settings.overlayWidth : _settings.hitboxWidth,
      isBasicOverlayMode ? _settings.overlayHeight : _settings.hitboxHeight,
    );

    final state = await _live2dBridge.getDisplayState();
    final screenWidth = _readInt(state, 'screenWidth', 0);
    final screenHeight = _readInt(state, 'screenHeight', 0);

    if (screenWidth <= 0 || screenHeight <= 0) {
      return;
    }

    final hitboxWidth = isBasicOverlayMode
        ? _settings.overlayWidth
        : _settings.hitboxWidth;
    final hitboxHeight = isBasicOverlayMode
        ? _settings.overlayHeight
        : _settings.hitboxHeight;
    final maxX = (screenWidth - hitboxWidth).clamp(0, screenWidth);
    final maxY = (screenHeight - hitboxHeight).clamp(0, screenHeight);
    final targetX = (maxX * _settings.positionX).round();
    final targetY = (maxY * _settings.positionY).round();

    await _live2dBridge.setPosition(targetX.toDouble(), targetY.toDouble());
  }

  Future<void> _syncCharacterNameToApp(String nextName) async {
    final provider = _settingsProvider;
    if (provider == null) {
      return;
    }
    if (provider.character.name == nextName) {
      return;
    }
    provider.setCharacterName(nextName);
  }

  int _readInt(Map<String, dynamic> source, String key, int fallback) {
    final value = source[key];
    if (value is num) {
      return value.toInt();
    }
    return fallback;
  }

  ImageOverlaySettings _sanitizeSelection(ImageOverlaySettings source) {
    final selectedFolder = source.selectedCharacterFolder;
    final selectedFile = source.selectedEmotionFile;
    if (_characters.isEmpty) {
      return source.copyWith(clearSelection: true);
    }

    ImageOverlayCharacter selectedCharacter = _characters.first;
    if (selectedFolder != null) {
      for (final character in _characters) {
        if (character.folderPath == selectedFolder) {
          selectedCharacter = character;
          break;
        }
      }
    }

    ImageOverlayEmotion selectedEmotion = selectedCharacter.emotions.first;
    if (selectedFile != null) {
      for (final emotion in selectedCharacter.emotions) {
        if (emotion.filePath == selectedFile) {
          selectedEmotion = emotion;
          break;
        }
      }
    }

    return source.copyWith(
      selectedCharacterFolder: selectedCharacter.folderPath,
      selectedEmotionFile: selectedEmotion.filePath,
    );
  }

  void _setState(ImageOverlayControllerState next) {
    _state = next;
    if (next != ImageOverlayControllerState.error) {
      _errorMessage = null;
    }
    notifyListeners();
  }
}
