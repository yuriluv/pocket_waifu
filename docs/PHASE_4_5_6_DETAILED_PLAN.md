# Phase 4, 5, 6 상세 구현 계획

## 📋 현재 완료 상태 (Phase 1-3)

| 항목 | 상태 | 비고 |
|------|------|------|
| Native 오버레이 서비스 | ✅ 완료 | Live2DOverlayService.kt |
| OpenGL 렌더러 (플레이스홀더) | ✅ 완료 | Live2DGLRenderer.kt |
| Platform Channel 기본 구조 | ✅ 완료 | MethodChannel + EventChannel |
| 로깅 시스템 | ✅ 완료 | Live2DLogger.kt + Flutter 연동 |
| 터치 이벤트 기본 전달 | ✅ 완료 | tap, doubleTap, longPress |
| 드래그 이동 | ✅ 완료 | 오버레이 위치 이동 |

---

## 📦 Phase 4: 상호작용 시스템 & 앱 연동 (상세)

### 4.1 목표
- 터치/제스처 이벤트의 체계적인 처리 시스템 구축
- Flutter 앱의 다른 기능들과 Live2D 오버레이 간 양방향 연동
- 외부 신호(AI 응답, 알림 등)에 대한 Live2D 반응 시스템

### 4.2 구현 항목

#### 4.2.1 상호작용 이벤트 정의 (Domain Layer)

```
lib/features/live2d/domain/
├── entities/
│   ├── interaction_event.dart      # 상호작용 이벤트 엔티티
│   ├── interaction_type.dart       # 이벤트 타입 enum
│   └── interaction_response.dart   # 반응 액션 정의
└── repositories/
    └── i_interaction_repository.dart  # 인터페이스
```

**InteractionType 정의:**
```dart
enum InteractionType {
  // === 기본 터치 ===
  tap,              // 단일 탭
  doubleTap,        // 더블 탭
  longPress,        // 롱프레스
  
  // === 스와이프 ===
  swipeUp,          // 위로 스와이프
  swipeDown,        // 아래로 스와이프
  swipeLeft,        // 왼쪽 스와이프
  swipeRight,       // 오른쪽 스와이프
  
  // === 특수 제스처 ===
  headPat,          // 머리 쓰다듬기 (좌우 반복)
  poke,             // 찌르기 (빠른 탭)
  
  // === 시스템 이벤트 ===
  overlayShown,     // 오버레이 표시됨
  overlayHidden,    // 오버레이 숨김
  modelLoaded,      // 모델 로드됨
  modelUnloaded,    // 모델 언로드됨
  
  // === 외부 신호 ===
  aiSpeakStart,     // AI 말하기 시작
  aiSpeakEnd,       // AI 말하기 종료
  notification,     // 알림 수신
  emotionChange,    // 감정 변화 신호
  customSignal,     // 커스텀 신호
}
```

**InteractionResponse 정의:**
```dart
enum ResponseAction {
  playMotion,       // 모션 재생
  setExpression,    // 표정 설정
  playSound,        // 소리 재생 (미래)
  showBubble,       // 말풍선 표시 (미래)
  vibrate,          // 진동 피드백
  none,             // 반응 없음
}

class InteractionResponse {
  final ResponseAction action;
  final String? motionGroup;
  final int? motionIndex;
  final String? expressionId;
  final Duration? duration;
}
```

#### 4.2.2 상호작용 매니저 (Data Layer)

```
lib/features/live2d/data/services/
├── interaction_manager.dart        # 상호작용 관리자
├── interaction_config_service.dart # 설정 저장/로드
└── signal_dispatcher.dart          # 신호 디스패처
```

**핵심 기능:**
1. **이벤트 수신**: Native에서 전달되는 터치/제스처 이벤트 수신
2. **매핑 처리**: 이벤트 타입 → 반응 액션 매핑 (설정 기반)
3. **반응 실행**: 매핑된 반응을 Native에 전달
4. **외부 연동**: 다른 앱 기능에서 Live2D 제어 가능한 API 제공

#### 4.2.3 상호작용 설정 모델

```dart
// 제스처-반응 매핑 설정
class InteractionMapping {
  final InteractionType trigger;      // 트리거 이벤트
  final InteractionResponse response; // 반응 액션
  final bool enabled;                 // 활성화 여부
  final String? condition;            // 조건 (예: 특정 모델만)
}

// 전체 상호작용 설정
class InteractionConfig {
  final List<InteractionMapping> mappings;
  final bool enableTouchFeedback;     // 터치 피드백
  final bool enableAutoReaction;      // 자동 반응
  final Duration reactionCooldown;    // 반응 쿨다운
}
```

#### 4.2.4 Native 측 제스처 감지 확장

```
android/.../live2d/gesture/
├── GestureDetectorManager.kt   # 제스처 감지 관리자
├── SwipeDetector.kt            # 스와이프 감지
├── HeadPatDetector.kt          # 머리 쓰다듬기 감지
└── GestureConfig.kt            # 제스처 설정
```

**감지할 제스처:**
| 제스처 | 감지 조건 | 임계값 |
|--------|----------|--------|
| Swipe Up | 수직 이동 > 100dp, 각도 70-110° | 속도 > 500dp/s |
| Swipe Down | 수직 이동 > 100dp, 각도 250-290° | 속도 > 500dp/s |
| Swipe Left | 수평 이동 > 100dp, 각도 160-200° | 속도 > 500dp/s |
| Swipe Right | 수평 이동 > 100dp, 각도 -20-20° | 속도 > 500dp/s |
| Head Pat | 좌우 방향 전환 >= 3회 | 이동 거리 > 50dp |
| Poke | 탭 간격 < 100ms, 이동 < 10dp | 3회 이상 |

#### 4.2.5 Flutter 연동 인터페이스

```dart
// 다른 기능에서 Live2D 제어를 위한 인터페이스
abstract class Live2DInteractionInterface {
  // === 외부에서 Live2D 제어 ===
  Future<void> triggerEmotion(String emotion);
  Future<void> triggerMotion(String group, int index);
  Future<void> triggerExpression(String expressionId);
  Future<void> sendSignal(String signalName, {Map<String, dynamic>? data});
  
  // === Live2D 이벤트 구독 ===
  Stream<InteractionEvent> get interactionStream;
  void addInteractionListener(InteractionListener listener);
  void removeInteractionListener(InteractionListener listener);
}
```

### 4.3 파일 구조

```
lib/features/live2d/
├── domain/
│   ├── entities/
│   │   ├── interaction_event.dart
│   │   ├── interaction_type.dart
│   │   └── interaction_response.dart
│   └── repositories/
│       └── i_interaction_repository.dart
│
├── data/
│   ├── models/
│   │   ├── interaction_mapping.dart
│   │   └── interaction_config.dart
│   ├── services/
│   │   ├── interaction_manager.dart
│   │   ├── interaction_config_service.dart
│   │   └── signal_dispatcher.dart
│   └── repositories/
│       └── interaction_repository_impl.dart
│
└── presentation/
    └── controllers/
        └── interaction_controller.dart

android/.../live2d/
├── gesture/
│   ├── GestureDetectorManager.kt
│   ├── SwipeDetector.kt
│   ├── HeadPatDetector.kt
│   └── GestureConfig.kt
└── events/
    └── InteractionEventTypes.kt
```

### 4.4 구현 순서

| 순서 | 작업 | 예상 시간 |
|------|------|----------|
| 4.1 | Domain 엔티티 정의 | 1시간 |
| 4.2 | Native 제스처 감지 확장 | 2시간 |
| 4.3 | InteractionManager 구현 | 2시간 |
| 4.4 | 설정 모델 및 저장 서비스 | 1시간 |
| 4.5 | Native Bridge 확장 | 1시간 |
| 4.6 | 테스트 및 디버깅 | 1시간 |

---

## 📦 Phase 5: Live2DViewerEX 수준 기능 (상세)

### 5.1 목표
- 사용자 친화적인 모델 탐색/선택 UI
- 모션/표정 미리보기 및 설정
- 상세 커스터마이징 옵션

### 5.2 구현 항목

#### 5.2.1 모델 브라우저 화면

**기능:**
- 폴더 탐색 (트리/그리드 뷰 전환)
- 모델 썸네일 미리보기 (있는 경우)
- 모델 정보 표시:
  - 이름, 경로
  - Cubism 버전
  - 모션 그룹 수
  - 표정 수
  - 파일 크기
- 즐겨찾기 기능
- 최근 사용 모델 목록
- 검색/필터

```dart
// 화면 구성
class ModelBrowserScreen extends StatefulWidget {
  // 탭 구조:
  // [전체] [즐겨찾기] [최근 사용]
  
  // 뷰 모드:
  // - 그리드 뷰 (썸네일)
  // - 리스트 뷰 (상세)
  
  // 정렬:
  // - 이름순
  // - 최근 수정순
  // - 크기순
}
```

#### 5.2.2 모션/표정 관리 화면

**기능:**
- 모델의 모션 그룹 목록
- 각 모션 미리보기 (재생 버튼)
- 모션 설정:
  - 기본 Idle 모션 지정
  - 우선순위 설정
  - 반복 여부
- 표정 목록 및 미리보기
- 표정 블렌딩 테스트

```dart
class MotionExpressionScreen extends StatefulWidget {
  // 탭 구조:
  // [모션] [표정]
  
  // 모션 탭:
  // - 그룹별 접기/펼치기
  // - 재생 버튼
  // - 기본 모션 설정
  
  // 표정 탭:
  // - 표정 목록
  // - 미리보기
  // - 블렌딩 슬라이더
}
```

#### 5.2.3 제스처 설정 화면

**기능:**
- 제스처별 반응 설정
- 커스텀 제스처 매핑
- 반응 테스트

```dart
class GestureSettingsScreen extends StatefulWidget {
  // 제스처 목록:
  // - 탭 → [모션 선택 드롭다운]
  // - 더블탭 → [액션 선택]
  // - 롱프레스 → [액션 선택]
  // - 스와이프 상/하/좌/우 → [각각 설정]
  // - 머리 쓰다듬기 → [특별 반응 설정]
  
  // 테스트 버튼
}
```

#### 5.2.4 디스플레이 설정 확장

**추가 설정:**
- 크기 프리셋 (소/중/대/커스텀)
- 위치 프리셋 (좌상/우상/좌하/우하/중앙/커스텀)
- 회전 설정
- 미러링 (좌우반전)
- 배경 설정 (투명/색상/이미지)

#### 5.2.5 자동 동작 설정 확장

**추가 설정:**
- 눈 깜빡임:
  - 활성화/비활성화
  - 주기 설정 (초)
  - 랜덤 변동 범위
- 호흡:
  - 활성화/비활성화
  - 강도 설정
- 랜덤 모션:
  - 활성화/비활성화
  - 주기 설정
  - 허용 모션 그룹 선택
- 시선 추적:
  - 활성화/비활성화
  - 추적 속도
  - 추적 범위

### 5.3 파일 구조

```
lib/features/live2d/presentation/
├── screens/
│   ├── model_browser_screen.dart       # 모델 브라우저
│   ├── motion_expression_screen.dart   # 모션/표정 관리
│   ├── gesture_settings_screen.dart    # 제스처 설정
│   ├── display_settings_screen.dart    # 디스플레이 설정
│   └── auto_behavior_screen.dart       # 자동 동작 설정
│
├── widgets/
│   ├── model_browser/
│   │   ├── model_grid_item.dart
│   │   ├── model_list_item.dart
│   │   ├── model_info_card.dart
│   │   └── folder_tree_view.dart
│   ├── motion/
│   │   ├── motion_group_card.dart
│   │   ├── motion_item_tile.dart
│   │   └── expression_item_tile.dart
│   └── settings/
│       ├── gesture_mapping_tile.dart
│       ├── position_preset_selector.dart
│       └── size_preset_selector.dart
│
└── controllers/
    ├── model_browser_controller.dart
    ├── motion_controller.dart
    └── settings_controller.dart
```

### 5.4 구현 순서

| 순서 | 작업 | 예상 시간 |
|------|------|----------|
| 5.1 | 모델 브라우저 화면 | 3시간 |
| 5.2 | 모션/표정 관리 화면 | 2시간 |
| 5.3 | 제스처 설정 화면 | 2시간 |
| 5.4 | 디스플레이 설정 확장 | 1시간 |
| 5.5 | 자동 동작 설정 확장 | 1시간 |
| 5.6 | UI 폴리싱 | 2시간 |

---

## 📦 Phase 6: 최적화 & 안정화 (상세)

### 6.1 목표
- 성능 최적화 (FPS, 메모리, 배터리)
- 안정성 향상 (에러 처리, 복구)
- 사용자 경험 개선

### 6.2 구현 항목

#### 6.2.1 렌더링 최적화

**Native 측:**
```kotlin
class RenderOptimization {
    // FPS 제한
    var targetFps: Int = 30  // 30fps / 60fps 선택
    
    // 백그라운드 처리
    var renderInBackground: Boolean = false
    
    // 텍스처 품질
    enum class TextureQuality { LOW, MEDIUM, HIGH }
    var textureQuality: TextureQuality = MEDIUM
    
    // 물리 연산 최적화
    var physicsEnabled: Boolean = true
    var physicsSimplified: Boolean = false  // 저사양 모드
}
```

**최적화 방법:**
1. **프레임 스키핑**: 부하가 높을 때 프레임 스킵
2. **LOD (Level of Detail)**: 화면 크기에 따른 디테일 조절
3. **텍스처 압축**: 저사양 기기용 텍스처 압축
4. **캐싱**: 모델 데이터 메모리 캐싱

#### 6.2.2 메모리 최적화

**전략:**
1. **Lazy Loading**: 필요할 때만 리소스 로드
2. **Texture Atlas**: 텍스처 병합
3. **모델 언로드**: 미사용 모델 자동 해제
4. **메모리 모니터링**: OOM 방지

```kotlin
class MemoryManager {
    private val maxMemoryMB: Int = 100  // 최대 메모리 사용량
    
    fun onLowMemory() {
        // 1. 캐시 정리
        clearTextureCache()
        
        // 2. 품질 저하
        reduceTextureQuality()
        
        // 3. 가비지 컬렉션 힌트
        System.gc()
    }
}
```

#### 6.2.3 배터리 최적화

**배터리 절약 모드:**
```dart
class BatterySaveConfig {
  bool enabled;                    // 배터리 절약 모드
  int reducedFps;                  // 감소된 FPS (15 or 30)
  bool disablePhysics;             // 물리 비활성화
  bool disableBreathing;           // 호흡 비활성화
  bool pauseWhenScreenOff;         // 화면 꺼짐 시 일시정지
  int autoStopMinutes;             // 자동 정지 시간 (분)
}
```

**구현:**
1. **배터리 상태 모니터링**: BatteryManager 사용
2. **자동 모드 전환**: 저전력 시 자동 절약 모드
3. **Doze 모드 대응**: Android Doze 모드 고려

#### 6.2.4 에러 처리 & 복구

**에러 유형:**
| 유형 | 처리 방법 |
|------|----------|
| 모델 로드 실패 | 재시도 → 기본 모델 로드 → 오류 표시 |
| 렌더링 크래시 | 서비스 재시작 → 마지막 상태 복원 |
| 메모리 부족 | 품질 저하 → 캐시 정리 → 알림 |
| 권한 상실 | 권한 재요청 안내 |

**복구 메커니즘:**
```kotlin
class CrashRecovery {
    // 상태 저장 (SharedPreferences)
    fun saveState(state: OverlayState) {
        // 현재 모델, 위치, 크기, 설정 저장
    }
    
    // 상태 복원
    fun restoreState(): OverlayState? {
        // 저장된 상태 복원
    }
    
    // 서비스 재시작
    fun restartService() {
        // 기존 서비스 정리 후 재시작
    }
}
```

#### 6.2.5 로깅 & 모니터링

**로그 수준:**
```dart
enum LogLevel {
  verbose,   // 모든 상세 로그
  debug,     // 개발용 디버그
  info,      // 일반 정보
  warning,   // 경고
  error,     // 오류
}
```

**모니터링 항목:**
- FPS 그래프
- 메모리 사용량
- CPU 사용량
- 배터리 소모율
- 에러 발생 횟수

#### 6.2.6 사용자 피드백 개선

**개선 항목:**
1. **로딩 인디케이터**: 모델 로드 중 표시
2. **에러 메시지**: 사용자 친화적 에러 안내
3. **툴팁**: 설정 항목 설명
4. **온보딩**: 첫 사용 가이드

### 6.3 파일 구조

```
lib/features/live2d/
├── data/services/
│   ├── performance_monitor_service.dart
│   ├── battery_manager_service.dart
│   └── crash_recovery_service.dart
│
└── presentation/
    └── widgets/
        ├── performance_overlay.dart      # 성능 오버레이 (개발용)
        └── loading_indicator.dart

android/.../live2d/
├── optimization/
│   ├── RenderOptimization.kt
│   ├── MemoryManager.kt
│   └── BatteryOptimization.kt
│
└── recovery/
    ├── CrashRecovery.kt
    └── StateManager.kt
```

### 6.4 구현 순서

| 순서 | 작업 | 예상 시간 |
|------|------|----------|
| 6.1 | FPS 제한 및 렌더링 최적화 | 2시간 |
| 6.2 | 메모리 관리 | 2시간 |
| 6.3 | 배터리 절약 모드 | 1시간 |
| 6.4 | 에러 처리 및 복구 | 2시간 |
| 6.5 | 로깅 시스템 완성 | 1시간 |
| 6.6 | 최종 테스트 및 버그 수정 | 3시간 |

---

## 🗓️ 전체 타임라인 요약

| Phase | 예상 시간 | 주요 산출물 |
|-------|----------|-------------|
| **Phase 4** | 8시간 | 상호작용 시스템, 앱 연동 API |
| **Phase 5** | 11시간 | ViewerEX 수준 UI/UX |
| **Phase 6** | 11시간 | 최적화, 안정화 완료 |

**총 예상 시간: 30시간**

---

## ✅ Phase 4 시작 체크리스트

- [x] Phase 3 완료 확인 (로깅 시스템)
- [x] Domain 엔티티 파일 생성
- [x] Native 제스처 감지 확장
- [x] InteractionManager 구현
- [x] Native Bridge 확장
- [x] 설정 모델 구현
- [x] 테스트

---

## 📝 Phase 4 완료 내역

### 구현된 파일 목록

**Flutter 측:**
1. `lib/features/live2d/domain/entities/interaction_response.dart` - 응답 액션 정의
2. `lib/features/live2d/data/models/interaction_mapping.dart` - 제스처-반응 매핑
3. `lib/features/live2d/data/models/interaction_config.dart` - 상호작용 설정
4. `lib/features/live2d/data/services/interaction_manager.dart` - 상호작용 관리자
5. `lib/features/live2d/data/services/interaction_config_service.dart` - 설정 저장 서비스
6. `lib/features/live2d/presentation/screens/live2d_settings_screen.dart` - 테스트 UI 추가

**Native(Android) 측:**
1. `android/.../live2d/gesture/GestureTypes.kt` - 제스처 유형 및 설정
2. `android/.../live2d/gesture/GestureDetectorManager.kt` - 제스처 감지 관리자
3. `android/.../live2d/overlay/Live2DOverlayService.kt` - 제스처 감지 통합
4. `android/.../live2d/Live2DEventStreamHandler.kt` - 제스처 결과 전송 메서드 추가

### 주요 기능
- **제스처 감지**: 탭, 더블탭, 롱프레스, 스와이프(4방향), 머리쓰다듬기, 연타
- **상호작용 매핑**: 제스처별 응답 액션 설정 (모션, 표정, 신호 등)
- **외부 연동 API**: `triggerEmotion()`, `triggerMotion()`, `sendSignal()` 등
- **이벤트 스트림**: 상호작용 이벤트 구독 가능
- **테스트 UI**: 설정 화면에서 이벤트 수신 및 외부 트리거 테스트 가능

### 빌드 결과
✅ **BUILD SUCCESSFUL** (flutter build apk --debug)

---

## 🧹 Phase 4.5: WebView 방식 잔재 제거 계획

### 배경
Native OpenGL 기반으로 전환됨에 따라, 기존 WebView 기반 Live2D 렌더링 관련 코드를 제거합니다.

### 제거 대상 파일 목록

#### 1. Flutter 파일 (삭제)
| 파일 경로 | 설명 |
|----------|------|
| `lib/widgets/live2d_overlay_widget.dart` | WebView 오버레이 위젯 |
| `lib/widgets/simple_overlay_test.dart` | WebView 테스트 위젯 |
| `lib/services/local_server_service.dart` | 구 로컬 서버 서비스 |
| `lib/services/live2d_loader_service.dart` | 구 로더 서비스 (확인 필요) |
| `lib/features/live2d/data/services/live2d_local_server_service.dart` | 구 서버 서비스 |
| `lib/features/live2d/presentation/widgets/live2d_overlay_widget.dart` | features 내 WebView 위젯 |

#### 2. Asset 파일 (삭제)
| 파일 경로 | 설명 |
|----------|------|
| `assets/web/index.html` | WebView용 HTML |
| `assets/live2d/viewer.html` | Live2D 뷰어 HTML |

#### 3. pubspec.yaml 의존성 제거
```yaml
# 제거할 패키지
webview_flutter: ^4.10.0
webview_flutter_android: ^4.0.0
flutter_overlay_window: ^0.4.5
shelf: ^1.4.2
shelf_static: ^1.1.3
mime: ^2.0.0
```

#### 4. main.dart 수정
- `overlayMain()` 함수 제거 (WebView 오버레이용)
- 관련 import 제거

#### 5. Android 관련 정리 (선택)
| 파일 경로 | 설명 | 조치 |
|----------|------|------|
| `Live2DLocalServer.kt` | WebView용 로컬 서버 | 삭제 |
| `ExternalStoragePathHandler.kt` | WebView 리소스 핸들러 | 삭제 |

### 제거 순서
1. Flutter 위젯/서비스 파일 삭제
2. Asset 파일 삭제
3. pubspec.yaml에서 의존성 제거
4. main.dart 수정
5. `flutter pub get` 실행
6. Android 관련 파일 삭제 (선택)
7. 빌드 테스트

### 주의사항
- 제거 전 백업 권장
- 다른 기능에서 해당 패키지 사용 여부 확인
- flutter_overlay_window는 백업용으로 유지 가능

---

## 📦 Phase 5: UI/UX 개선 (구체화)

### 5.1 현재 설정 화면 문제점
1. 모든 설정이 한 화면에 집중되어 복잡함
2. 모션/표정 설정 UI 부재
3. 제스처 커스터마이징 UI 부재
4. 프리셋 시스템 부재

### 5.2 UI 구조 재설계

```
Live2D 설정 메인 화면 (현재)
├── 권한 섹션 (유지)
├── 데이터 폴더 섹션 (유지)
├── 모델 목록 섹션 (개선)
│   └── 탭 → 모델 상세 화면 (신규)
├── 표시 설정 섹션 (확장)
│   └── 더보기 → 디스플레이 설정 화면 (신규)
├── 플로팅 뷰어 토글 (유지)
├── 상호작용 설정 (신규)
│   └── 탭 → 제스처 설정 화면 (신규)
├── 자동 동작 설정 (신규)
│   └── 탭 → 자동 동작 설정 화면 (신규)
└── 디버그/테스트 섹션 (유지)
```

### 5.3 구현할 새 화면들

#### 5.3.1 모델 상세 화면 (ModelDetailScreen)
- 모델 정보 카드 (이름, 경로, 버전, 파일 크기)
- 모션 그룹 목록 (접기/펼치기)
  - 각 모션 재생 버튼
  - 기본 Idle 모션 설정
- 표정 목록
  - 각 표정 미리보기 버튼
- 즐겨찾기 토글
- 모델 삭제/이동 옵션

#### 5.3.2 제스처 설정 화면 (GestureSettingsScreen)
- 제스처별 반응 설정 카드
  - 탭: 액션 선택 드롭다운
  - 더블탭: 액션 선택
  - 롱프레스: 액션 선택
  - 스와이프 상/하/좌/우: 각각 설정
  - 머리 쓰다듬기: 특별 반응
- 쿨다운 설정 슬라이더
- 프리셋 저장/불러오기

#### 5.3.3 자동 동작 설정 화면 (AutoBehaviorScreen)
- 눈 깜빡임 섹션
  - 활성화 토글
  - 주기 슬라이더 (1-5초)
- 호흡 섹션
  - 활성화 토글
  - 강도 슬라이더
- 랜덤 모션 섹션
  - 활성화 토글
  - 주기 슬라이더 (10-60초)
  - 허용 모션 그룹 체크박스
- 시선 추적 섹션
  - 활성화 토글
  - 추적 속도 슬라이더

#### 5.3.4 디스플레이 설정 화면 (DisplaySettingsScreen)
- 크기 프리셋 (작게/중간/크게/커스텀)
- 위치 프리셋 (9방향 그리드 선택기)
- 투명도 슬라이더
- 회전 슬라이더 (선택)
- 미러링 토글 (선택)

### 5.4 구현 우선순위

| 순서 | 작업 | 중요도 | 예상 시간 |
|------|------|--------|----------|
| 1 | WebView 잔재 제거 (Phase 4.5) | 🔴 높음 | 1시간 |
| 2 | 제스처 설정 화면 | 🔴 높음 | 2시간 |
| 3 | 자동 동작 설정 화면 | 🟡 중간 | 1.5시간 |
| 4 | 모델 상세 화면 | 🟡 중간 | 2시간 |
| 5 | 디스플레이 설정 화면 | 🟢 낮음 | 1시간 |
| 6 | 기존 설정 화면 정리 | 🟡 중간 | 1시간 |

---

## 📦 Phase 6: 최적화 & 안정화 (구체화)

### 6.1 현재 이슈
1. 플레이스홀더 렌더러만 있음 (실제 Live2D SDK 미통합)
2. FPS 제한 없음
3. 백그라운드 처리 미구현
4. 에러 복구 미구현

### 6.2 구체적 구현 항목

#### 6.2.1 렌더링 최적화 (Native)
```kotlin
// Live2DGLRenderer.kt 확장
class RenderConfig {
    var targetFps: Int = 30           // 30 or 60
    var renderInBackground: Boolean = false
    var lowPowerMode: Boolean = false
}

// FPS 제한 구현
private var lastRenderTime = 0L
private val frameInterval = 1000L / targetFps

override fun onDrawFrame(gl: GL10?) {
    val currentTime = System.currentTimeMillis()
    if (currentTime - lastRenderTime < frameInterval) {
        return  // 프레임 스킵
    }
    lastRenderTime = currentTime
    // ... 렌더링
}
```

#### 6.2.2 백그라운드 처리 (Native)
```kotlin
// Live2DOverlayService.kt 확장
private var isInBackground = false

fun onAppBackground() {
    isInBackground = true
    if (!config.renderInBackground) {
        glSurfaceView?.onPause()
    }
}

fun onAppForeground() {
    isInBackground = false
    glSurfaceView?.onResume()
}
```

#### 6.2.3 상태 저장/복구 (Flutter + Native)
```dart
// 저장할 상태
class Live2DState {
  final String? modelPath;
  final double scale;
  final double opacity;
  final int positionX;
  final int positionY;
  final bool isVisible;
  final Map<String, dynamic> settings;
}
```

#### 6.2.4 에러 처리 개선
| 에러 유형 | 현재 처리 | 개선 방향 |
|----------|----------|----------|
| 모델 로드 실패 | 로그만 출력 | 사용자 알림 + 재시도 옵션 |
| 렌더링 크래시 | 앱 크래시 | 자동 복구 + 상태 복원 |
| 메모리 부족 | 없음 | 품질 저하 + 경고 |
| 권한 상실 | 없음 | 권한 재요청 안내 |

### 6.3 성능 목표
| 항목 | 목표값 |
|------|--------|
| FPS | 30fps (안정) |
| 메모리 | < 100MB |
| 배터리 (1시간) | < 5% |
| 시작 시간 | < 2초 |

### 6.4 구현 우선순위

| 순서 | 작업 | 중요도 | 예상 시간 |
|------|------|--------|----------|
| 1 | FPS 제한 구현 | 🔴 높음 | 1시간 |
| 2 | 백그라운드 처리 | 🔴 높음 | 1시간 |
| 3 | 상태 저장/복구 | 🟡 중간 | 2시간 |
| 4 | 에러 처리 개선 | 🟡 중간 | 2시간 |
| 5 | 성능 모니터링 | 🟢 낮음 | 1시간 |
| 6 | 배터리 최적화 | 🟢 낮음 | 1시간 |

---

## ✅ Phase 5 체크리스트

- [ ] Phase 4.5: WebView 잔재 제거
  - [ ] Flutter 파일 삭제
  - [ ] Asset 파일 삭제
  - [ ] pubspec.yaml 정리
  - [ ] main.dart 수정
  - [ ] 빌드 테스트
- [ ] 제스처 설정 화면 구현
- [ ] 자동 동작 설정 화면 구현
- [ ] 모델 상세 화면 구현
- [ ] 디스플레이 설정 화면 구현
- [ ] 기존 설정 화면 정리
