# Phase 1 구현 가이드: 기반 구축

## 1. Android Native 모듈 설정

### 1.1 build.gradle.kts 설정

```kotlin
// android/app/build.gradle.kts

android {
    // ...기존 설정...
    
    defaultConfig {
        // ...
        ndk {
            abiFilters += listOf("arm64-v8a", "armeabi-v7a", "x86_64")
        }
    }
    
    sourceSets {
        getByName("main") {
            jniLibs.srcDirs("src/main/jniLibs")
        }
    }
}

dependencies {
    // 기존 의존성...
    
    // OpenGL ES
    implementation("androidx.core:core-ktx:1.12.0")
    
    // Coroutines (비동기 처리)
    implementation("org.jetbrains.kotlinx:kotlinx-coroutines-android:1.7.3")
}
```

### 1.2 AndroidManifest.xml 수정

```xml
<!-- android/app/src/main/AndroidManifest.xml -->

<manifest ...>
    <!-- 기존 권한들... -->
    
    <!-- Live2D Overlay 권한 -->
    <uses-permission android:name="android.permission.SYSTEM_ALERT_WINDOW"/>
    <uses-permission android:name="android.permission.FOREGROUND_SERVICE"/>
    <uses-permission android:name="android.permission.FOREGROUND_SERVICE_SPECIAL_USE"/>
    
    <!-- OpenGL ES 요구사항 -->
    <uses-feature android:glEsVersion="0x00020000" android:required="true"/>
    
    <application ...>
        <!-- 기존 설정들... -->
        
        <!-- Live2D Overlay Service -->
        <service
            android:name=".live2d.overlay.Live2DOverlayService"
            android:foregroundServiceType="specialUse"
            android:exported="false">
            <property
                android:name="android.app.PROPERTY_SPECIAL_USE_FGS_SUBTYPE"
                android:value="live2d_overlay"/>
        </service>
        
    </application>
</manifest>
```

---

## 2. Platform Channel 기본 구조

### 2.1 Flutter 측 브릿지

```dart
// lib/features/live2d/data/services/live2d_native_bridge.dart

import 'dart:async';
import 'package:flutter/services.dart';
import '../../domain/entities/interaction_event.dart';

/// Live2D 네이티브 브릿지
/// Flutter와 Android 네이티브 모듈 간 통신을 담당합니다.
class Live2DNativeBridge {
  // 싱글톤 패턴
  static final Live2DNativeBridge _instance = Live2DNativeBridge._internal();
  factory Live2DNativeBridge() => _instance;
  Live2DNativeBridge._internal();

  // 채널 정의
  static const String _channelName = 'com.example.flutter_application_1/live2d';
  static const String _eventChannelName = 'com.example.flutter_application_1/live2d/events';
  
  final MethodChannel _methodChannel = const MethodChannel(_channelName);
  final EventChannel _eventChannel = const EventChannel(_eventChannelName);
  
  // 이벤트 스트림
  Stream<InteractionEvent>? _interactionStream;
  StreamSubscription? _eventSubscription;
  
  // 콜백
  final List<Function(InteractionEvent)> _eventCallbacks = [];

  /// 초기화
  Future<void> initialize() async {
    _interactionStream = _eventChannel
        .receiveBroadcastStream()
        .map((event) => InteractionEvent.fromMap(event as Map<String, dynamic>));
    
    _eventSubscription = _interactionStream?.listen(_handleEvent);
  }

  /// 정리
  void dispose() {
    _eventSubscription?.cancel();
    _eventCallbacks.clear();
  }

  /// 이벤트 핸들러
  void _handleEvent(InteractionEvent event) {
    for (final callback in _eventCallbacks) {
      callback(event);
    }
  }

  /// 이벤트 리스너 등록
  void addEventListener(Function(InteractionEvent) callback) {
    _eventCallbacks.add(callback);
  }

  /// 이벤트 리스너 제거
  void removeEventListener(Function(InteractionEvent) callback) {
    _eventCallbacks.remove(callback);
  }

  // ============================================================================
  // 오버레이 제어
  // ============================================================================

  /// 오버레이 표시
  Future<bool> showOverlay() async {
    try {
      final result = await _methodChannel.invokeMethod<bool>('showOverlay');
      return result ?? false;
    } on PlatformException catch (e) {
      print('[Live2DBridge] showOverlay 실패: ${e.message}');
      return false;
    }
  }

  /// 오버레이 숨김
  Future<bool> hideOverlay() async {
    try {
      final result = await _methodChannel.invokeMethod<bool>('hideOverlay');
      return result ?? false;
    } on PlatformException catch (e) {
      print('[Live2DBridge] hideOverlay 실패: ${e.message}');
      return false;
    }
  }

  /// 오버레이 표시 상태 확인
  Future<bool> isOverlayVisible() async {
    try {
      final result = await _methodChannel.invokeMethod<bool>('isOverlayVisible');
      return result ?? false;
    } on PlatformException catch (e) {
      print('[Live2DBridge] isOverlayVisible 실패: ${e.message}');
      return false;
    }
  }

  // ============================================================================
  // 모델 제어
  // ============================================================================

  /// 모델 로드
  Future<bool> loadModel(String modelPath) async {
    try {
      final result = await _methodChannel.invokeMethod<bool>('loadModel', {
        'path': modelPath,
      });
      return result ?? false;
    } on PlatformException catch (e) {
      print('[Live2DBridge] loadModel 실패: ${e.message}');
      return false;
    }
  }

  /// 모델 언로드
  Future<bool> unloadModel() async {
    try {
      final result = await _methodChannel.invokeMethod<bool>('unloadModel');
      return result ?? false;
    } on PlatformException catch (e) {
      print('[Live2DBridge] unloadModel 실패: ${e.message}');
      return false;
    }
  }

  /// 모션 재생
  Future<bool> playMotion(String group, int index, {int priority = 2}) async {
    try {
      final result = await _methodChannel.invokeMethod<bool>('playMotion', {
        'group': group,
        'index': index,
        'priority': priority,
      });
      return result ?? false;
    } on PlatformException catch (e) {
      print('[Live2DBridge] playMotion 실패: ${e.message}');
      return false;
    }
  }

  /// 표정 설정
  Future<bool> setExpression(String expressionId) async {
    try {
      final result = await _methodChannel.invokeMethod<bool>('setExpression', {
        'id': expressionId,
      });
      return result ?? false;
    } on PlatformException catch (e) {
      print('[Live2DBridge] setExpression 실패: ${e.message}');
      return false;
    }
  }

  /// 랜덤 표정 설정
  Future<bool> setRandomExpression() async {
    try {
      final result = await _methodChannel.invokeMethod<bool>('setRandomExpression');
      return result ?? false;
    } on PlatformException catch (e) {
      print('[Live2DBridge] setRandomExpression 실패: ${e.message}');
      return false;
    }
  }

  // ============================================================================
  // 디스플레이 설정
  // ============================================================================

  /// 크기 설정
  Future<bool> setScale(double scale) async {
    try {
      final result = await _methodChannel.invokeMethod<bool>('setScale', {
        'scale': scale,
      });
      return result ?? false;
    } on PlatformException catch (e) {
      print('[Live2DBridge] setScale 실패: ${e.message}');
      return false;
    }
  }

  /// 투명도 설정
  Future<bool> setOpacity(double opacity) async {
    try {
      final result = await _methodChannel.invokeMethod<bool>('setOpacity', {
        'opacity': opacity,
      });
      return result ?? false;
    } on PlatformException catch (e) {
      print('[Live2DBridge] setOpacity 실패: ${e.message}');
      return false;
    }
  }

  /// 위치 설정
  Future<bool> setPosition(int x, int y) async {
    try {
      final result = await _methodChannel.invokeMethod<bool>('setPosition', {
        'x': x,
        'y': y,
      });
      return result ?? false;
    } on PlatformException catch (e) {
      print('[Live2DBridge] setPosition 실패: ${e.message}');
      return false;
    }
  }

  /// 크기 설정 (픽셀)
  Future<bool> setSize(int width, int height) async {
    try {
      final result = await _methodChannel.invokeMethod<bool>('setSize', {
        'width': width,
        'height': height,
      });
      return result ?? false;
    } on PlatformException catch (e) {
      print('[Live2DBridge] setSize 실패: ${e.message}');
      return false;
    }
  }

  // ============================================================================
  // 자동 동작 설정
  // ============================================================================

  /// 눈 깜빡임 설정
  Future<bool> setEyeBlink(bool enabled) async {
    try {
      final result = await _methodChannel.invokeMethod<bool>('setEyeBlink', {
        'enabled': enabled,
      });
      return result ?? false;
    } on PlatformException catch (e) {
      print('[Live2DBridge] setEyeBlink 실패: ${e.message}');
      return false;
    }
  }

  /// 호흡 설정
  Future<bool> setBreathing(bool enabled) async {
    try {
      final result = await _methodChannel.invokeMethod<bool>('setBreathing', {
        'enabled': enabled,
      });
      return result ?? false;
    } on PlatformException catch (e) {
      print('[Live2DBridge] setBreathing 실패: ${e.message}');
      return false;
    }
  }

  /// 시선 추적 설정
  Future<bool> setLookAt(bool enabled) async {
    try {
      final result = await _methodChannel.invokeMethod<bool>('setLookAt', {
        'enabled': enabled,
      });
      return result ?? false;
    } on PlatformException catch (e) {
      print('[Live2DBridge] setLookAt 실패: ${e.message}');
      return false;
    }
  }

  /// 터치 포인트 설정 (시선 추적용)
  Future<bool> setTouchPoint(double x, double y) async {
    try {
      final result = await _methodChannel.invokeMethod<bool>('setTouchPoint', {
        'x': x,
        'y': y,
      });
      return result ?? false;
    } on PlatformException catch (e) {
      print('[Live2DBridge] setTouchPoint 실패: ${e.message}');
      return false;
    }
  }

  // ============================================================================
  // 상호작용 신호
  // ============================================================================

  /// 외부 신호 전송 (다른 앱 기능에서 Live2D 제어)
  Future<bool> sendSignal(String signalName, {Map<String, dynamic>? data}) async {
    try {
      final result = await _methodChannel.invokeMethod<bool>('sendSignal', {
        'signal': signalName,
        'data': data ?? {},
      });
      return result ?? false;
    } on PlatformException catch (e) {
      print('[Live2DBridge] sendSignal 실패: ${e.message}');
      return false;
    }
  }

  // ============================================================================
  // 모델 정보 조회
  // ============================================================================

  /// 모션 그룹 목록 조회
  Future<List<String>> getMotionGroups() async {
    try {
      final result = await _methodChannel.invokeMethod<List<dynamic>>('getMotionGroups');
      return result?.cast<String>() ?? [];
    } on PlatformException catch (e) {
      print('[Live2DBridge] getMotionGroups 실패: ${e.message}');
      return [];
    }
  }

  /// 특정 그룹의 모션 수 조회
  Future<int> getMotionCount(String group) async {
    try {
      final result = await _methodChannel.invokeMethod<int>('getMotionCount', {
        'group': group,
      });
      return result ?? 0;
    } on PlatformException catch (e) {
      print('[Live2DBridge] getMotionCount 실패: ${e.message}');
      return 0;
    }
  }

  /// 표정 목록 조회
  Future<List<String>> getExpressions() async {
    try {
      final result = await _methodChannel.invokeMethod<List<dynamic>>('getExpressions');
      return result?.cast<String>() ?? [];
    } on PlatformException catch (e) {
      print('[Live2DBridge] getExpressions 실패: ${e.message}');
      return [];
    }
  }
}
```

### 2.2 Android 측 Plugin

```kotlin
// android/app/src/main/kotlin/com/example/flutter_application_1/live2d/Live2DPlugin.kt

package com.example.flutter_application_1.live2d

import android.content.Context
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel

class Live2DPlugin : FlutterPlugin {
    
    companion object {
        private const val CHANNEL_NAME = "com.example.flutter_application_1/live2d"
        private const val EVENT_CHANNEL_NAME = "com.example.flutter_application_1/live2d/events"
    }
    
    private lateinit var methodChannel: MethodChannel
    private lateinit var eventChannel: EventChannel
    private lateinit var methodHandler: Live2DMethodHandler
    private lateinit var eventStreamHandler: Live2DEventStreamHandler
    
    override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        val context = binding.applicationContext
        
        // Event Stream Handler 생성
        eventStreamHandler = Live2DEventStreamHandler()
        
        // Method Handler 생성
        methodHandler = Live2DMethodHandler(context, eventStreamHandler)
        
        // Method Channel 설정
        methodChannel = MethodChannel(binding.binaryMessenger, CHANNEL_NAME)
        methodChannel.setMethodCallHandler(methodHandler)
        
        // Event Channel 설정
        eventChannel = EventChannel(binding.binaryMessenger, EVENT_CHANNEL_NAME)
        eventChannel.setStreamHandler(eventStreamHandler)
    }
    
    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        methodChannel.setMethodCallHandler(null)
        eventChannel.setStreamHandler(null)
        methodHandler.dispose()
    }
}
```

### 2.3 Method Handler

```kotlin
// android/app/src/main/kotlin/com/example/flutter_application_1/live2d/Live2DMethodHandler.kt

package com.example.flutter_application_1.live2d

import android.content.Context
import android.content.Intent
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import com.example.flutter_application_1.live2d.overlay.Live2DOverlayService

class Live2DMethodHandler(
    private val context: Context,
    private val eventStreamHandler: Live2DEventStreamHandler
) : MethodChannel.MethodCallHandler {
    
    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            // === 오버레이 제어 ===
            "showOverlay" -> showOverlay(result)
            "hideOverlay" -> hideOverlay(result)
            "isOverlayVisible" -> isOverlayVisible(result)
            
            // === 모델 제어 ===
            "loadModel" -> loadModel(call, result)
            "unloadModel" -> unloadModel(result)
            "playMotion" -> playMotion(call, result)
            "setExpression" -> setExpression(call, result)
            "setRandomExpression" -> setRandomExpression(result)
            
            // === 디스플레이 설정 ===
            "setScale" -> setScale(call, result)
            "setOpacity" -> setOpacity(call, result)
            "setPosition" -> setPosition(call, result)
            "setSize" -> setSize(call, result)
            
            // === 자동 동작 설정 ===
            "setEyeBlink" -> setEyeBlink(call, result)
            "setBreathing" -> setBreathing(call, result)
            "setLookAt" -> setLookAt(call, result)
            "setTouchPoint" -> setTouchPoint(call, result)
            
            // === 상호작용 신호 ===
            "sendSignal" -> sendSignal(call, result)
            
            // === 모델 정보 조회 ===
            "getMotionGroups" -> getMotionGroups(result)
            "getMotionCount" -> getMotionCount(call, result)
            "getExpressions" -> getExpressions(result)
            
            else -> result.notImplemented()
        }
    }
    
    // ============================================================================
    // 오버레이 제어 구현
    // ============================================================================
    
    private fun showOverlay(result: MethodChannel.Result) {
        try {
            val intent = Intent(context, Live2DOverlayService::class.java).apply {
                action = Live2DOverlayService.ACTION_SHOW
            }
            context.startForegroundService(intent)
            result.success(true)
        } catch (e: Exception) {
            result.error("OVERLAY_ERROR", e.message, null)
        }
    }
    
    private fun hideOverlay(result: MethodChannel.Result) {
        try {
            val intent = Intent(context, Live2DOverlayService::class.java).apply {
                action = Live2DOverlayService.ACTION_HIDE
            }
            context.startService(intent)
            result.success(true)
        } catch (e: Exception) {
            result.error("OVERLAY_ERROR", e.message, null)
        }
    }
    
    private fun isOverlayVisible(result: MethodChannel.Result) {
        result.success(Live2DOverlayService.isRunning)
    }
    
    // ============================================================================
    // 모델 제어 구현
    // ============================================================================
    
    private fun loadModel(call: MethodCall, result: MethodChannel.Result) {
        val path = call.argument<String>("path")
        if (path == null) {
            result.error("INVALID_ARGUMENT", "path is required", null)
            return
        }
        
        try {
            val intent = Intent(context, Live2DOverlayService::class.java).apply {
                action = Live2DOverlayService.ACTION_LOAD_MODEL
                putExtra("path", path)
            }
            context.startService(intent)
            result.success(true)
        } catch (e: Exception) {
            result.error("MODEL_ERROR", e.message, null)
        }
    }
    
    private fun unloadModel(result: MethodChannel.Result) {
        try {
            val intent = Intent(context, Live2DOverlayService::class.java).apply {
                action = Live2DOverlayService.ACTION_UNLOAD_MODEL
            }
            context.startService(intent)
            result.success(true)
        } catch (e: Exception) {
            result.error("MODEL_ERROR", e.message, null)
        }
    }
    
    private fun playMotion(call: MethodCall, result: MethodChannel.Result) {
        val group = call.argument<String>("group") ?: ""
        val index = call.argument<Int>("index") ?: 0
        val priority = call.argument<Int>("priority") ?: 2
        
        try {
            val intent = Intent(context, Live2DOverlayService::class.java).apply {
                action = Live2DOverlayService.ACTION_PLAY_MOTION
                putExtra("group", group)
                putExtra("index", index)
                putExtra("priority", priority)
            }
            context.startService(intent)
            result.success(true)
        } catch (e: Exception) {
            result.error("MOTION_ERROR", e.message, null)
        }
    }
    
    private fun setExpression(call: MethodCall, result: MethodChannel.Result) {
        val id = call.argument<String>("id")
        if (id == null) {
            result.error("INVALID_ARGUMENT", "id is required", null)
            return
        }
        
        try {
            val intent = Intent(context, Live2DOverlayService::class.java).apply {
                action = Live2DOverlayService.ACTION_SET_EXPRESSION
                putExtra("id", id)
            }
            context.startService(intent)
            result.success(true)
        } catch (e: Exception) {
            result.error("EXPRESSION_ERROR", e.message, null)
        }
    }
    
    private fun setRandomExpression(result: MethodChannel.Result) {
        try {
            val intent = Intent(context, Live2DOverlayService::class.java).apply {
                action = Live2DOverlayService.ACTION_RANDOM_EXPRESSION
            }
            context.startService(intent)
            result.success(true)
        } catch (e: Exception) {
            result.error("EXPRESSION_ERROR", e.message, null)
        }
    }
    
    // ============================================================================
    // 디스플레이 설정 구현
    // ============================================================================
    
    private fun setScale(call: MethodCall, result: MethodChannel.Result) {
        val scale = call.argument<Double>("scale") ?: 1.0
        
        try {
            val intent = Intent(context, Live2DOverlayService::class.java).apply {
                action = Live2DOverlayService.ACTION_SET_SCALE
                putExtra("scale", scale.toFloat())
            }
            context.startService(intent)
            result.success(true)
        } catch (e: Exception) {
            result.error("DISPLAY_ERROR", e.message, null)
        }
    }
    
    private fun setOpacity(call: MethodCall, result: MethodChannel.Result) {
        val opacity = call.argument<Double>("opacity") ?: 1.0
        
        try {
            val intent = Intent(context, Live2DOverlayService::class.java).apply {
                action = Live2DOverlayService.ACTION_SET_OPACITY
                putExtra("opacity", opacity.toFloat())
            }
            context.startService(intent)
            result.success(true)
        } catch (e: Exception) {
            result.error("DISPLAY_ERROR", e.message, null)
        }
    }
    
    private fun setPosition(call: MethodCall, result: MethodChannel.Result) {
        val x = call.argument<Int>("x") ?: 0
        val y = call.argument<Int>("y") ?: 0
        
        try {
            val intent = Intent(context, Live2DOverlayService::class.java).apply {
                action = Live2DOverlayService.ACTION_SET_POSITION
                putExtra("x", x)
                putExtra("y", y)
            }
            context.startService(intent)
            result.success(true)
        } catch (e: Exception) {
            result.error("DISPLAY_ERROR", e.message, null)
        }
    }
    
    private fun setSize(call: MethodCall, result: MethodChannel.Result) {
        val width = call.argument<Int>("width") ?: 300
        val height = call.argument<Int>("height") ?: 400
        
        try {
            val intent = Intent(context, Live2DOverlayService::class.java).apply {
                action = Live2DOverlayService.ACTION_SET_SIZE
                putExtra("width", width)
                putExtra("height", height)
            }
            context.startService(intent)
            result.success(true)
        } catch (e: Exception) {
            result.error("DISPLAY_ERROR", e.message, null)
        }
    }
    
    // ============================================================================
    // 자동 동작 설정 구현
    // ============================================================================
    
    private fun setEyeBlink(call: MethodCall, result: MethodChannel.Result) {
        val enabled = call.argument<Boolean>("enabled") ?: true
        
        try {
            val intent = Intent(context, Live2DOverlayService::class.java).apply {
                action = Live2DOverlayService.ACTION_SET_EYE_BLINK
                putExtra("enabled", enabled)
            }
            context.startService(intent)
            result.success(true)
        } catch (e: Exception) {
            result.error("BEHAVIOR_ERROR", e.message, null)
        }
    }
    
    private fun setBreathing(call: MethodCall, result: MethodChannel.Result) {
        val enabled = call.argument<Boolean>("enabled") ?: true
        
        try {
            val intent = Intent(context, Live2DOverlayService::class.java).apply {
                action = Live2DOverlayService.ACTION_SET_BREATHING
                putExtra("enabled", enabled)
            }
            context.startService(intent)
            result.success(true)
        } catch (e: Exception) {
            result.error("BEHAVIOR_ERROR", e.message, null)
        }
    }
    
    private fun setLookAt(call: MethodCall, result: MethodChannel.Result) {
        val enabled = call.argument<Boolean>("enabled") ?: true
        
        try {
            val intent = Intent(context, Live2DOverlayService::class.java).apply {
                action = Live2DOverlayService.ACTION_SET_LOOK_AT
                putExtra("enabled", enabled)
            }
            context.startService(intent)
            result.success(true)
        } catch (e: Exception) {
            result.error("BEHAVIOR_ERROR", e.message, null)
        }
    }
    
    private fun setTouchPoint(call: MethodCall, result: MethodChannel.Result) {
        val x = call.argument<Double>("x") ?: 0.0
        val y = call.argument<Double>("y") ?: 0.0
        
        try {
            val intent = Intent(context, Live2DOverlayService::class.java).apply {
                action = Live2DOverlayService.ACTION_SET_TOUCH_POINT
                putExtra("x", x.toFloat())
                putExtra("y", y.toFloat())
            }
            context.startService(intent)
            result.success(true)
        } catch (e: Exception) {
            result.error("BEHAVIOR_ERROR", e.message, null)
        }
    }
    
    // ============================================================================
    // 상호작용 신호 구현
    // ============================================================================
    
    private fun sendSignal(call: MethodCall, result: MethodChannel.Result) {
        val signal = call.argument<String>("signal") ?: ""
        val data = call.argument<Map<String, Any>>("data") ?: emptyMap()
        
        try {
            val intent = Intent(context, Live2DOverlayService::class.java).apply {
                action = Live2DOverlayService.ACTION_SEND_SIGNAL
                putExtra("signal", signal)
                // data는 별도 처리 필요
            }
            context.startService(intent)
            result.success(true)
        } catch (e: Exception) {
            result.error("SIGNAL_ERROR", e.message, null)
        }
    }
    
    // ============================================================================
    // 모델 정보 조회 구현
    // ============================================================================
    
    private fun getMotionGroups(result: MethodChannel.Result) {
        // TODO: 현재 로드된 모델에서 모션 그룹 목록 조회
        result.success(listOf<String>())
    }
    
    private fun getMotionCount(call: MethodCall, result: MethodChannel.Result) {
        val group = call.argument<String>("group") ?: ""
        // TODO: 특정 그룹의 모션 수 조회
        result.success(0)
    }
    
    private fun getExpressions(result: MethodChannel.Result) {
        // TODO: 현재 로드된 모델에서 표정 목록 조회
        result.success(listOf<String>())
    }
    
    fun dispose() {
        // 정리 작업
    }
}
```

### 2.4 Event Stream Handler

```kotlin
// android/app/src/main/kotlin/com/example/flutter_application_1/live2d/Live2DEventStreamHandler.kt

package com.example.flutter_application_1.live2d

import android.os.Handler
import android.os.Looper
import io.flutter.plugin.common.EventChannel

class Live2DEventStreamHandler : EventChannel.StreamHandler {
    
    private var eventSink: EventChannel.EventSink? = null
    private val mainHandler = Handler(Looper.getMainLooper())
    
    override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
        eventSink = events
    }
    
    override fun onCancel(arguments: Any?) {
        eventSink = null
    }
    
    /**
     * Flutter로 이벤트 전송
     */
    fun sendEvent(event: Map<String, Any?>) {
        mainHandler.post {
            eventSink?.success(event)
        }
    }
    
    /**
     * 상호작용 이벤트 전송
     */
    fun sendInteractionEvent(
        type: String,
        x: Float? = null,
        y: Float? = null,
        extras: Map<String, Any?>? = null
    ) {
        val event = mutableMapOf<String, Any?>(
            "type" to type,
            "timestamp" to System.currentTimeMillis()
        )
        
        if (x != null && y != null) {
            event["x"] = x
            event["y"] = y
        }
        
        extras?.let {
            event["extras"] = it
        }
        
        sendEvent(event)
    }
    
    /**
     * 에러 이벤트 전송
     */
    fun sendError(code: String, message: String) {
        mainHandler.post {
            eventSink?.error(code, message, null)
        }
    }
}
```

---

## 3. Domain 엔티티 정의

### 3.1 상호작용 이벤트

```dart
// lib/features/live2d/domain/entities/interaction_event.dart

import 'dart:ui';

/// 상호작용 유형
enum InteractionType {
  // 기본 터치
  tap,
  doubleTap,
  longPress,
  
  // 드래그 패턴
  swipeUp,
  swipeDown,
  swipeLeft,
  swipeRight,
  circleCW,
  circleCCW,
  headPat,
  zigzag,
  
  // 특수 영역 터치
  headTouch,
  bodyTouch,
  faceTouch,
  
  // 시스템 이벤트
  overlayShown,
  overlayHidden,
  modelLoaded,
  modelUnloaded,
  motionStarted,
  motionFinished,
  
  // 외부 신호
  externalCommand,
  
  // 알 수 없음
  unknown,
}

/// 상호작용 이벤트
class InteractionEvent {
  final InteractionType type;
  final Offset? position;
  final Map<String, dynamic>? extras;
  final DateTime timestamp;

  const InteractionEvent({
    required this.type,
    this.position,
    this.extras,
    required this.timestamp,
  });

  /// Map에서 생성
  factory InteractionEvent.fromMap(Map<String, dynamic> map) {
    return InteractionEvent(
      type: _parseType(map['type'] as String?),
      position: map['x'] != null && map['y'] != null
          ? Offset(
              (map['x'] as num).toDouble(),
              (map['y'] as num).toDouble(),
            )
          : null,
      extras: map['extras'] as Map<String, dynamic>?,
      timestamp: DateTime.fromMillisecondsSinceEpoch(
        (map['timestamp'] as int?) ?? DateTime.now().millisecondsSinceEpoch,
      ),
    );
  }

  /// Map으로 변환
  Map<String, dynamic> toMap() {
    return {
      'type': type.name,
      'x': position?.dx,
      'y': position?.dy,
      'extras': extras,
      'timestamp': timestamp.millisecondsSinceEpoch,
    };
  }

  static InteractionType _parseType(String? typeStr) {
    if (typeStr == null) return InteractionType.unknown;
    
    try {
      return InteractionType.values.firstWhere(
        (e) => e.name == typeStr,
        orElse: () => InteractionType.unknown,
      );
    } catch (e) {
      return InteractionType.unknown;
    }
  }

  @override
  String toString() {
    return 'InteractionEvent(type: $type, position: $position, timestamp: $timestamp)';
  }
}
```

### 3.2 제스처 패턴 설정

```dart
// lib/features/live2d/domain/entities/gesture_config.dart

/// 제스처 동작 매핑
class GestureActionMapping {
  final InteractionType gesture;
  final String actionType;  // 'motion', 'expression', 'signal'
  final String? motionGroup;
  final int? motionIndex;
  final String? expressionId;
  final String? signalName;
  final Map<String, dynamic>? signalData;

  const GestureActionMapping({
    required this.gesture,
    required this.actionType,
    this.motionGroup,
    this.motionIndex,
    this.expressionId,
    this.signalName,
    this.signalData,
  });

  Map<String, dynamic> toJson() {
    return {
      'gesture': gesture.name,
      'actionType': actionType,
      'motionGroup': motionGroup,
      'motionIndex': motionIndex,
      'expressionId': expressionId,
      'signalName': signalName,
      'signalData': signalData,
    };
  }

  factory GestureActionMapping.fromJson(Map<String, dynamic> json) {
    return GestureActionMapping(
      gesture: InteractionType.values.firstWhere(
        (e) => e.name == json['gesture'],
        orElse: () => InteractionType.unknown,
      ),
      actionType: json['actionType'] as String,
      motionGroup: json['motionGroup'] as String?,
      motionIndex: json['motionIndex'] as int?,
      expressionId: json['expressionId'] as String?,
      signalName: json['signalName'] as String?,
      signalData: json['signalData'] as Map<String, dynamic>?,
    );
  }
}

/// 제스처 설정
class GestureConfig {
  final bool enableTapReaction;
  final bool enableDoubleTapReaction;
  final bool enableLongPressReaction;
  final bool enableDragPatterns;
  final bool enableAreaTouch;  // 영역별 터치 감지
  final List<GestureActionMapping> actionMappings;

  const GestureConfig({
    this.enableTapReaction = true,
    this.enableDoubleTapReaction = true,
    this.enableLongPressReaction = true,
    this.enableDragPatterns = true,
    this.enableAreaTouch = false,
    this.actionMappings = const [],
  });

  factory GestureConfig.defaults() => const GestureConfig();

  GestureConfig copyWith({
    bool? enableTapReaction,
    bool? enableDoubleTapReaction,
    bool? enableLongPressReaction,
    bool? enableDragPatterns,
    bool? enableAreaTouch,
    List<GestureActionMapping>? actionMappings,
  }) {
    return GestureConfig(
      enableTapReaction: enableTapReaction ?? this.enableTapReaction,
      enableDoubleTapReaction: enableDoubleTapReaction ?? this.enableDoubleTapReaction,
      enableLongPressReaction: enableLongPressReaction ?? this.enableLongPressReaction,
      enableDragPatterns: enableDragPatterns ?? this.enableDragPatterns,
      enableAreaTouch: enableAreaTouch ?? this.enableAreaTouch,
      actionMappings: actionMappings ?? this.actionMappings,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'enableTapReaction': enableTapReaction,
      'enableDoubleTapReaction': enableDoubleTapReaction,
      'enableLongPressReaction': enableLongPressReaction,
      'enableDragPatterns': enableDragPatterns,
      'enableAreaTouch': enableAreaTouch,
      'actionMappings': actionMappings.map((e) => e.toJson()).toList(),
    };
  }

  factory GestureConfig.fromJson(Map<String, dynamic> json) {
    return GestureConfig(
      enableTapReaction: json['enableTapReaction'] as bool? ?? true,
      enableDoubleTapReaction: json['enableDoubleTapReaction'] as bool? ?? true,
      enableLongPressReaction: json['enableLongPressReaction'] as bool? ?? true,
      enableDragPatterns: json['enableDragPatterns'] as bool? ?? true,
      enableAreaTouch: json['enableAreaTouch'] as bool? ?? false,
      actionMappings: (json['actionMappings'] as List<dynamic>?)
          ?.map((e) => GestureActionMapping.fromJson(e))
          .toList() ?? [],
    );
  }
}
```

---

## 4. MainActivity 수정

```kotlin
// android/app/src/main/kotlin/com/example/flutter_application_1/MainActivity.kt

package com.example.flutter_application_1

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import com.example.flutter_application_1.live2d.Live2DPlugin

class MainActivity : FlutterActivity() {
    
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        
        // Live2D Plugin 등록
        flutterEngine.plugins.add(Live2DPlugin())
    }
}
```

---

## 5. 다음 단계

Phase 1 완료 후:
1. Phase 2로 진행: Live2D Cubism SDK 통합 및 OpenGL 렌더러 구현
2. 또는 먼저 기본 오버레이 서비스만 구현하여 테스트

Phase 1에서 기본 구조를 먼저 구축하고, 점진적으로 기능을 추가하는 것을 권장합니다.
