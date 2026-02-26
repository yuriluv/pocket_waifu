// ============================================================================
// ============================================================================
// ============================================================================

import 'dart:async';
import 'package:flutter/services.dart';
import '../../domain/entities/interaction_event.dart';
import '../../domain/entities/interaction_response.dart';
import '../models/interaction_config.dart';
import 'live2d_native_bridge.dart';
import 'live2d_log_service.dart';

/// 
class InteractionManager {
  static const String _tag = 'InteractionManager';
  
  static final InteractionManager _instance = InteractionManager._internal();
  factory InteractionManager() => _instance;
  InteractionManager._internal();
  
  final Live2DNativeBridge _bridge = Live2DNativeBridge();
  
  InteractionConfig _config = InteractionConfig.defaults();
  InteractionConfig get config => _config;
  
  final StreamController<InteractionEvent> _eventController = 
      StreamController<InteractionEvent>.broadcast();
  
  Stream<InteractionEvent> get eventStream => _eventController.stream;
  
  final List<ExternalInteractionListener> _externalListeners = [];
  
  final Map<InteractionType, DateTime> _lastTriggerTimes = {};
  
  bool _isInitialized = false;
  String? _currentModelPath;
  
  // ============================================================================
  // ============================================================================
  
  Future<void> initialize() async {
    if (_isInitialized) return;
    
    live2dLog.info(_tag, 'InteractionManager 초기화');
    
    _bridge.addEventHandler(_handleNativeEvent);
    
    _isInitialized = true;
  }
  
  void dispose() {
    _bridge.removeEventHandler(_handleNativeEvent);
    _externalListeners.clear();
    _lastTriggerTimes.clear();
    _eventController.close();
    _isInitialized = false;
    live2dLog.info(_tag, 'InteractionManager 정리됨');
  }
  
  // ============================================================================
  // ============================================================================
  
  void updateConfig(InteractionConfig newConfig) {
    _config = newConfig;
    live2dLog.debug(_tag, '설정 업데이트됨', details: '매핑 수: ${newConfig.mappings.length}');
  }
  
  void setCurrentModel(String? modelPath) {
    _currentModelPath = modelPath;
  }
  
  // ============================================================================
  // ============================================================================
  
  void _handleNativeEvent(InteractionEvent event) {
    live2dLog.debug(_tag, '이벤트 수신', details: event.type.name);
    
    _eventController.add(event);
    
    for (final listener in _externalListeners) {
      try {
        listener.onInteraction(event);
      } catch (e) {
        live2dLog.error(_tag, '외부 리스너 오류', error: e);
      }
    }
    
    if (_config.autoReactionEnabled) {
      _processAutoReaction(event);
    }
  }
  
  Future<void> _processAutoReaction(InteractionEvent event) async {
    if (!_checkCooldown(event.type)) {
      live2dLog.debug(_tag, '쿨다운 중', details: event.type.name);
      return;
    }
    
    final mapping = _config.getMappingFor(event.type);
    if (mapping == null) {
      live2dLog.debug(_tag, '매핑 없음', details: event.type.name);
      return;
    }
    
    if (mapping.condition != null) {
      final conditionMet = mapping.condition!.evaluate(
        currentModel: _currentModelPath,
      );
      if (!conditionMet) {
        live2dLog.debug(_tag, '조건 미충족', details: event.type.name);
        return;
      }
    }
    
    _recordTrigger(event.type);
    
    await _executeResponse(mapping.response);
  }
  
  bool _checkCooldown(InteractionType type) {
    final lastTime = _lastTriggerTimes[type];
    if (lastTime == null) return true;
    
    final elapsed = DateTime.now().difference(lastTime).inMilliseconds;
    return elapsed >= _config.globalCooldownMs;
  }
  
  void _recordTrigger(InteractionType type) {
    _lastTriggerTimes[type] = DateTime.now();
  }
  
  // ============================================================================
  // ============================================================================
  
  Future<void> _executeResponse(InteractionResponse response) async {
    live2dLog.debug(_tag, '응답 실행', details: response.toString());
    
    if (response.delayMs > 0) {
      await Future.delayed(Duration(milliseconds: response.delayMs));
    }
    
    switch (response.action) {
      case ResponseAction.playMotion:
        await _executeMotion(response);
        break;
        
      case ResponseAction.setExpression:
        await _executeExpression(response);
        break;
        
      case ResponseAction.randomExpression:
        await _bridge.setRandomExpression();
        break;
        
      case ResponseAction.randomMotion:
        await _executeRandomMotion(response);
        break;
        
      case ResponseAction.vibrate:
        await _executeVibrate(response);
        break;
        
      case ResponseAction.sendSignalToFlutter:
        _emitSignal(response);
        break;
        
      case ResponseAction.composite:
        await _executeComposite(response);
        break;
        
      case ResponseAction.playSound:
      case ResponseAction.showBubble:
        live2dLog.debug(_tag, '미구현 액션', details: response.action.name);
        break;
        
      case ResponseAction.none:
        break;
    }
  }
  
  Future<void> _executeMotion(InteractionResponse response) async {
    if (response.motionGroup != null) {
      await _bridge.playMotion(
        response.motionGroup!,
        response.motionIndex ?? 0,
        priority: response.motionPriority ?? 2,
      );
    }
  }
  
  Future<void> _executeExpression(InteractionResponse response) async {
    if (response.expressionId != null) {
      await _bridge.setExpression(response.expressionId!);
    }
  }
  
  Future<void> _executeRandomMotion(InteractionResponse response) async {
    final group = response.motionGroup ?? 'idle';
    final count = await _bridge.getMotionCount(group);
    if (count > 0) {
      final randomIndex = DateTime.now().millisecond % count;
      await _bridge.playMotion(group, randomIndex);
    }
  }
  
  Future<void> _executeVibrate(InteractionResponse response) async {
    await HapticFeedback.vibrate();
  }
  
  void _emitSignal(InteractionResponse response) {
    if (response.signalName != null) {
      final event = InteractionEvent.command(
        response.signalName!,
        params: response.signalData,
      );
      _eventController.add(event);
    }
  }
  
  Future<void> _executeComposite(InteractionResponse response) async {
    if (response.compositeActions != null) {
      for (final action in response.compositeActions!) {
        await _executeResponse(action);
      }
    }
  }
  
  // ============================================================================
  // ============================================================================
  
  void addExternalListener(ExternalInteractionListener listener) {
    _externalListeners.add(listener);
    live2dLog.debug(_tag, '외부 리스너 등록', details: '총 ${_externalListeners.length}개');
  }
  
  void removeExternalListener(ExternalInteractionListener listener) {
    _externalListeners.remove(listener);
  }
  
  Future<void> triggerEmotion(String emotion) async {
    live2dLog.info(_tag, '감정 트리거', details: emotion);
    await _bridge.setExpression(emotion);
  }
  
  Future<void> triggerMotion(String group, {int index = 0, int priority = 2}) async {
    live2dLog.info(_tag, '모션 트리거', details: '$group[$index]');
    await _bridge.playMotion(group, index, priority: priority);
  }
  
  Future<void> triggerExpression(String expressionId) async {
    live2dLog.info(_tag, '표정 트리거', details: expressionId);
    await _bridge.setExpression(expressionId);
  }
  
  Future<void> sendSignal(String signalName, {Map<String, dynamic>? data}) async {
    live2dLog.info(_tag, '신호 전송', details: signalName);
    await _bridge.sendSignal(signalName, data: data);
  }
  
  Future<void> startSpeaking({String? emotion}) async {
    live2dLog.info(_tag, 'AI 말하기 시작', details: emotion);
    if (emotion != null) {
      await triggerExpression(emotion);
    }
    await triggerMotion('talk', priority: 2);
  }
  
  Future<void> stopSpeaking() async {
    live2dLog.info(_tag, 'AI 말하기 종료');
    await triggerMotion('idle', priority: 1);
  }
  
  Future<void> reactToNotification({String type = 'default'}) async {
    live2dLog.info(_tag, '알림 반응', details: type);
    
    switch (type) {
      case 'message':
        await triggerExpression('happy');
        await triggerMotion('notice', priority: 2);
        break;
      case 'alert':
        await triggerExpression('surprised');
        await triggerMotion('alert', priority: 3);
        break;
      default:
        await triggerMotion('notice', priority: 2);
    }
  }
}

/// 
abstract class Live2DInteractionInterface {
  Future<void> triggerEmotion(String emotion);
  
  Future<void> triggerMotion(String group, int index);
  
  Future<void> triggerExpression(String expressionId);
  
  Future<void> sendSignal(String signalName, {Map<String, dynamic>? data});
  
  Stream<InteractionEvent> get interactionStream;
}

class Live2DInteractionAdapter implements Live2DInteractionInterface {
  final InteractionManager _manager;
  
  Live2DInteractionAdapter(this._manager);
  
  @override
  Future<void> triggerEmotion(String emotion) => _manager.triggerEmotion(emotion);
  
  @override
  Future<void> triggerMotion(String group, int index) => 
      _manager.triggerMotion(group, index: index);
  
  @override
  Future<void> triggerExpression(String expressionId) => 
      _manager.triggerExpression(expressionId);
  
  @override
  Future<void> sendSignal(String signalName, {Map<String, dynamic>? data}) =>
      _manager.sendSignal(signalName, data: data);
  
  @override
  Stream<InteractionEvent> get interactionStream => _manager.eventStream;
}
