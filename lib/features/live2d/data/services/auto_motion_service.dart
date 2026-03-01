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

  final Live2DNativeBridge _bridge = Live2DNativeBridge();
  final Random _random = Random();

  Timer? _timer;
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
    );
    _config = loaded;
    return loaded;
  }

  Future<void> saveConfig(AutoMotionConfig config) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyEnabled, config.enabled);
    if (config.motionGroup == null || config.motionGroup!.isEmpty) {
      await prefs.remove(_keyMotionGroup);
    } else {
      await prefs.setString(_keyMotionGroup, config.motionGroup!);
    }
    await prefs.setInt(_keyInterval, config.intervalSeconds.clamp(5, 120));
    await prefs.setBool(_keyRandomMode, config.randomMode);
    await prefs.setBool(_keyAutoExpression, config.autoExpressionChange);
    if (config.expressionSelection == null || config.expressionSelection!.isEmpty) {
      await prefs.remove(_keyExpressionSelection);
    } else {
      await prefs.setString(_keyExpressionSelection, config.expressionSelection!);
    }
    _config = config;
  }

  Future<void> applyConfig(AutoMotionConfig config, Model3Data modelData) async {
    _config = config;
    _modelData = modelData;
    await saveConfig(config);
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
}
