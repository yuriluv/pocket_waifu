import 'dart:async';
import 'dart:math';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/auto_motion_config.dart';
import '../models/model3_data.dart';
import 'live2d_log_service.dart';
import 'live2d_native_bridge.dart';

class AutoMotionService {
  static final AutoMotionService _instance = AutoMotionService._internal();
  factory AutoMotionService() => _instance;
  AutoMotionService._internal();

  static const String _tag = 'AutoMotionService';
  static const String _prefix = 'live2d_auto_motion_';

  static const String _keyEnabled = '${_prefix}enabled';
  static const String _keyMotionGroup = '${_prefix}motion_group';
  static const String _keyInterval = '${_prefix}interval_seconds';
  static const String _keyRandomMode = '${_prefix}random_mode';
  static const String _keyAutoExpression = '${_prefix}auto_expression';
  static const String _keyExpressionSelection = '${_prefix}expression_selection';
  static const String _keyEyeBlinkEnabled = '${_prefix}eye_blink_enabled';
  static const String _keyEyeBlinkInterval = '${_prefix}eye_blink_interval';
  static const String _keyBreathEnabled = '${_prefix}breath_enabled';
  static const String _keyBreathCycle = '${_prefix}breath_cycle';
  static const String _keyBreathWeight = '${_prefix}breath_weight';
  static const String _keyLookAtEnabled = '${_prefix}look_at_enabled';
  static const String _keyPhysicsEnabled = '${_prefix}physics_enabled';
  static const String _keyPhysicsFps = '${_prefix}physics_fps';
  static const String _keyPhysicsDelayScale = '${_prefix}physics_delay_scale';
  static const String _keyPhysicsMobilityScale = '${_prefix}physics_mobility_scale';

  final Live2DNativeBridge _bridge = Live2DNativeBridge();
  final Random _random = Random();

  Timer? _timer;
  Timer? _saveDebounce;
  AutoMotionConfig? _pendingSaveConfig;
  bool _isTicking = false;
  int _motionCursor = 0;
  int _expressionCursor = 0;
  AutoMotionConfig _config = AutoMotionConfig.defaults();
  Model3Data _modelData = Model3Data.empty;

  bool get isRunning => _timer?.isActive ?? false;
  AutoMotionConfig get config => _config;

  Future<AutoMotionConfig> loadConfig() async {
    final prefs = await SharedPreferences.getInstance();
    final loaded = AutoMotionConfig(
      enabled: prefs.getBool(_keyEnabled) ?? false,
      motionGroup: prefs.getString(_keyMotionGroup),
      intervalSeconds: (prefs.getInt(_keyInterval) ?? 10).clamp(5, 120),
      randomMode: prefs.getBool(_keyRandomMode) ?? true,
      autoExpressionChange: prefs.getBool(_keyAutoExpression) ?? false,
      expressionSelection: prefs.getString(_keyExpressionSelection),
      cubismEyeBlinkEnabled: prefs.getBool(_keyEyeBlinkEnabled) ?? true,
      eyeBlinkIntervalSeconds: (prefs.getDouble(_keyEyeBlinkInterval) ?? 3.0)
          .clamp(0.5, 12.0),
      cubismBreathEnabled: prefs.getBool(_keyBreathEnabled) ?? true,
      breathCycleSeconds: (prefs.getDouble(_keyBreathCycle) ?? 3.2)
          .clamp(1.0, 12.0),
      breathWeight: (prefs.getDouble(_keyBreathWeight) ?? 1.0)
          .clamp(0.0, 2.0),
      lookAtEnabled: prefs.getBool(_keyLookAtEnabled) ?? true,
      physicsEnabled: prefs.getBool(_keyPhysicsEnabled) ?? true,
      physicsFps: (prefs.getInt(_keyPhysicsFps) ?? 30).clamp(1, 120),
      physicsDelayScale: (prefs.getDouble(_keyPhysicsDelayScale) ?? 1.0)
          .clamp(0.1, 3.0),
      physicsMobilityScale: (prefs.getDouble(_keyPhysicsMobilityScale) ?? 1.0)
          .clamp(0.1, 3.0),
    );
    _config = loaded;
    return loaded;
  }

  Future<void> saveConfig(AutoMotionConfig config) async {
    _config = config;
    _pendingSaveConfig = config;
    _saveDebounce?.cancel();
    _saveDebounce = Timer(const Duration(milliseconds: 500), () async {
      final prefs = await SharedPreferences.getInstance();
      final pending = _pendingSaveConfig;
      if (pending == null) {
        return;
      }

      await prefs.setBool(_keyEnabled, pending.enabled);
      if (pending.motionGroup == null || pending.motionGroup!.isEmpty) {
        await prefs.remove(_keyMotionGroup);
      } else {
        await prefs.setString(_keyMotionGroup, pending.motionGroup!);
      }
      await prefs.setInt(_keyInterval, pending.intervalSeconds.clamp(5, 120));
      await prefs.setBool(_keyRandomMode, pending.randomMode);
      await prefs.setBool(_keyAutoExpression, pending.autoExpressionChange);
      if (pending.expressionSelection == null || pending.expressionSelection!.isEmpty) {
        await prefs.remove(_keyExpressionSelection);
      } else {
        await prefs.setString(_keyExpressionSelection, pending.expressionSelection!);
      }
      await prefs.setBool(_keyEyeBlinkEnabled, pending.cubismEyeBlinkEnabled);
      await prefs.setDouble(
        _keyEyeBlinkInterval,
        pending.eyeBlinkIntervalSeconds.clamp(0.5, 12.0),
      );
      await prefs.setBool(_keyBreathEnabled, pending.cubismBreathEnabled);
      await prefs.setDouble(
        _keyBreathCycle,
        pending.breathCycleSeconds.clamp(1.0, 12.0),
      );
      await prefs.setDouble(
        _keyBreathWeight,
        pending.breathWeight.clamp(0.0, 2.0),
      );
      await prefs.setBool(_keyLookAtEnabled, pending.lookAtEnabled);
      await prefs.setBool(_keyPhysicsEnabled, pending.physicsEnabled);
      await prefs.setInt(_keyPhysicsFps, pending.physicsFps.clamp(1, 120));
      await prefs.setDouble(
        _keyPhysicsDelayScale,
        pending.physicsDelayScale.clamp(0.1, 3.0),
      );
      await prefs.setDouble(
        _keyPhysicsMobilityScale,
        pending.physicsMobilityScale.clamp(0.1, 3.0),
      );

      _pendingSaveConfig = null;
    });
  }

  Future<void> applyConfig(AutoMotionConfig config, Model3Data modelData) async {
    _config = config;
    _modelData = modelData;
    await saveConfig(config);
    await _applyRuntimeBehaviorToggles(config);
    if (config.enabled) {
      start();
    } else {
      stop();
    }
  }

  void start() {
    stop();

    final group = _config.motionGroup;
    if (group == null || group.isEmpty) {
      live2dLog.warning(_tag, 'Cannot start: motion group not selected');
      return;
    }

    final motions = _modelData.motionGroups[group] ?? const <String>[];
    if (motions.isEmpty) {
      live2dLog.warning(_tag, 'Cannot start: selected motion group has no motions');
      return;
    }

    final interval = Duration(seconds: _config.intervalSeconds.clamp(5, 120));
    _timer = Timer.periodic(interval, (_) {
      _tick();
    });
    live2dLog.info(
      _tag,
      'Auto motion started',
      details: 'group=$group, interval=${_config.intervalSeconds}s',
    );
  }

  void stop() {
    if (_timer != null) {
      _timer?.cancel();
      _timer = null;
      live2dLog.info(_tag, 'Auto motion stopped');
    }
  }

  void dispose() {
    _timer?.cancel();
    _timer = null;
    _saveDebounce?.cancel();
    _saveDebounce = null;
    _pendingSaveConfig = null;
  }

  Future<void> _tick() async {
    if (_isTicking) {
      return;
    }
    _isTicking = true;
    try {
      final group = _config.motionGroup;
      if (group == null || group.isEmpty) {
        return;
      }

      final motions = _modelData.motionGroups[group] ?? const <String>[];
      if (motions.isEmpty) {
        return;
      }

      final motionIndex = _nextMotionIndex(motions.length);
      await _bridge.playMotion(group, motionIndex);

      if (_config.autoExpressionChange && _modelData.expressions.isNotEmpty) {
        final expression = _nextExpressionName();
        if (expression != null && expression.isNotEmpty) {
          await _bridge.setExpression(expression);
        }
      }
    } catch (e, stack) {
      live2dLog.error(
        _tag,
        'Auto motion tick failed',
        error: e,
        stackTrace: stack,
      );
    } finally {
      _isTicking = false;
    }
  }

  int _nextMotionIndex(int motionCount) {
    if (motionCount <= 1) {
      return 0;
    }
    if (_config.randomMode) {
      return _random.nextInt(motionCount);
    }

    final next = _motionCursor % motionCount;
    _motionCursor += 1;
    return next;
  }

  String? _nextExpressionName() {
    final selected = _config.expressionSelection;
    if (selected != null && selected.isNotEmpty) {
      return selected;
    }

    if (_modelData.expressions.isEmpty) {
      return null;
    }

    if (_config.randomMode) {
      return _modelData.expressions[_random.nextInt(_modelData.expressions.length)]
          .name;
    }

    final next = _modelData.expressions[_expressionCursor % _modelData.expressions.length]
        .name;
    _expressionCursor += 1;
    return next;
  }

  Future<void> _applyRuntimeBehaviorToggles(AutoMotionConfig config) async {
    await _bridge.setEyeBlink(config.cubismEyeBlinkEnabled);
    await _bridge.setEyeBlinkInterval(config.eyeBlinkIntervalSeconds);
    await _bridge.setBreathing(config.cubismBreathEnabled);
    await _bridge.setBreathConfig(
      cycleSeconds: config.breathCycleSeconds,
      weight: config.breathWeight,
    );
    await _bridge.setLookAt(config.lookAtEnabled);
    await _bridge.setPhysicsEnabled(config.physicsEnabled);
    await _bridge.setPhysicsConfig(
      fps: config.physicsFps,
      delayScale: config.physicsDelayScale,
      mobilityScale: config.physicsMobilityScale,
    );
  }
}
