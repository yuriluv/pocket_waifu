// ============================================================================
// ============================================================================
// ============================================================================

import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/display_config.dart';
import '../models/live2d_settings.dart';
import '../models/display_preset.dart';
import 'live2d_log_service.dart';

class Live2DDisplayConfigStore {
  static const String _prefsKey = 'live2d_display_configs';
  static const String _tag = 'DisplayConfigStore';

  static final Live2DDisplayConfigStore _instance =
      Live2DDisplayConfigStore._internal();
  factory Live2DDisplayConfigStore() => _instance;
  Live2DDisplayConfigStore._internal();

  Map<String, Live2DDisplayConfig> _cache = {};

  Future<Map<String, Live2DDisplayConfig>> _loadAll() async {
    if (_cache.isNotEmpty) return _cache;
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonString = prefs.getString(_prefsKey);
      if (jsonString == null) return {};
      final decoded = jsonDecode(jsonString) as List<dynamic>;
      final result = <String, Live2DDisplayConfig>{};
      for (final item in decoded) {
        if (item is Map<String, dynamic>) {
          final config = Live2DDisplayConfig.fromJson(item);
          if (config.isValid) {
            result[config.modelId] = config;
          }
        }
      }
      _cache = result;
    } catch (e) {
      live2dLog.error(_tag, '디스플레이 설정 로드 실패', error: e);
    }
    return _cache;
  }

  Future<Live2DDisplayConfig?> loadForModel(String modelId) async {
    final all = await _loadAll();
    return all[modelId];
  }

  Future<bool> save(Live2DDisplayConfig config) async {
    try {
      final all = await _loadAll();
      all[config.modelId] = config;
      _cache = all;
      final prefs = await SharedPreferences.getInstance();
      final jsonString = jsonEncode(all.values.map((e) => e.toJson()).toList());
      await prefs.setString(_prefsKey, jsonString);
      return true;
    } catch (e) {
      live2dLog.error(_tag, '디스플레이 설정 저장 실패', error: e);
      return false;
    }
  }

  Future<void> deleteForModel(String modelId) async {
    try {
      final all = await _loadAll();
      all.remove(modelId);
      _cache = all;
      final prefs = await SharedPreferences.getInstance();
      final jsonString = jsonEncode(all.values.map((e) => e.toJson()).toList());
      await prefs.setString(_prefsKey, jsonString);
    } catch (e) {
      live2dLog.error(_tag, '디스플레이 설정 삭제 실패', error: e);
    }
  }

  Future<Live2DDisplayConfig> migrateLegacy({
    required String modelId,
    Live2DSettings? settings,
    DisplayPreset? linkedPreset,
  }) async {
    final sourceSettings = settings ?? await Live2DSettings.load();
    final baseScale = linkedPreset?.relativeCharacterScale ??
        sourceSettings.relativeCharacterScale;

    final config = Live2DDisplayConfig(
      modelId: modelId,
      modelPath: sourceSettings.selectedModelPath,
      containerWidthDp: (linkedPreset?.overlayWidth ??
              sourceSettings.overlayWidth)
          .toDouble(),
      containerHeightDp: (linkedPreset?.overlayHeight ??
              sourceSettings.overlayHeight)
          .toDouble(),
      containerXRatio: sourceSettings.positionX,
      containerYRatio: sourceSettings.positionY,
      containerWidthRatio: 0.3,
      containerHeightRatio: 0.4,
      modelScaleX: baseScale,
      modelScaleY: baseScale,
      modelOffsetXRatio: 0.0,
      modelOffsetYRatio: 0.0,
      modelOffsetXDp: linkedPreset?.characterOffsetX ??
          sourceSettings.characterOffsetX,
      modelOffsetYDp: linkedPreset?.characterOffsetY ??
          sourceSettings.characterOffsetY,
      relativeScaleRatio: baseScale,
      rotationDeg: linkedPreset?.characterRotation ??
          sourceSettings.characterRotation,
    );

    await save(config);
    live2dLog.info(_tag, '레거시 설정 마이그레이션 완료', details: modelId);
    return config;
  }

  void clearCache() {
    _cache = {};
  }
}
