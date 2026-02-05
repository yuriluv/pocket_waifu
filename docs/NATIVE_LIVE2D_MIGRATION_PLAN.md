# Native OpenGL Live2D 오버레이 마이그레이션 계획

> **최종 업데이트**: 2026-02-06
> **현재 상태**: Phase 6 완료 (인프라), Phase 7 진입 필요 (SDK 통합)

## 📋 개요

현재 WebView 기반 Live2D 렌더링을 **네이티브 OpenGL 기반**으로 전환하여 다음을 달성합니다:
- **성능 최적화**: WebView 오버헤드 제거, GPU 직접 렌더링
- **모델 선택 유연성**: 네이티브 SDK로 직접 모델 로딩/관리
- **터치 상호작용**: 네이티브 수준의 터치 감지 및 제스처 인식
- **기능 확장성**: Live2DViewerEX Floating Viewer 수준의 기능 구현

---

## 🚨 현황 요약 (2026-02-06 기준)

### ✅ 완료된 항목 (Phase 1-6)

| 카테고리 | 항목 | 상태 |
|----------|------|------|
| **Android Native 인프라** | 프로젝트 구조 | ✅ 완료 |
| | Live2DPlugin.kt | ✅ 완료 |
| | Live2DMethodHandler.kt | ✅ 완료 |
| | Live2DEventStreamHandler.kt | ✅ 완료 |
| **오버레이 시스템** | Live2DOverlayService.kt | ✅ 완료 |
| | Live2DOverlayWindow.kt | ✅ 완료 |
| | Foreground Service + Notification | ✅ 완료 |
| **렌더링 엔진** | Live2DGLSurfaceView.kt | ✅ 완료 |
| | Live2DGLRenderer.kt | ✅ 완료 |
| | PlaceholderShader.kt | ✅ 완료 |
| | TextureModelRenderer.kt (프리뷰용) | ✅ 완료 |
| | GL 스레드 동기화 | ✅ 완료 |
| | 텍스처 크기 제한 처리 | ✅ 완료 |
| **모델 관리** | Live2DModel.kt | ✅ 완료 |
| | Model3JsonParser.kt | ✅ 완료 |
| | Live2DManager.kt (플레이스홀더) | ⚠️ SDK 연동 필요 |
| **제스처** | GestureDetectorManager.kt | ✅ 완료 |
| | 기본 터치/드래그 | ✅ 완료 |
| **Flutter 브릿지** | live2d_native_bridge.dart | ✅ 완료 |
| | live2d_overlay_service.dart | ✅ 완료 |
| **설정** | FPS 조절 | ✅ 완료 |
| | 저전력 모드 | ✅ 완료 |
| | 위치/크기 조절 | ✅ 완료 |

### ❌ 미완료 항목 (Phase 7-8 필요)

| 카테고리 | 항목 | 상태 |
|----------|------|------|
| **SDK** | Live2D Cubism SDK for Native 설치 | ❌ 미완료 |
| | jniLibs/*.so 파일 | ❌ 없음 |
| | CubismFramework 초기화 | ❌ 미구현 |
| **실제 렌더링** | moc3 파일 로드 | ❌ 미구현 |
| | 메시 렌더링 | ❌ 미구현 |
| | 모션 애니메이션 | ❌ 미구현 |
| | 표정 시스템 | ❌ 미구현 |
| | 물리 연산 | ❌ 미구현 |
| | 눈 깜빡임/호흡 | ❌ 미구현 |
| | 시선 추적 | ❌ 미구현 |

### 현재 동작 방식

```
[현재 - 텍스처 프리뷰 모드]
model3.json 파싱 → texture_00.png 추출 → OpenGL 사각형에 텍스처 매핑

[목표 - 실제 Live2D 렌더링]
model3.json 파싱 → moc3 로드 → SDK 초기화 → 모션/물리 연산 → 메시 렌더링
```

---

## 🏗️ 아키텍처 설계

### 현재 구조 (WebView 기반)
```
Flutter App
    ├── flutter_overlay_window (오버레이 창)
    │       └── WebView
    │               └── Live2D Web SDK (JavaScript)
    └── Local HTTP Server (shelf)
            └── Live2D 모델 파일 서빙
```

### 목표 구조 (Native OpenGL 기반)
```
Flutter App
    ├── Platform Channel (MethodChannel/EventChannel)
    │       ├── Live2D Control Commands
    │       ├── Touch Event Forwarding
    │       └── Interaction Signals
    │
    └── Android Native Module
            ├── Overlay Service (WindowManager)
            │       └── SurfaceView / GLSurfaceView
            │               └── OpenGL ES Renderer
            │                       └── Live2D Cubism Native SDK
            │
            ├── Gesture Detector
            │       ├── Tap Detection
            │       ├── Long Press Detection
            │       └── Drag Pattern Recognition
            │
            └── Signal/Event System
                    └── Interaction Event Bus
```

---

## 📦 Phase 1: 기반 구축 (1-2주)

### 1.1 프로젝트 구조 재설계

```
lib/
└── features/
    └── live2d/
        ├── live2d_module.dart           # 모듈 진입점
        │
        ├── domain/                       # 도메인 레이어 (NEW)
        │   ├── entities/
        │   │   ├── live2d_model.dart         # 모델 엔티티
        │   │   ├── interaction_event.dart    # 상호작용 이벤트
        │   │   └── gesture_pattern.dart      # 제스처 패턴 정의
        │   ├── repositories/
        │   │   └── i_live2d_repository.dart  # 리포지토리 인터페이스
        │   └── use_cases/
        │       ├── load_model_usecase.dart
        │       ├── handle_gesture_usecase.dart
        │       └── send_interaction_usecase.dart
        │
        ├── data/
        │   ├── models/
        │   │   ├── live2d_model_info.dart    # (기존 유지)
        │   │   ├── live2d_settings.dart      # (확장)
        │   │   ├── gesture_config.dart       # (NEW) 제스처 설정
        │   │   └── motion_config.dart        # (NEW) 모션 설정
        │   ├── repositories/
        │   │   └── live2d_repository_impl.dart
        │   └── services/
        │       ├── live2d_storage_service.dart   # (기존 유지)
        │       ├── live2d_log_service.dart       # (기존 유지)
        │       ├── live2d_native_bridge.dart     # (NEW) 네이티브 브릿지
        │       └── gesture_recognition_service.dart # (NEW)
        │
        └── presentation/
            ├── controllers/
            │   ├── live2d_controller.dart    # (확장)
            │   └── gesture_controller.dart   # (NEW)
            ├── screens/
            │   ├── live2d_settings_screen.dart  # (확장)
            │   ├── model_browser_screen.dart    # (NEW) 모델 브라우저
            │   └── gesture_settings_screen.dart # (NEW) 제스처 설정
            └── widgets/
                └── ... (기존 + 확장)
```

### 1.2 Android Native 모듈 구조

```
android/app/src/main/
├── kotlin/com/example/flutter_application_1/
│   ├── MainActivity.kt                    # (기존)
│   │
│   └── live2d/                            # (NEW) Live2D 네이티브 모듈
│       ├── Live2DPlugin.kt                # Flutter Plugin 진입점
│       ├── Live2DMethodHandler.kt         # MethodChannel 핸들러
│       │
│       ├── core/
│       │   ├── Live2DRenderer.kt          # OpenGL 렌더러
│       │   ├── Live2DModel.kt             # 모델 로더/관리
│       │   ├── Live2DMotionManager.kt     # 모션 관리
│       │   └── Live2DExpressionManager.kt # 표정 관리
│       │
│       ├── overlay/
│       │   ├── OverlayService.kt          # Foreground Service
│       │   ├── OverlayWindow.kt           # WindowManager 관리
│       │   └── Live2DSurfaceView.kt       # GLSurfaceView 구현
│       │
│       ├── gesture/
│       │   ├── GestureDetectorManager.kt  # 제스처 감지 관리
│       │   ├── TapDetector.kt             # 탭 감지
│       │   ├── DragPatternRecognizer.kt   # 드래그 패턴 인식
│       │   └── GesturePatterns.kt         # 패턴 정의
│       │
│       └── events/
│           ├── InteractionEvent.kt        # 상호작용 이벤트
│           └── EventDispatcher.kt         # 이벤트 디스패처
│
├── jniLibs/                               # Live2D Cubism SDK 네이티브 라이브러리
│   ├── arm64-v8a/
│   │   └── libLive2DCubismCore.so
│   ├── armeabi-v7a/
│   │   └── libLive2DCubismCore.so
│   └── x86_64/
│       └── libLive2DCubismCore.so
│
└── res/
    └── raw/                               # 셰이더 파일
        ├── live2d_vertex_shader.glsl
        └── live2d_fragment_shader.glsl
```

### 1.3 의존성 업데이트

```yaml
# pubspec.yaml 변경사항
dependencies:
  # 제거할 패키지
  # webview_flutter: ^4.10.0        # 제거
  # webview_flutter_android: ^4.0.0 # 제거
  # shelf: ^1.4.2                   # 제거
  # shelf_static: ^1.1.3            # 제거
  # mime: ^2.0.0                    # 제거

  # 유지할 패키지
  flutter_overlay_window: ^0.4.5    # 오버레이 기본 (백업용)
  permission_handler: ^11.3.1       # 권한 관리
  path_provider: ^2.1.5             # 파일 경로
  path: ^1.9.1                      # 경로 유틸
  file_picker: ^8.0.0               # 폴더 선택

  # 추가할 패키지
  ffi: ^2.1.0                       # FFI (필요시)
  rxdart: ^0.28.0                   # 반응형 이벤트 스트림
  equatable: ^2.0.5                 # 값 비교
```

---

## 📦 Phase 2: 네이티브 렌더링 구현 (2-3주)

### 2.1 Live2D Cubism SDK 통합

#### 2.1.1 SDK 준비
1. **Live2D Cubism SDK for Native** 다운로드
   - https://www.live2d.com/download/cubism-sdk/
   - Android용 네이티브 라이브러리 (.so 파일)

2. **라이센스 확인**
   - Free 버전: 개인/소규모 이용 가능
   - PRO 버전: 상업적 이용

3. **파일 구조**
```
android/app/src/main/
├── jniLibs/
│   ├── arm64-v8a/libLive2DCubismCore.so
│   ├── armeabi-v7a/libLive2DCubismCore.so
│   └── x86_64/libLive2DCubismCore.so
│
└── java/  (또는 kotlin/)
    └── com/live2d/sdk/cubism/
        ├── framework/          # Cubism Framework Java/Kotlin 래퍼
        └── ...
```

### 2.2 OpenGL ES 렌더러 구현

```kotlin
// Live2DRenderer.kt 핵심 구조
class Live2DRenderer(private val context: Context) : GLSurfaceView.Renderer {
    
    private var model: CubismModel? = null
    private var motionManager: MotionManager? = null
    private var expressionManager: ExpressionManager? = null
    
    // OpenGL 프로그램
    private var shaderProgram: Int = 0
    
    override fun onSurfaceCreated(gl: GL10?, config: EGLConfig?) {
        // OpenGL 초기화
        GLES20.glClearColor(0f, 0f, 0f, 0f)  // 투명 배경
        GLES20.glEnable(GLES20.GL_BLEND)
        GLES20.glBlendFunc(GLES20.GL_SRC_ALPHA, GLES20.GL_ONE_MINUS_SRC_ALPHA)
        
        // 셰이더 로드 및 컴파일
        loadShaders()
    }
    
    override fun onSurfaceChanged(gl: GL10?, width: Int, height: Int) {
        GLES20.glViewport(0, 0, width, height)
        updateProjectionMatrix(width, height)
    }
    
    override fun onDrawFrame(gl: GL10?) {
        GLES20.glClear(GLES20.GL_COLOR_BUFFER_BIT)
        
        model?.let { m ->
            // 1. 모션 업데이트
            motionManager?.update(m, deltaTime)
            
            // 2. 표정 업데이트
            expressionManager?.update(m, deltaTime)
            
            // 3. 물리 연산
            m.physics?.evaluate(deltaTime)
            
            // 4. 파라미터 업데이트 (눈 깜빡임, 호흡 등)
            updateAutoParameters(m)
            
            // 5. 렌더링
            m.update()
            m.draw(shaderProgram, projectionMatrix)
        }
    }
    
    fun loadModel(modelPath: String) {
        // 모델 로딩 로직
    }
    
    fun setTouchPoint(x: Float, y: Float) {
        // 터치 포인트 설정 (시선 추적용)
    }
    
    fun playMotion(motionGroup: String, index: Int, priority: Int) {
        // 모션 재생
    }
    
    fun setExpression(expressionId: String) {
        // 표정 설정
    }
}
```

### 2.3 오버레이 서비스 구현

```kotlin
// OverlayService.kt
class Live2DOverlayService : Service() {
    
    private lateinit var windowManager: WindowManager
    private lateinit var overlayView: Live2DSurfaceView
    private lateinit var gestureDetector: GestureDetectorManager
    
    // 오버레이 파라미터
    private val overlayParams = WindowManager.LayoutParams().apply {
        type = WindowManager.LayoutParams.TYPE_APPLICATION_OVERLAY
        flags = WindowManager.LayoutParams.FLAG_NOT_FOCUSABLE or
                WindowManager.LayoutParams.FLAG_LAYOUT_IN_SCREEN or
                WindowManager.LayoutParams.FLAG_NOT_TOUCH_MODAL
        format = PixelFormat.TRANSLUCENT
        gravity = Gravity.TOP or Gravity.START
        width = 300
        height = 400
    }
    
    override fun onCreate() {
        super.onCreate()
        windowManager = getSystemService(WINDOW_SERVICE) as WindowManager
        setupOverlayView()
        setupGestureDetection()
    }
    
    private fun setupOverlayView() {
        overlayView = Live2DSurfaceView(this).apply {
            setEGLContextClientVersion(2)
            setEGLConfigChooser(8, 8, 8, 8, 16, 0)  // RGBA8888
            holder.setFormat(PixelFormat.TRANSLUCENT)
            setZOrderOnTop(true)
        }
        windowManager.addView(overlayView, overlayParams)
    }
    
    private fun setupGestureDetection() {
        gestureDetector = GestureDetectorManager(this) { event ->
            // Flutter로 이벤트 전송
            EventDispatcher.dispatch(event)
        }
        
        overlayView.setOnTouchListener { _, event ->
            gestureDetector.onTouchEvent(event)
            true
        }
    }
    
    // ... 크기 조절, 위치 이동, 모델 로드 메서드들
}
```

---

## 📦 Phase 3: 터치 & 제스처 시스템 (1-2주)

### 3.1 제스처 인식 시스템

```kotlin
// GestureDetectorManager.kt
class GestureDetectorManager(
    context: Context,
    private val onGestureDetected: (InteractionEvent) -> Unit
) {
    
    private val tapDetector = TapDetector()
    private val longPressDetector = LongPressDetector()
    private val dragRecognizer = DragPatternRecognizer()
    
    fun onTouchEvent(event: MotionEvent): Boolean {
        when (event.actionMasked) {
            MotionEvent.ACTION_DOWN -> {
                startTracking(event)
            }
            MotionEvent.ACTION_MOVE -> {
                dragRecognizer.addPoint(event.x, event.y)
            }
            MotionEvent.ACTION_UP -> {
                analyzeGesture(event)
            }
        }
        return true
    }
    
    private fun analyzeGesture(event: MotionEvent) {
        val gesture = when {
            tapDetector.isTap() -> detectTapType()
            longPressDetector.isLongPress() -> GestureType.LONG_PRESS
            dragRecognizer.hasPattern() -> analyzeDragPattern()
            else -> GestureType.UNKNOWN
        }
        
        onGestureDetected(InteractionEvent(
            type = gesture,
            position = Position(event.x, event.y),
            timestamp = System.currentTimeMillis()
        ))
    }
}
```

### 3.2 드래그 패턴 인식

```kotlin
// DragPatternRecognizer.kt
class DragPatternRecognizer {
    
    private val points = mutableListOf<PointF>()
    
    // 인식 가능한 패턴들
    enum class DragPattern {
        SWIPE_UP,           // 위로 스와이프
        SWIPE_DOWN,         // 아래로 스와이프
        SWIPE_LEFT,         // 왼쪽 스와이프
        SWIPE_RIGHT,        // 오른쪽 스와이프
        CIRCLE_CW,          // 시계방향 원
        CIRCLE_CCW,         // 반시계방향 원
        ZIGZAG,             // 지그재그
        HEART,              // 하트 (❤)
        STAR,               // 별
        HEAD_PAT,           // 머리 쓰다듬기 (좌우 반복)
        CUSTOM              // 사용자 정의 패턴
    }
    
    fun addPoint(x: Float, y: Float) {
        points.add(PointF(x, y))
    }
    
    fun analyzePattern(): DragPattern {
        if (points.size < 3) return DragPattern.UNKNOWN
        
        // 1. 방향 분석
        val direction = calculateOverallDirection()
        
        // 2. 패턴 매칭
        return when {
            isSwipe(direction) -> direction.toSwipePattern()
            isCircle() -> detectCircleDirection()
            isZigzag() -> DragPattern.ZIGZAG
            isHeadPat() -> DragPattern.HEAD_PAT
            matchesCustomPattern() -> DragPattern.CUSTOM
            else -> DragPattern.UNKNOWN
        }
    }
    
    private fun isHeadPat(): Boolean {
        // 좌우 반복 움직임 감지 (머리 쓰다듬기)
        var directionChanges = 0
        var lastDirection = 0
        
        for (i in 1 until points.size) {
            val dx = points[i].x - points[i-1].x
            val currentDirection = if (dx > 0) 1 else -1
            
            if (currentDirection != lastDirection && lastDirection != 0) {
                directionChanges++
            }
            lastDirection = currentDirection
        }
        
        return directionChanges >= 3  // 3번 이상 방향 전환
    }
    
    private fun isCircle(): Boolean {
        // 시작점과 끝점이 가까운지, 회전 각도 합이 360도에 가까운지
        val startEnd = distance(points.first(), points.last())
        val totalAngle = calculateTotalRotation()
        
        return startEnd < threshold && abs(totalAngle) > 300
    }
}
```

### 3.3 상호작용 이벤트 시스템

```dart
// lib/features/live2d/domain/entities/interaction_event.dart
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
  
  // 시스템 이벤트
  overlayShown,
  overlayHidden,
  modelLoaded,
  
  // 외부 신호
  externalCommand,
}

class InteractionEvent {
  final InteractionType type;
  final Offset? position;
  final Map<String, dynamic>? extras;
  final DateTime timestamp;
  
  const InteractionEvent({
    required this.type,
    this.position,
    this.extras,
    DateTime? timestamp,
  }) : timestamp = timestamp ?? DateTime.now();
}
```

---

## 📦 Phase 4: 앱 연동 & 신호 시스템 (1-2주)

### 4.1 Flutter-Native 브릿지

```dart
// lib/features/live2d/data/services/live2d_native_bridge.dart
class Live2DNativeBridge {
  static const MethodChannel _methodChannel = 
      MethodChannel('com.example.app/live2d');
  static const EventChannel _eventChannel = 
      EventChannel('com.example.app/live2d/events');
  
  // 이벤트 스트림
  late final Stream<InteractionEvent> interactionEvents;
  
  // === 명령 전송 (Flutter → Native) ===
  
  Future<void> showOverlay() async {
    await _methodChannel.invokeMethod('showOverlay');
  }
  
  Future<void> hideOverlay() async {
    await _methodChannel.invokeMethod('hideOverlay');
  }
  
  Future<void> loadModel(String modelPath) async {
    await _methodChannel.invokeMethod('loadModel', {'path': modelPath});
  }
  
  Future<void> playMotion(String group, int index) async {
    await _methodChannel.invokeMethod('playMotion', {
      'group': group,
      'index': index,
    });
  }
  
  Future<void> setExpression(String expressionId) async {
    await _methodChannel.invokeMethod('setExpression', {
      'id': expressionId,
    });
  }
  
  Future<void> setScale(double scale) async {
    await _methodChannel.invokeMethod('setScale', {'scale': scale});
  }
  
  Future<void> setPosition(int x, int y) async {
    await _methodChannel.invokeMethod('setPosition', {'x': x, 'y': y});
  }
  
  // === 상호작용 전송 (외부 앱 연동용) ===
  
  Future<void> sendInteractionSignal(String signalName, {
    Map<String, dynamic>? data,
  }) async {
    await _methodChannel.invokeMethod('sendSignal', {
      'signal': signalName,
      'data': data,
    });
  }
  
  // === 이벤트 수신 (Native → Flutter) ===
  
  void initialize() {
    interactionEvents = _eventChannel
        .receiveBroadcastStream()
        .map((event) => InteractionEvent.fromMap(event));
  }
}
```

### 4.2 상호작용 연동 시스템

```dart
// lib/features/live2d/data/services/interaction_manager.dart
class InteractionManager {
  final Live2DNativeBridge _bridge;
  final StreamController<InteractionEvent> _eventController;
  
  // 상호작용 핸들러 맵
  final Map<InteractionType, List<InteractionHandler>> _handlers = {};
  
  // 외부 연동 리스너
  final List<ExternalInteractionListener> _externalListeners = [];
  
  InteractionManager(this._bridge) 
    : _eventController = StreamController.broadcast() {
    _bridge.interactionEvents.listen(_handleNativeEvent);
  }
  
  // 핸들러 등록
  void registerHandler(InteractionType type, InteractionHandler handler) {
    _handlers.putIfAbsent(type, () => []).add(handler);
  }
  
  // 외부 리스너 등록 (다른 앱 기능과 연동)
  void addExternalListener(ExternalInteractionListener listener) {
    _externalListeners.add(listener);
  }
  
  // 네이티브 이벤트 처리
  void _handleNativeEvent(InteractionEvent event) {
    // 1. 등록된 핸들러 실행
    _handlers[event.type]?.forEach((handler) => handler(event));
    
    // 2. 외부 리스너에게 전달
    for (final listener in _externalListeners) {
      listener.onInteraction(event);
    }
    
    // 3. 스트림으로 브로드캐스트
    _eventController.add(event);
  }
  
  // 외부에서 상호작용 트리거 (다른 앱 기능에서 Live2D 제어)
  Future<void> triggerInteraction(String command, {
    Map<String, dynamic>? params,
  }) async {
    await _bridge.sendInteractionSignal(command, data: params);
  }
}
```

### 4.3 앱 기능 연동 예시

```dart
// 다른 앱 기능에서 Live2D와 연동하는 예시

// 예: 채팅 서비스에서 AI 응답 시 Live2D 반응
class ChatService {
  final InteractionManager _interactionManager;
  
  Future<void> onAIResponse(String response, String emotion) async {
    // Live2D에 감정 표현 요청
    await _interactionManager.triggerInteraction('setEmotion', params: {
      'emotion': emotion,  // happy, sad, angry, surprised...
    });
    
    // 말하기 모션 시작
    await _interactionManager.triggerInteraction('startSpeaking');
  }
}

// 예: 알림 서비스에서 알림 시 Live2D 반응
class NotificationService {
  final InteractionManager _interactionManager;
  
  void onNotificationReceived(String type) {
    _interactionManager.triggerInteraction('notification', params: {
      'type': type,
    });
  }
}

// 예: Live2D 터치 이벤트 수신
class SomeFeatureController {
  void setupLive2DListeners(InteractionManager manager) {
    manager.registerHandler(InteractionType.headPat, (event) {
      // 머리 쓰다듬기 시 특별한 동작
      print('User is patting the head!');
    });
    
    manager.registerHandler(InteractionType.doubleTap, (event) {
      // 더블탭 시 메뉴 표시 등
      showQuickMenu();
    });
  }
}
```

---

## 📦 Phase 5: Live2DViewerEX 수준 기능 구현 (2-3주)

### 5.1 모델 브라우저

```dart
// lib/features/live2d/presentation/screens/model_browser_screen.dart
// 기능:
// - 폴더 탐색 (트리 뷰)
// - 모델 미리보기 썸네일
// - 모델 정보 표시 (이름, 버전, 모션 수, 표정 수)
// - 즐겨찾기
// - 최근 사용 모델
// - 검색/필터링
```

### 5.2 모션 & 표정 관리

```dart
// 모션 그룹 관리
class MotionConfig {
  final String groupName;
  final List<MotionInfo> motions;
  final int priority;  // 우선순위 (idle < normal < force)
  final bool loop;
}

// 표정 관리
class ExpressionConfig {
  final String id;
  final String displayName;
  final double blendWeight;  // 블렌딩 가중치
}

// 자동 동작 설정
class AutoBehaviorConfig {
  final bool enableEyeBlink;      // 눈 깜빡임
  final double blinkInterval;     // 깜빡임 주기
  final bool enableBreathing;     // 호흡
  final bool enableRandomMotion;  // 랜덤 모션
  final Duration randomInterval;  // 랜덤 모션 주기
  final bool enableLipSync;       // 립싱크
  final bool enableMouseTracking; // 마우스/터치 추적
}
```

### 5.3 세부 설정 화면

```dart
// 설정 카테고리
// 1. 디스플레이 설정
//    - 크기 (scale)
//    - 투명도 (opacity)
//    - 위치 (position)
//    - 항상 위 (always on top)
//    - 터치 투과 (touch pass-through)
//
// 2. 동작 설정
//    - 자동 눈 깜빡임
//    - 자동 호흡
//    - 랜덤 모션
//    - 터치 반응
//    - 시선 추적
//
// 3. 제스처 설정
//    - 탭 동작
//    - 더블탭 동작
//    - 롱프레스 동작
//    - 드래그 패턴 → 동작 매핑
//    - 영역별 터치 동작
//
// 4. 연동 설정
//    - 앱 기능 연동 on/off
//    - 외부 앱 연동 설정
//    - 알림 연동
//
// 5. 고급 설정
//    - 렌더링 품질
//    - FPS 제한
//    - 배터리 최적화
```

---

## 📦 Phase 6: 최적화 & 안정화 (1-2주)

### 6.1 성능 최적화

```kotlin
// 렌더링 최적화
- 프레임 레이트 제한 (30fps / 60fps 선택)
- 백그라운드 시 렌더링 중지
- 저전력 모드 지원
- 텍스처 품질 조절

// 메모리 최적화
- 모델 언로드 시 텍스처 해제
- 미사용 리소스 정리
- 메모리 캐싱 최적화
```

### 6.2 배터리 최적화

```kotlin
// 배터리 절약 모드
class PowerSaveConfig {
    var reducedFrameRate: Boolean = true      // FPS 감소
    var disablePhysics: Boolean = false       // 물리 연산 비활성화
    var disableBreathing: Boolean = false     // 호흡 비활성화
    var simplifiedRendering: Boolean = false  // 단순 렌더링
}
```

### 6.3 에러 처리 & 복구

```dart
// 안정성 향상
- 모델 로드 실패 시 복구
- 오버레이 크래시 시 자동 재시작
- 메모리 부족 시 품질 자동 저하
- 로그 수집 및 에러 리포팅
```

---

## 🗓️ 전체 타임라인

| Phase | 기간 | 주요 작업 | 상태 |
|-------|------|----------|------|
| **Phase 1** | 1-2주 | 프로젝트 구조 재설계, SDK 준비 | ✅ 완료 |
| **Phase 2** | 2-3주 | 네이티브 렌더러, 오버레이 서비스 | ✅ 완료 |
| **Phase 3** | 1-2주 | 제스처 인식 시스템 | ✅ 완료 |
| **Phase 4** | 1-2주 | 앱 연동, 신호 시스템 | ✅ 완료 |
| **Phase 5** | 2-3주 | ViewerEX 수준 기능 | ⏳ 부분 완료 |
| **Phase 6** | 1-2주 | 최적화, 안정화 | ✅ 완료 |
| **Phase 7** | 1-2주 | **Live2D Cubism SDK 통합** | 🔴 진행 필요 |
| **Phase 8** | 1-2주 | **기능 완성 및 최종 안정화** | 🔴 대기 |

**총 예상 기간: 8-14주** → **현재 6주차 완료, 2주 추가 필요**

---

## 📦 Phase 7: Live2D Cubism SDK 통합 (핵심) 🔴

> **상세 계획**: [LIVE2D_PHASE7_COMPLETION_PLAN.md](./LIVE2D_PHASE7_COMPLETION_PLAN.md) 참조

### 7.1 SDK 설치

1. **다운로드**: https://www.live2d.com/download/cubism-sdk/
2. **파일 배치**:
   ```
   android/app/src/main/jniLibs/
   ├── arm64-v8a/libLive2DCubismCore.so
   ├── armeabi-v7a/libLive2DCubismCore.so
   └── x86_64/libLive2DCubismCore.so
   ```

### 7.2 핵심 구현 사항

- [ ] `System.loadLibrary("Live2DCubismCore")` 연동
- [ ] `CubismFramework.initialize()` 초기화
- [ ] `CubismModelWrapper` 클래스 구현
- [ ] moc3 파일 로드 및 렌더링
- [ ] 모션 재생 시스템
- [ ] 표정 시스템
- [ ] 물리 연산 연동
- [ ] 눈 깜빡임/호흡 자동화
- [ ] 시선 추적

### 7.3 예상 기간: 1-2주

---

## 📦 Phase 8: 기능 완성 및 최종 안정화 🔴

### 8.1 UI/UX 완성

- [ ] 모션 선택 UI
- [ ] 표정 선택 UI
- [ ] 파라미터 실시간 조절
- [ ] 제스처 → 동작 매핑 설정

### 8.2 성능 최적화

- [ ] 렌더링 최적화 (FPS, 저전력)
- [ ] 메모리 캐싱
- [ ] OOM 방지

### 8.3 안정화

- [ ] 에러 복구 로직
- [ ] 크래시 방지
- [ ] 테스트 및 QA

### 8.4 예상 기간: 1-2주

---

## ⚠️ 주의사항 & 리스크

### 라이센스
- Live2D Cubism SDK 라이센스 확인 필요
- 상업적 이용 시 PRO 라이센스 필요 가능

### 기술적 도전
- OpenGL ES와 Live2D SDK 통합의 복잡성
- Android 버전별 오버레이 권한 차이
- 메모리 관리 및 리소스 해제

### 대안 검토
- **flutter_live2d** 패키지가 있다면 활용 검토
- **Cubism Web SDK + flutter_gl** 조합 검토
- **Unity 임베딩** 방식 검토 (더 간단할 수 있음)

---

## 📁 마이그레이션 체크리스트

### 제거할 파일/코드
- [x] `lib/widgets/live2d_overlay_widget.dart` (WebView 버전) - ✅ 제거됨/미사용
- [x] `lib/features/live2d/data/services/live2d_local_server_service.dart` - ✅ 제거됨
- [ ] `assets/web/` (Live2D Web 관련) - 유지 (백업용)
- [ ] `assets/live2d/viewer.html` - 유지 (백업용)
- [x] WebView 관련 pubspec 의존성 - ✅ 미사용

### 유지할 파일/코드
- [x] `lib/features/live2d/data/models/live2d_model_info.dart`
- [x] `lib/features/live2d/data/models/live2d_settings.dart` (확장)
- [x] `lib/features/live2d/data/services/live2d_storage_service.dart`
- [x] `lib/features/live2d/data/services/live2d_log_service.dart`
- [x] `lib/features/live2d/data/repositories/live2d_repository.dart` (수정)
- [x] `lib/features/live2d/presentation/controllers/live2d_controller.dart` (수정)
- [x] 권한 관련 코드

### 새로 작성할 파일 (완료)
- [x] Android Native Live2D 모듈 전체
- [x] Platform Channel 브릿지
- [x] 제스처 인식 시스템
- [x] 상호작용 이벤트 시스템
- [ ] 확장된 설정 화면들 (Phase 8)

### Phase 7에서 추가/수정할 파일
- [ ] `android/app/src/main/jniLibs/**/*.so` - SDK 라이브러리
- [ ] `android/.../live2d/cubism/` - SDK 래퍼 클래스들
- [ ] `android/.../live2d/core/Live2DManager.kt` - SDK 연동
- [ ] `android/.../live2d/renderer/Live2DGLRenderer.kt` - Cubism 렌더링 추가
- [ ] `lib/.../live2d_native_bridge.dart` - 모션/표정 API 확장

---

## 🎯 최종 목표 상태

```
[완료 시 동작]

1. 오버레이 표시 → 실제 Live2D 모델 렌더링 (애니메이션 포함)
2. 자동 동작 → 눈 깜빡임, 호흡, Idle 모션 자동 재생
3. 터치 반응 → 영역별 모션/표정 반응
4. 시선 추적 → 터치 위치를 바라봄
5. 설정 UI → 모션/표정 선택, 제스처 매핑
6. 안정적 동작 → 에러 복구, 메모리 관리

[최종 아키텍처]

Flutter App
    └── Platform Channel
            └── Live2D Native Module
                    ├── Live2DManager (SDK 관리)
                    ├── CubismModelWrapper (모델 렌더링)
                    ├── OverlayService (윈도우 관리)
                    └── GestureManager (터치 처리)
```

---

## 🔗 참고 자료

- [Live2D Cubism SDK Documentation](https://docs.live2d.com/cubism-sdk-manual/top/)
- [Live2D Cubism SDK for Native](https://www.live2d.com/download/cubism-sdk/)
- [Android WindowManager Overlay](https://developer.android.com/reference/android/view/WindowManager)
- [OpenGL ES on Android](https://developer.android.com/develop/ui/views/graphics/opengl)
- [Flutter Platform Channels](https://docs.flutter.dev/platform-integration/platform-channels)
