import 'dart:convert';
import 'dart:math';

import 'package:shared_preferences/shared_preferences.dart';

import '../../domain/entities/interaction_event.dart';
import '../models/gesture_motion_mapping.dart';
import 'live2d_log_service.dart';
import 'live2d_native_bridge.dart';

class GestureMotionMapper {
  GestureMotionMapper._internal();

  static final GestureMotionMapper _instance = GestureMotionMapper._internal();
  factory GestureMotionMapper() => _instance;

  static const String _tag = 'GestureMotionMapper';
  static const String _storageKey = 'live2d_gesture_mapping_config_json';

  final Live2DNativeBridge _bridge = Live2DNativeBridge();
  final Random _random = Random();

  GestureMotionConfig _config = GestureMotionConfig.defaults();
  bool _initialized = false;

  GestureMotionConfig get config => _config;

  Future<void> initialize() async {
    if (_initialized) {
      return;
    }
    _config = await loadConfig();
    _bridge.addEventHandler(_handleInteractionEvent);
    _initialized = true;
    live2dLog.info(_tag, 'Gesture motion mapper initialized');
  }

  void dispose() {
    if (!_initialized) {
      return;
    }
    _bridge.removeEventHandler(_handleInteractionEvent);
    _initialized = false;
  }

  Future<GestureMotionConfig> loadConfig() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_storageKey);
    if (raw == null || raw.isEmpty) {
      _config = GestureMotionConfig.defaults();
      return _config;
    }

    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map<String, dynamic>) {
        _config = GestureMotionConfig.defaults();
        return _config;
      }
      _config = GestureMotionConfig.fromJson(decoded);
      return _config;
    } catch (e) {
      live2dLog.warning(
        _tag,
        'Failed to parse gesture mapping config; using defaults',
        error: e,
      );
      _config = GestureMotionConfig.defaults();
      return _config;
    }
  }

  Future<void> saveConfig(GestureMotionConfig config) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_storageKey, jsonEncode(config.toJson()));
    _config = config;
  }

  Future<void> setConfig(GestureMotionConfig config) async {
    await saveConfig(config);
  }

  Future<void> handleGesture(InteractionType gesture) async {
    final entries = _config
        .entriesFor(gesture)
        .where((entry) => entry.enabled)
        .toList(growable: false);
    if (entries.isEmpty) {
      return;
    }

    final randomMode = _config.randomEnabled(gesture);
    final GestureMotionEntry selected;
    if (randomMode) {
      selected = entries[_random.nextInt(entries.length)];
    } else {
      final sorted = entries.toList(growable: false)
        ..sort((a, b) => b.priority.compareTo(a.priority));
      selected = sorted.first;
    }

    try {
      await _bridge.playMotion(selected.motionGroup, selected.motionIndex);
      if (selected.expressionOverride != null && selected.expressionOverride!.isNotEmpty) {
        await _bridge.setExpression(selected.expressionOverride!);
      }
    } catch (e) {
      live2dLog.warning(_tag, 'Failed to dispatch mapped gesture motion', error: e);
    }
  }

  bool isSupportedGesture(InteractionType type) {
    return GestureMotionConfig.supportedGestures.contains(type);
  }

  void _handleInteractionEvent(InteractionEvent event) {
    if (!isSupportedGesture(event.type)) {
      return;
    }
    handleGesture(event.type);
  }
}
