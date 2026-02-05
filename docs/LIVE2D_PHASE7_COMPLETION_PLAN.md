# Live2D 완성 계획서 - Phase 7 & 8

## 📋 현황 분석

### 현재 달성 사항 (Phase 1-6 완료)

| 구분 | 항목 | 상태 |
|------|------|------|
| **인프라** | Android Native 모듈 구조 | ✅ 완료 |
| | Flutter Platform Channel 브릿지 | ✅ 완료 |
| | Foreground Service 오버레이 | ✅ 완료 |
| | GLSurfaceView + OpenGL ES 2.0 | ✅ 완료 |
| **렌더링** | 플레이스홀더 셰이더 | ✅ 완료 |
| | 텍스처 프리뷰 렌더러 | ✅ 완료 |
| | GL 스레드 동기화 | ✅ 완료 |
| | 텍스처 크기 제한 처리 | ✅ 완료 |
| **모델 관리** | model3.json 파서 | ✅ 완료 |
| | 모션/표정 정보 추출 | ✅ 완료 |
| | 텍스처 경로 추출 | ✅ 완료 |
| **제스처** | GestureDetectorManager | ✅ 완료 |
| | 기본 터치 처리 | ✅ 완료 |
| **설정** | FPS 조절 | ✅ 완료 |
| | 저전력 모드 | ✅ 완료 |
| | 위치/크기 조절 | ✅ 완료 |

### 현재 문제점 ⚠️

```
❌ Live2D Cubism SDK for Native 미설치
   → jniLibs/ 폴더 비어있음
   → libLive2DCubismCore.so 없음
   
❌ 실제 모델 렌더링 불가
   → TextureModelRenderer는 텍스처 이미지만 표시
   → moc3 파일 로드/렌더링 미구현
   → 모션/표정 애니메이션 불가
   
❌ SDK 연동 코드 미완성
   → Live2DManager: 플레이스홀더 모드
   → Live2DModel: 파싱만, 렌더링 연동 없음
```

### 현재 동작 방식

```
[현재] 텍스처 프리뷰 모드
model3.json → 텍스처 경로 추출 → texture_00.png 로드 → OpenGL로 사각형에 텍스처 매핑

[목표] 실제 Live2D 렌더링
model3.json → moc3 로드 → Cubism SDK 초기화 → 모션/물리 연산 → 프레임별 메시 렌더링
```

---

## 🎯 Phase 7: Live2D Cubism SDK 통합 (핵심)

### 7.1 SDK 설치 및 설정

#### 7.1.1 SDK 다운로드
```
1. Live2D Cubism SDK for Native 다운로드
   - URL: https://www.live2d.com/download/cubism-sdk/
   - 버전: Cubism 4 SDK for Native (R7 이상 권장)
   - 라이센스: Free (개인/소규모), PRO (상업용)

2. SDK 구조
   CubismSdkForNative-4-r.7/
   ├── Core/
   │   ├── include/
   │   │   └── Live2DCubismCore.h
   │   └── lib/
   │       └── android/
   │           ├── arm64-v8a/libLive2DCubismCore.so
   │           ├── armeabi-v7a/libLive2DCubismCore.so
   │           └── x86_64/libLive2DCubismCore.so
   │
   └── Framework/
       └── src/
           └── ... (Java/Kotlin 래퍼)
```

#### 7.1.2 SDK 파일 배치
```bash
# .so 파일 복사
android/app/src/main/jniLibs/
├── arm64-v8a/
│   └── libLive2DCubismCore.so      # 복사
├── armeabi-v7a/
│   └── libLive2DCubismCore.so      # 복사
└── x86_64/
    └── libLive2DCubismCore.so      # 복사

# Framework 파일 복사
android/app/src/main/kotlin/.../live2d/
└── cubism/                          # NEW: SDK Framework 래퍼
    ├── CubismFramework.kt
    ├── CubismModel.kt
    ├── CubismMotionManager.kt
    ├── CubismExpressionManager.kt
    ├── CubismPhysics.kt
    ├── CubismPose.kt
    ├── CubismBreath.kt
    ├── CubismEyeBlink.kt
    └── CubismRenderer.kt
```

#### 7.1.3 build.gradle.kts 업데이트
```kotlin
android {
    // ...
    
    // NDK 설정 (이미 있을 수 있음)
    ndkVersion = "25.1.8937393"  // 적절한 버전
    
    // jniLibs 경로 확인
    sourceSets {
        getByName("main") {
            jniLibs.srcDirs("src/main/jniLibs")
        }
    }
}
```

### 7.2 SDK 래퍼 구현

#### 7.2.1 Live2DManager 업데이트
```kotlin
// 현재 (플레이스홀더):
fun initialize(context: Context): Boolean {
    // TODO: Live2D SDK .so 파일 로드
    Live2DLogger.i("Live2D Manager 초기화됨", "플레이스홀더 모드")
    isSdkLoaded = false
    return true
}

// 변경 후 (실제 SDK):
fun initialize(context: Context): Boolean {
    try {
        // 네이티브 라이브러리 로드
        System.loadLibrary("Live2DCubismCore")
        
        // Cubism Framework 초기화
        CubismFramework.initialize()
        CubismFramework.setLogFunction { msg -> Live2DLogger.d("Cubism", msg) }
        
        isSdkLoaded = true
        isInitialized = true
        Live2DLogger.i("Live2D SDK 초기화 완료", "버전: ${getVersion()}")
        return true
    } catch (e: UnsatisfiedLinkError) {
        Live2DLogger.e("SDK 라이브러리 로드 실패", e)
        return false
    }
}
```

#### 7.2.2 CubismModel 래퍼 생성
```kotlin
// android/app/src/main/kotlin/.../live2d/cubism/CubismModelWrapper.kt

class CubismModelWrapper(private val context: Context) {
    
    private var model: CubismUserModel? = null
    private var motionManager: CubismMotionManager? = null
    private var expressionManager: CubismExpressionManager? = null
    private var physics: CubismPhysics? = null
    private var pose: CubismPose? = null
    private var breath: CubismBreath? = null
    private var eyeBlink: CubismEyeBlink? = null
    
    // 텍스처 ID 배열
    private val textureIds = mutableListOf<Int>()
    
    /**
     * 모델 로드
     */
    fun loadModel(modelPath: String): Boolean {
        try {
            val modelFile = File(modelPath)
            val modelDir = modelFile.parentFile ?: return false
            
            // model3.json 파싱
            val modelJson = ModelSettingJson(modelPath)
            
            // moc3 로드
            val mocPath = modelDir.resolve(modelJson.getMocFileName()).absolutePath
            val mocBuffer = readFileToBuffer(mocPath)
            model = CubismUserModel()
            model?.loadModel(mocBuffer)
            
            // 텍스처 로드
            for (i in 0 until modelJson.getTextureCount()) {
                val texturePath = modelDir.resolve(modelJson.getTextureFileName(i)).absolutePath
                val textureId = loadTexture(texturePath)
                textureIds.add(textureId)
            }
            model?.renderer?.setTextures(textureIds)
            
            // 물리 연산 설정
            val physicsPath = modelJson.getPhysicsFileName()
            if (physicsPath.isNotEmpty()) {
                physics = CubismPhysics.create(modelDir.resolve(physicsPath).absolutePath)
            }
            
            // 포즈 설정
            val posePath = modelJson.getPoseFileName()
            if (posePath.isNotEmpty()) {
                pose = CubismPose.create(modelDir.resolve(posePath).absolutePath)
            }
            
            // 눈 깜빡임 설정
            eyeBlink = CubismEyeBlink.create(model?.model)
            
            // 호흡 설정
            breath = CubismBreath.create()
            
            // 모션 매니저 초기화
            motionManager = CubismMotionManager()
            expressionManager = CubismExpressionManager()
            
            // 모션 프리로드
            preloadMotions(modelJson, modelDir)
            
            // 표정 프리로드
            preloadExpressions(modelJson, modelDir)
            
            return true
        } catch (e: Exception) {
            Live2DLogger.e("모델 로드 실패", e)
            return false
        }
    }
    
    /**
     * 모션 재생
     */
    fun playMotion(groupName: String, index: Int, priority: Int): Boolean {
        val motion = motions["${groupName}_$index"] ?: return false
        motionManager?.startMotion(motion, priority)
        return true
    }
    
    /**
     * 표정 설정
     */
    fun setExpression(expressionId: String): Boolean {
        val expression = expressions[expressionId] ?: return false
        expressionManager?.setExpression(expression)
        return true
    }
    
    /**
     * 프레임 업데이트
     */
    fun update(deltaTime: Float) {
        model?.let { m ->
            // 모션 업데이트
            motionManager?.updateMotion(m.model, deltaTime)
            
            // 표정 업데이트
            expressionManager?.updateMotion(m.model, deltaTime)
            
            // 물리 연산
            physics?.evaluate(m.model, deltaTime)
            
            // 포즈 업데이트
            pose?.updateParameters(m.model, deltaTime)
            
            // 눈 깜빡임
            eyeBlink?.updateParameters(m.model, deltaTime)
            
            // 호흡
            breath?.updateParameters(m.model, deltaTime)
            
            // 모델 업데이트
            m.model.update()
        }
    }
    
    /**
     * 렌더링
     */
    fun draw(projectionMatrix: FloatArray) {
        model?.let { m ->
            m.renderer?.setMvpMatrix(projectionMatrix)
            m.renderer?.drawModel()
        }
    }
    
    /**
     * 시선 설정
     */
    fun setLookAt(x: Float, y: Float) {
        model?.let { m ->
            m.model.setParameterValue(CubismDefaultParameterId.ParamAngleX, x * 30f)
            m.model.setParameterValue(CubismDefaultParameterId.ParamAngleY, y * 30f)
            m.model.setParameterValue(CubismDefaultParameterId.ParamBodyAngleX, x * 10f)
        }
    }
    
    /**
     * 리소스 해제
     */
    fun dispose() {
        // 텍스처 해제
        textureIds.forEach { GLES20.glDeleteTextures(1, intArrayOf(it), 0) }
        textureIds.clear()
        
        // 모델 해제
        model?.dispose()
        model = null
        
        physics = null
        pose = null
        breath = null
        eyeBlink = null
        motionManager = null
        expressionManager = null
    }
}
```

#### 7.2.3 Live2DGLRenderer 업데이트
```kotlin
// 현재: TextureModelRenderer 사용
// 변경: CubismModelWrapper 사용

class Live2DGLRenderer(private val context: Context) : GLSurfaceView.Renderer {
    
    // 변경: 실제 Cubism 모델 래퍼
    private var cubismModel: CubismModelWrapper? = null
    
    // 텍스처 렌더러는 폴백용으로 유지
    private var textureRenderer: TextureModelRenderer? = null
    
    // SDK 사용 가능 여부
    private val useCubismSdk: Boolean
        get() = Live2DManager.getInstance().isSdkAvailable()
    
    override fun onDrawFrame(gl: GL10?) {
        GLES20.glClear(GLES20.GL_COLOR_BUFFER_BIT)
        
        if (useCubismSdk && cubismModel != null) {
            // 실제 Live2D 렌더링
            val deltaTime = calculateDeltaTime()
            cubismModel?.update(deltaTime)
            cubismModel?.draw(mvpMatrix)
        } else {
            // 폴백: 텍스처 프리뷰
            textureRenderer?.draw(mvpMatrix, modelOpacity)
        }
    }
    
    fun loadModel(modelPath: String, modelName: String): Boolean {
        if (useCubismSdk) {
            // Cubism SDK로 모델 로드
            cubismModel?.dispose()
            cubismModel = CubismModelWrapper(context)
            return cubismModel?.loadModel(modelPath) ?: false
        } else {
            // 폴백: 텍스처 프리뷰
            return loadTexturePreview(modelPath)
        }
    }
}
```

### 7.3 모션/표정 시스템 연동

#### 7.3.1 MethodHandler 확장
```kotlin
// Live2DMethodHandler.kt 확장

// 모션 관련
"playMotion" -> {
    val group = call.argument<String>("group") ?: "Idle"
    val index = call.argument<Int>("index") ?: 0
    val priority = call.argument<Int>("priority") ?: 2
    
    surfaceView?.playMotion(group, index, priority)
    result.success(mapOf("success" to true))
}

"stopMotion" -> {
    surfaceView?.stopCurrentMotion()
    result.success(mapOf("success" to true))
}

"getMotionGroups" -> {
    val groups = surfaceView?.getMotionGroups() ?: emptyMap()
    result.success(groups)
}

// 표정 관련
"setExpression" -> {
    val expressionId = call.argument<String>("id") ?: ""
    surfaceView?.setExpression(expressionId)
    result.success(mapOf("success" to true))
}

"getExpressions" -> {
    val expressions = surfaceView?.getExpressions() ?: emptyList()
    result.success(expressions)
}

// 자동 동작
"setAutoBlink" -> {
    val enabled = call.argument<Boolean>("enabled") ?: true
    surfaceView?.setAutoBlink(enabled)
    result.success(mapOf("success" to true))
}

"setAutoBreath" -> {
    val enabled = call.argument<Boolean>("enabled") ?: true
    surfaceView?.setAutoBreath(enabled)
    result.success(mapOf("success" to true))
}

// 시선 추적
"setLookAt" -> {
    val x = call.argument<Double>("x")?.toFloat() ?: 0f
    val y = call.argument<Double>("y")?.toFloat() ?: 0f
    surfaceView?.setLookAt(x, y)
    result.success(mapOf("success" to true))
}
```

#### 7.3.2 Flutter 브릿지 확장
```dart
// live2d_native_bridge.dart 확장

// 모션 재생
Future<bool> playMotion(String group, int index, {int priority = 2}) async {
  final result = await _methodChannel.invokeMethod('playMotion', {
    'group': group,
    'index': index,
    'priority': priority,
  });
  return result['success'] == true;
}

// 모션 정지
Future<void> stopMotion() async {
  await _methodChannel.invokeMethod('stopMotion');
}

// 모션 그룹 조회
Future<Map<String, List<String>>> getMotionGroups() async {
  final result = await _methodChannel.invokeMethod('getMotionGroups');
  return Map<String, List<String>>.from(result);
}

// 표정 설정
Future<bool> setExpression(String expressionId) async {
  final result = await _methodChannel.invokeMethod('setExpression', {
    'id': expressionId,
  });
  return result['success'] == true;
}

// 자동 눈 깜빡임
Future<void> setAutoBlink(bool enabled) async {
  await _methodChannel.invokeMethod('setAutoBlink', {'enabled': enabled});
}

// 자동 호흡
Future<void> setAutoBreath(bool enabled) async {
  await _methodChannel.invokeMethod('setAutoBreath', {'enabled': enabled});
}

// 시선 설정
Future<void> setLookAt(double x, double y) async {
  await _methodChannel.invokeMethod('setLookAt', {'x': x, 'y': y});
}
```

### 7.4 체크리스트

- [ ] Live2D Cubism SDK for Native 다운로드
- [ ] .so 파일 jniLibs 폴더에 배치
- [ ] build.gradle.kts NDK 설정 확인
- [ ] CubismFramework 초기화 코드 구현
- [ ] CubismModelWrapper 클래스 생성
- [ ] Live2DManager SDK 연동 구현
- [ ] Live2DGLRenderer Cubism 렌더링 추가
- [ ] 모션 재생/정지 구현
- [ ] 표정 설정 구현
- [ ] 물리 연산 연동
- [ ] 눈 깜빡임/호흡 자동화
- [ ] 시선 추적 구현
- [ ] Flutter 브릿지 메서드 확장
- [ ] 테스트: 모델 로드
- [ ] 테스트: 모션 재생
- [ ] 테스트: 표정 변경
- [ ] 테스트: 시선 추적

---

## 🎯 Phase 8: 기능 완성 및 안정화

### 8.1 UI/UX 개선

#### 8.1.1 모션/표정 선택 UI
```dart
// lib/features/live2d/presentation/widgets/motion_selector_widget.dart

class MotionSelectorWidget extends StatelessWidget {
  final Map<String, List<String>> motionGroups;
  final Function(String group, int index) onMotionSelected;
  
  // 그룹별 모션 목록 표시
  // 탭하면 해당 모션 재생
}

// lib/features/live2d/presentation/widgets/expression_selector_widget.dart

class ExpressionSelectorWidget extends StatelessWidget {
  final List<String> expressions;
  final String? currentExpression;
  final Function(String) onExpressionSelected;
  
  // 표정 목록 그리드 표시
  // 탭하면 해당 표정 적용
}
```

#### 8.1.2 실시간 파라미터 조절
```dart
// lib/features/live2d/presentation/screens/parameter_editor_screen.dart

class ParameterEditorScreen extends StatelessWidget {
  // 모델 파라미터 실시간 조절
  // - 눈 크기
  // - 입 모양
  // - 고개 기울기
  // - 몸 기울기
  // 슬라이더로 조절, 변경 시 즉시 반영
}
```

### 8.2 제스처 → 동작 매핑

#### 8.2.1 제스처 설정 화면
```dart
// lib/features/live2d/presentation/screens/gesture_mapping_screen.dart

class GestureMappingScreen extends StatelessWidget {
  // 제스처 → 동작 매핑 설정
  // 예:
  //   - 머리 탭 → 머리 쓰다듬기 모션
  //   - 몸 탭 → 부끄러워하는 표정
  //   - 더블탭 → 특수 모션
  //   - 좌우 드래그 → 시선 따라가기
}
```

#### 8.2.2 영역 기반 터치 감지
```kotlin
// 모델의 특정 영역 터치 감지

enum class TouchArea {
    HEAD,       // 머리
    FACE,       // 얼굴
    BODY,       // 몸통
    NONE        // 영역 외
}

fun detectTouchArea(x: Float, y: Float): TouchArea {
    // 모델의 히트 영역 확인 (model3.json에 정의된 경우)
    model?.let { m ->
        for (i in 0 until m.hitAreaCount) {
            val areaName = m.getHitAreaName(i)
            if (m.isHit(areaName, x, y)) {
                return when {
                    areaName.contains("Head", true) -> TouchArea.HEAD
                    areaName.contains("Face", true) -> TouchArea.FACE
                    areaName.contains("Body", true) -> TouchArea.BODY
                    else -> TouchArea.BODY
                }
            }
        }
    }
    
    // 히트 영역 미정의 시 좌표 기반 추정
    return when {
        y < surfaceHeight * 0.3f -> TouchArea.HEAD
        y < surfaceHeight * 0.6f -> TouchArea.FACE
        else -> TouchArea.BODY
    }
}
```

### 8.3 성능 최적화

#### 8.3.1 렌더링 최적화
```kotlin
// FPS 제한
private var targetFps = 30  // 기본 30fps (배터리 절약)
private var frameInterval = 1000L / targetFps

// 화면 꺼짐/백그라운드 시 렌더링 중지
fun onPause() {
    isPaused = true
    // 렌더링 루프 정지
}

fun onResume() {
    isPaused = false
    // 렌더링 재개
}

// 저전력 모드
fun setLowPowerMode(enabled: Boolean) {
    targetFps = if (enabled) 15 else 30
    // 물리 연산 간소화
    // 텍스처 품질 저하
}
```

#### 8.3.2 메모리 최적화
```kotlin
// 텍스처 캐싱 및 해제
class TextureCache {
    private val cache = LruCache<String, Int>(maxSize = 10)
    
    fun getTexture(path: String): Int {
        return cache.get(path) ?: loadAndCache(path)
    }
    
    fun clear() {
        cache.evictAll()
    }
}

// 모델 언로드 시 리소스 정리
fun unloadModel() {
    cubismModel?.dispose()
    cubismModel = null
    textureCache.clear()
    System.gc()
}
```

### 8.4 에러 처리 및 복구

```kotlin
// 안정성 향상

// 모델 로드 실패 시 복구
fun loadModelSafe(path: String): Boolean {
    return try {
        loadModel(path)
    } catch (e: Exception) {
        Live2DLogger.e("모델 로드 실패", e)
        // 텍스처 프리뷰로 폴백
        loadTexturePreview(path)
    }
}

// 오버레이 크래시 시 자동 재시작
class OverlayWatchdog {
    fun onServiceCrash() {
        // 3초 후 서비스 재시작
        Handler(Looper.getMainLooper()).postDelayed({
            restartOverlayService()
        }, 3000)
    }
}

// OOM 방지
fun onLowMemory() {
    // 텍스처 품질 저하
    // 미사용 리소스 해제
    textureCache.trimToSize(5)
}
```

### 8.5 테스트 및 검증

#### 8.5.1 단위 테스트
```kotlin
// SDK 초기화 테스트
@Test
fun testSdkInitialization() {
    val result = Live2DManager.getInstance().initialize(context)
    assertTrue(result)
    assertTrue(Live2DManager.getInstance().isSdkAvailable())
}

// 모델 로드 테스트
@Test
fun testModelLoading() {
    val wrapper = CubismModelWrapper(context)
    val result = wrapper.loadModel(testModelPath)
    assertTrue(result)
}

// 모션 재생 테스트
@Test
fun testMotionPlayback() {
    val wrapper = CubismModelWrapper(context)
    wrapper.loadModel(testModelPath)
    val result = wrapper.playMotion("Idle", 0, 2)
    assertTrue(result)
}
```

#### 8.5.2 통합 테스트
```dart
// Flutter 통합 테스트

testWidgets('Live2D overlay integration', (tester) async {
  // 오버레이 표시
  await Live2DNativeBridge.showOverlay();
  
  // 모델 로드
  await Live2DNativeBridge.loadModel(testModelPath);
  
  // 모션 재생
  final result = await Live2DNativeBridge.playMotion('Idle', 0);
  expect(result, true);
  
  // 표정 변경
  await Live2DNativeBridge.setExpression('happy');
});
```

### 8.6 체크리스트

- [ ] 모션 선택 UI 위젯
- [ ] 표정 선택 UI 위젯
- [ ] 파라미터 에디터 화면
- [ ] 제스처 → 동작 매핑 화면
- [ ] 영역 기반 터치 감지
- [ ] FPS 제한 최적화
- [ ] 메모리 캐싱 최적화
- [ ] 에러 복구 로직
- [ ] OOM 방지 처리
- [ ] 단위 테스트 작성
- [ ] 통합 테스트 작성
- [ ] 성능 프로파일링
- [ ] 최종 사용자 테스트

---

## 📅 타임라인

| Phase | 예상 기간 | 주요 작업 |
|-------|----------|----------|
| **Phase 7.1** | 1-2일 | SDK 다운로드, 파일 배치, 빌드 확인 |
| **Phase 7.2** | 3-4일 | CubismModelWrapper 구현, SDK 연동 |
| **Phase 7.3** | 2-3일 | 모션/표정/물리 시스템 연동 |
| **Phase 7.4** | 1일 | 테스트 및 디버깅 |
| **Phase 8.1** | 2-3일 | UI/UX 개선 (모션/표정 선택) |
| **Phase 8.2** | 2-3일 | 제스처 매핑 시스템 |
| **Phase 8.3** | 1-2일 | 성능 최적화 |
| **Phase 8.4** | 1-2일 | 안정화, 에러 처리 |
| **Phase 8.5** | 1-2일 | 테스트 및 QA |

**총 예상 기간: 2-3주**

---

## ⚠️ 주요 고려사항

### 1. Live2D SDK 라이센스
- **Free Plan**: 개인/소규모 팀, 연 매출 1000만엔 이하
- **PRO Plan**: 상업적 이용, 대규모 프로젝트
- 배포 전 라이센스 확인 필수

### 2. SDK 버전 호환성
- Cubism 4.x 모델만 지원 (moc3 형식)
- Cubism 2.x/3.x 모델 (moc 형식)은 미지원
- 사용할 모델의 Cubism 버전 확인 필요

### 3. 안드로이드 호환성
- 최소 API 레벨: 21 (Android 5.0)
- OpenGL ES 2.0 이상 필요
- 일부 저사양 기기에서 성능 이슈 가능

### 4. 대안 검토 (SDK 설치 어려울 경우)
```
옵션 A: Live2D Cubism Web SDK + WebView (현재 방식으로 회귀)
  - 장점: SDK 별도 설치 불필요
  - 단점: 성능 오버헤드, 네이티브 기능 제한

옵션 B: Unity Embedding
  - 장점: Live2D Unity SDK 활용 가능
  - 단점: 앱 크기 증가, 복잡도 증가

옵션 C: 커뮤니티 SDK 래퍼 사용
  - live2d-android 등 오픈소스 프로젝트 활용
  - 유지보수 상태 확인 필요
```

---

## 🔗 필요 리소스

### SDK 다운로드
- [Live2D Cubism SDK for Native](https://www.live2d.com/download/cubism-sdk/)

### 문서
- [Cubism SDK Manual](https://docs.live2d.com/cubism-sdk-manual/top/)
- [Cubism SDK for Native API Reference](https://docs.live2d.com/cubism-sdk-manual/cubism-native-framework/)

### 샘플 프로젝트
- SDK 패키지 내 Samples/OpenGL 폴더 참고
- [GitHub - Live2D/CubismNativeSamples](https://github.com/Live2D/CubismNativeSamples)

---

## 📊 최종 목표 상태

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
