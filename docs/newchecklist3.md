# newchecklist3.md — 화면 공유 기능 확장 (ADB/Shizuku 스크린샷)

> **Purpose:** Screen Share Settings에 자체 캡처 / ADB(Shizuku) 선택 기능 추가, Shizuku 연동 ADB 스크린샷 구현, 팝업 메뉴(Mini Menu) 연동, 스크린샷 테스트 UI 추가.
>
> **Date:** 2026-03-02

---

## Table of Contents

1. [Baseline: 현재 아키텍처 분석](#baseline-현재-아키텍처-분석)
2. [§1 Screen Share Settings — 캡처 방식 선택 UI](#1-screen-share-settings--캡처-방식-선택-ui)
3. [§2 Shizuku/ADB 스크린샷 서비스 구현](#2-shizukuadb-스크린샷-서비스-구현)
4. [§3 알림 · 팝업 메뉴 — ADB 스크린샷 연동](#3-알림--팝업-메뉴--adb-스크린샷-연동)
5. [§4 스크린샷 테스트 & 보기 UI](#4-스크린샷-테스트--보기-ui)
6. [Implementation Order](#implementation-order)
7. [Key Files Reference](#key-files-reference)

---

## Baseline: 현재 아키텍처 분석

### B1. 기존 화면 캡처 파이프라인 (MediaProjection 방식)

```
Flutter ScreenCaptureService  →  MethodChannel 'com.pocketwaifu/screen_capture'
  → ScreenCapturePlugin.kt  →  MediaProjectionManager.getMediaProjection()
  → ImageReader + VirtualDisplay  →  Bitmap → base64 PNG → Flutter
```

| 컴포넌트 | 파일 | 역할 |
|---------|------|------|
| **ScreenCaptureService** | `lib/services/screen_capture_service.dart` | Flutter-side 캡처 인터페이스. `requestPermission()`, `capture()`, `release()` |
| **ScreenCapturePlugin** | `android/.../ScreenCapturePlugin.kt` | Android native. `MediaProjection` 기반 캡처. Permission → VirtualDisplay → ImageReader → base64 |
| **ScreenCaptureProvider** | `lib/providers/screen_capture_provider.dart` | 상태 관리 (permission status, isCapturing, lastCapture) |
| **ScreenShareSettings** | `lib/models/screen_share_settings.dart` | 설정 모델: `enabled`, `captureInterval`, `autoCapture`, `imageQuality`, `maxResolution` |
| **ScreenShareProvider** | `lib/providers/screen_share_provider.dart` | 설정 영속화, permission 관리 |
| **ScreenShareSettingsScreen** | `lib/screens/screen_share_settings_screen.dart` | 설정 화면 UI — Permission Status, Capture Settings, Privacy Notice 카드 |

### B2. 미니 메뉴 스크린샷 흐름

```
Android MiniMenu 오버레이  →  'miniMenuCaptureAndSendScreenshot' MethodCall
  → MiniMenuService._handleMethodCall()  →  _captureAndSend callback
  → main.dart: ScreenCaptureService.capture()  →  coordinator.handleMiniMenuReplyWithImages()
```

- `MiniMenuService` (`lib/services/mini_menu_service.dart`): `MiniMenuCaptureAndSend` 콜백으로 스크린샷 촬영 후 AI에게 전송.
- `main.dart` (line 230–291): `captureAndSend` 구현 — `ScreenCaptureService().capture()` 사용. **현재 MediaProjection만 사용.**

### B3. 핵심 과제

1. **캡처 방식이 MediaProjection 단일 경로** — ADB(Shizuku) 대안 경로가 없음.
2. **ScreenShareSettings에 캡처 방식 선택 필드 없음** — `captureMethod` 같은 enum 부재.
3. **Shizuku 라이브러리 미통합** — `pubspec.yaml`에 Shizuku 관련 의존성 없음, Android 코드에도 없음.
4. **테스트/미리보기 UI 없음** — Settings 화면에 캡처 테스트 및 결과 확인 기능 부재.

---

## §1 Screen Share Settings — 캡처 방식 선택 UI

> **Goal:** Screen Share Settings 상단에 캡처 방식(자체 MediaProjection / ADB via Shizuku)을 선택하는 UI를 추가한다. 선택에 따라 하위 Permission 섹션과 캡처 동작이 분기된다.

### 1.1 ScreenShareSettings 모델 확장

- [x] **1.1.1** `lib/models/screen_share_settings.dart`에 `CaptureMethod` enum 추가:
  ```dart
  enum CaptureMethod { mediaProjection, adb }
  ```

- [x] **1.1.2** `ScreenShareSettings` 클래스에 `captureMethod` 필드 추가:
  ```dart
  final CaptureMethod captureMethod;
  
  const ScreenShareSettings({
    // ... 기존 필드 ...
    this.captureMethod = CaptureMethod.mediaProjection,
  });
  ```

- [x] **1.1.3** `copyWith()`, `toMap()`, `fromMap()`에 `captureMethod` 직렬화 반영:
  ```dart
  // toMap
  'captureMethod': captureMethod.name,
  // fromMap
  captureMethod: CaptureMethod.values.firstWhere(
    (e) => e.name == map['captureMethod'],
    orElse: () => CaptureMethod.mediaProjection,
  ),
  ```

### 1.2 ScreenShareProvider 확장

- [x] **1.2.1** `lib/providers/screen_share_provider.dart`에 `setCaptureMethod(CaptureMethod method)` 메서드 추가:
  ```dart
  Future<void> setCaptureMethod(CaptureMethod method) async {
    _settings = _settings.copyWith(captureMethod: method);
    await _persist();
    notifyListeners();
  }
  ```

- [x] **1.2.2** `load()` 메서드에서 ADB 방식 선택 시 Shizuku 연결 상태도 함께 확인하도록 로직 추가:
  ```dart
  if (_settings.captureMethod == CaptureMethod.adb) {
    final shizukuConnected = await _adbCaptureService.isShizukuAvailable();
    _settings = _settings.copyWith(isAdbConnected: shizukuConnected);
  }
  ```

### 1.3 ScreenShareSettingsScreen UI 변경

- [x] **1.3.1** 기존 `Permission Status` 카드 **위에** 새 `_SectionCard`로 **캡처 방식 선택** 섹션 추가:
  ```dart
  _SectionCard(
    title: 'Capture Method',
    child: Column(
      children: [
        RadioListTile<CaptureMethod>(
          title: const Text('자체 화면 공유 (MediaProjection)'),
          subtitle: const Text('Android 기본 화면 캡처 API 사용'),
          value: CaptureMethod.mediaProjection,
          groupValue: settings.captureMethod,
          onChanged: (v) => provider.setCaptureMethod(v!),
        ),
        RadioListTile<CaptureMethod>(
          title: const Text('ADB (Shizuku)'),
          subtitle: const Text('Shizuku를 통한 ADB 스크린샷 (root 불필요)'),
          value: CaptureMethod.adb,
          groupValue: settings.captureMethod,
          onChanged: (v) => provider.setCaptureMethod(v!),
        ),
      ],
    ),
  ),
  ```

- [x] **1.3.2** **조건부 Permission 섹션 표시:**
  - `CaptureMethod.mediaProjection` 선택 시: 기존 `Permission Status` 카드 (MediaProjection 권한) 표시.
  - `CaptureMethod.adb` 선택 시: 새 `Shizuku Connection Status` 카드 표시 (§2.4에서 상세 정의).

- [x] **1.3.3** `Capture Settings` 카드 내 설정들은 두 방식 모두에서 공통 사용 — `imageQuality`, `maxResolution`, `captureInterval` 등은 유지.

---

## §2 Shizuku/ADB 스크린샷 서비스 구현

> **Goal:** Shizuku API를 통해 ADB 권한을 획득하고, `screencap` 명령으로 스크린샷을 촬영하는 서비스를 구현한다. MediaProjection과 동일한 인터페이스(`ImageAttachment`)를 반환하여 기존 파이프라인과 호환시킨다.

### 2.1 Android Gradle — Shizuku 의존성 추가

- [x] **2.1.1** `android/app/build.gradle`에 Shizuku 의존성 추가:
  ```groovy
  dependencies {
      // Shizuku API
      implementation 'dev.rikka.shizuku:api:13.1.5'
      implementation 'dev.rikka.shizuku:provider:13.1.5'
  }
  ```

- [x] **2.1.2** `android/app/src/main/AndroidManifest.xml`에 Shizuku provider 선언:
  ```xml
  <provider
      android:name="rikka.shizuku.ShizukuProvider"
      android:authorities="${applicationId}.shizuku"
      android:multiprocess="false"
      android:enabled="true"
      android:exported="true"
      android:permission="android.permission.INTERACT_ACROSS_USERS_FULL" />
  ```

### 2.2 Android Native — AdbScreenCapturePlugin

- [x] **2.2.1** `android/app/src/main/kotlin/.../AdbScreenCapturePlugin.kt` 신규 생성:
  ```kotlin
  class AdbScreenCapturePlugin(private val context: Context) {
      
      fun isShizukuInstalled(): Boolean
      fun isShizukuRunning(): Boolean
      fun hasShizukuPermission(): Boolean
      fun requestShizukuPermission(activity: Activity, requestCode: Int)
      
      fun captureScreen(): Map<String, Any>?  // base64Data, mimeType, width, height
  }
  ```

- [x] **2.2.2** `isShizukuInstalled()` 구현 — `Shizuku.pingBinder()` 또는 PackageManager로 `moe.shizuku.privileged.api` 패키지 존재 확인.

- [x] **2.2.3** `isShizukuRunning()` 구현 — `Shizuku.pingBinder()` 호출, `true` 반환 시 Shizuku 서비스 활성.

- [x] **2.2.4** `hasShizukuPermission()` 구현 — `Shizuku.checkSelfPermission() == PackageManager.PERMISSION_GRANTED`.

- [x] **2.2.5** `requestShizukuPermission()` 구현 — `Shizuku.requestPermission(requestCode)`.

- [x] **2.2.6** `captureScreen()` 핵심 구현 — Shizuku의 `ShizukuRemoteProcess`를 통해 `screencap -p` 실행:
  ```kotlin
  fun captureScreen(): Map<String, Any>? {
      if (!hasShizukuPermission()) return null
      
      val process = Shizuku.newProcess(arrayOf("screencap", "-p"), null, null)
      val inputStream = process.inputStream
      val bytes = inputStream.readBytes()
      process.waitFor()
      
      if (bytes.isEmpty()) return null
      
      // PNG 바이트를 Bitmap으로 디코딩하여 width/height 확인
      val bitmap = BitmapFactory.decodeByteArray(bytes, 0, bytes.size) ?: return null
      val base64 = Base64.encodeToString(bytes, Base64.NO_WRAP)
      
      val result = mapOf(
          "base64Data" to base64,
          "mimeType" to "image/png",
          "width" to bitmap.width,
          "height" to bitmap.height,
      )
      bitmap.recycle()
      return result
  }
  ```

- [x] **2.2.7** 선택적 해상도 축소 — `maxResolution` 설정을 반영하여 캡처 후 리사이즈:
  ```kotlin
  fun captureScreen(maxResolution: Int = 0): Map<String, Any>? {
      // ... screencap 실행 ...
      // maxResolution > 0이면 Bitmap 리사이즈 후 base64 인코딩
  }
  ```

### 2.3 MethodChannel 등록

- [x] **2.3.1** `MainActivity.kt`에 ADB 캡처용 별도 MethodChannel 등록:
  ```kotlin
  private val adbCaptureChannel = MethodChannel(
      flutterEngine.dartExecutor.binaryMessenger,
      "com.pocketwaifu/adb_screen_capture"
  )
  ```

- [x] **2.3.2** MethodChannel 핸들러 구현:
  ```kotlin
  adbCaptureChannel.setMethodCallHandler { call, result ->
      when (call.method) {
          "isShizukuInstalled" -> result.success(adbPlugin.isShizukuInstalled())
          "isShizukuRunning" -> result.success(adbPlugin.isShizukuRunning())
          "hasPermission" -> result.success(adbPlugin.hasShizukuPermission())
          "requestPermission" -> {
              adbPlugin.requestShizukuPermission(this, ADB_CAPTURE_REQUEST_CODE)
              // result는 onRequestPermissionsResult에서 반환
          }
          "captureScreen" -> {
              Thread {
                  val data = adbPlugin.captureScreen(
                      call.argument<Int>("maxResolution") ?: 0
                  )
                  runOnUiThread {
                      if (data != null) result.success(data)
                      else result.error("CAPTURE_FAILED", "ADB screencap failed", null)
                  }
              }.start()
          }
          "getConnectionStatus" -> {
              result.success(mapOf(
                  "installed" to adbPlugin.isShizukuInstalled(),
                  "running" to adbPlugin.isShizukuRunning(),
                  "permission" to adbPlugin.hasShizukuPermission(),
              ))
          }
          else -> result.notImplemented()
      }
  }
  ```

- [x] **2.3.3** `onRequestPermissionsResult`에서 Shizuku 권한 결과 처리 — pending result에 `success(granted)` 반환.

### 2.4 Flutter-Side — AdbScreenCaptureService

- [x] **2.4.1** `lib/services/adb_screen_capture_service.dart` 신규 생성:
  ```dart
  class AdbScreenCaptureService {
    static const MethodChannel _channel = MethodChannel(
      'com.pocketwaifu/adb_screen_capture',
    );
    
    Future<bool> isShizukuInstalled() async { ... }
    Future<bool> isShizukuRunning() async { ... }
    Future<bool> hasPermission() async { ... }
    Future<bool> requestPermission() async { ... }
    
    Future<Map<String, dynamic>?> captureScreen({int maxResolution = 0}) async { ... }
    
    Future<ImageAttachment?> capture({int maxResolution = 0}) async {
      final raw = await captureScreen(maxResolution: maxResolution);
      // ScreenCaptureService.capture()와 동일한 ImageAttachment 변환 로직
    }
    
    Future<Map<String, dynamic>> getConnectionStatus() async { ... }
  }
  ```

- [x] **2.4.2** `capture()` 메서드가 `ScreenCaptureService.capture()`와 동일한 `ImageAttachment` 형식을 반환하도록 구현 — `ImageCacheManager`를 통한 캐시 저장 포함.

### 2.5 통합 캡처 서비스 (Unified Interface)

- [x] **2.5.1** `lib/services/unified_capture_service.dart` 신규 생성 — 설정에 따라 적절한 캡처 서비스를 호출하는 facade:
  ```dart
  class UnifiedCaptureService {
    final ScreenCaptureService _mediaProjectionService = ScreenCaptureService();
    final AdbScreenCaptureService _adbService = AdbScreenCaptureService();
    
    Future<ImageAttachment?> capture(ScreenShareSettings settings) async {
      switch (settings.captureMethod) {
        case CaptureMethod.mediaProjection:
          return _mediaProjectionService.capture();
        case CaptureMethod.adb:
          return _adbService.capture(maxResolution: settings.maxResolution);
      }
    }
    
    Future<bool> hasPermission(CaptureMethod method) async { ... }
    Future<bool> requestPermission(CaptureMethod method) async { ... }
  }
  ```

- [x] **2.5.2** `ScreenCaptureProvider`를 `UnifiedCaptureService`를 사용하도록 리팩터링:
  ```dart
  class ScreenCaptureProvider extends ChangeNotifier {
    final UnifiedCaptureService _unifiedService = UnifiedCaptureService();
    CaptureMethod _currentMethod = CaptureMethod.mediaProjection;
    
    void updateCaptureMethod(CaptureMethod method) {
      _currentMethod = method;
    }
    
    Future<ImageAttachment?> capture() async {
      // _currentMethod에 따라 분기
    }
  }
  ```

### 2.6 Shizuku 연결 상태 UI (Settings 내)

- [x] **2.6.1** `CaptureMethod.adb` 선택 시 표시할 `Shizuku Connection Status` 카드 구현:
  ```dart
  _SectionCard(
    title: 'Shizuku Connection',
    child: FutureBuilder<Map<String, dynamic>>(
      future: adbService.getConnectionStatus(),
      builder: (context, snapshot) {
        final status = snapshot.data;
        return Column(children: [
          _StatusRow('Shizuku 설치됨', status?['installed'] == true),
          _StatusRow('Shizuku 실행 중', status?['running'] == true),
          _StatusRow('권한 허용됨', status?['permission'] == true),
          // 상태에 따른 액션 버튼
          if (status?['installed'] != true)
            _ActionButton('Shizuku 설치', onTap: _openShizukuPlayStore),
          if (status?['installed'] == true && status?['running'] != true)
            _ActionButton('Shizuku를 실행해 주세요', onTap: _openShizukuApp),
          if (status?['running'] == true && status?['permission'] != true)
            _ActionButton('권한 요청', onTap: provider.requestAdbPermission),
        ]);
      },
    ),
  ),
  ```

- [x] **2.6.2** `_StatusRow` 위젯 — 아이콘(✅/❌) + 레이블의 간단한 행.

- [x] **2.6.3** `_openShizukuPlayStore()` — `url_launcher`나 Intent로 Play Store Shizuku 페이지 열기:
  ```dart
  void _openShizukuPlayStore() {
    // Intent: market://details?id=moe.shizuku.privileged.api
    // 또는 MethodChannel로 Android에서 직접 열기
  }
  ```

- [x] **2.6.4** `_openShizukuApp()` — Shizuku 앱의 메인 화면을 Launch Intent로 열기.

---

## §3 알림 · 팝업 메뉴 — ADB 스크린샷 연동

> **Goal:** ADB 캡처 방식 선택 시 알림 응답, 팝업 메뉴(Mini Menu)의 "스크린샷 보내기" 기능이 ADB 캡처를 사용하도록 업데이트한다.

### 3.1 main.dart — captureAndSend 콜백 수정

- [x] **3.1.1** `main.dart`의 `captureAndSend` 콜백 (line 230–291)을 `UnifiedCaptureService`를 사용하도록 수정:
  ```dart
  captureAndSend: (sessionId, text) async {
    try {
      final screenShareProvider = context.read<ScreenShareProvider>();
      final settings = screenShareProvider.settings;
      final unifiedService = UnifiedCaptureService();
      
      // 1. 현재 설정된 캡처 방식으로 권한 확인
      final hasPermission = await unifiedService.hasPermission(settings.captureMethod);
      if (!hasPermission) {
        final granted = await unifiedService.requestPermission(settings.captureMethod);
        if (!granted) {
          return {
            'ok': false,
            'error': 'capture_permission_denied',
            'message': settings.captureMethod == CaptureMethod.adb
                ? 'Shizuku 권한이 없습니다. 설정에서 Shizuku 연결을 확인하세요.'
                : '화면 캡처 권한이 없습니다. 앱에서 Screen Share 설정을 확인하세요.',
          };
        }
      }
      
      // 2. 통합 서비스로 캡처
      final image = await unifiedService.capture(settings);
      if (image == null) {
        return {
          'ok': false,
          'error': 'capture_failed',
          'message': '화면 캡처에 실패했습니다.',
        };
      }
      
      // 3. AI에게 전송
      final result = await coordinator.handleMiniMenuReplyWithImages(
        message: text,
        images: [image],
        sessionId: sessionId,
      );
      return result;
    } catch (e, stack) {
      debugPrint('MiniMenu: captureAndSend exception=$e');
      return {
        'ok': false,
        'error': 'capture_exception',
        'message': '스크린샷 처리 중 오류: $e',
      };
    }
  },
  ```

### 3.2 MiniMenuService — 캡처 방식 인지

- [x] **3.2.1** `MiniMenuService._handleMethodCall`의 `miniMenuCaptureAndSendScreenshot` 케이스는 변경 불필요 — `_captureAndSend` 콜백이 내부적으로 `UnifiedCaptureService`를 사용하므로 방식 선택이 자동 분기됨.

- [x] **3.2.2** Android side MiniMenu 오버레이에도 캡처 방식에 따른 UI 피드백 문자열 수정 — ADB 사용 시 "ADB로 캡처 중..." 표시 (선택적 개선).

### 3.3 NotificationCoordinator 연동

- [x] **3.3.1** `NotificationCoordinator.handleMiniMenuReplyWithImages()` (line 155–169)는 `ImageAttachment` 리스트를 받으므로, 캡처 방식 무관하게 동일 동작 — **변경 불필요.**

- [x] **3.3.2** `handleNotificationReply()` 경로에서도 향후 이미지 첨부가 필요할 경우를 대비하여, `UnifiedCaptureService` 참조 경로 확보 (현재는 알림 텍스트 응답만 지원하므로 당장 변경 불필요).

### 3.4 ADB 캡처 시 오버레이 숨김 처리

- [x] **3.4.1** MediaProjection 캡처 시에는 오버레이(Live2D, MiniMenu)가 같이 캡처되는 문제가 있음. ADB `screencap`은 SurfaceFlinger 레벨 캡처이므로 오버레이도 캡처됨.
  - ADB 캡처 전에 오버레이를 일시 숨기는 로직 추가:
  ```dart
  if (settings.captureMethod == CaptureMethod.adb) {
    await _hideOverlays();         // Live2D, MiniMenu 일시 숨김
    await Future.delayed(Duration(milliseconds: 100));
    final image = await _adbService.capture();
    await _showOverlays();         // 복원
    return image;
  }
  ```

- [x] **3.4.2** `_hideOverlays()` / `_showOverlays()` 구현:
  - Live2D overlay: `Live2DOverlayService` ACTION으로 visibility 토글.
  - MiniMenu overlay: 캡처 직전 `closeMiniMenu()`, 캡처 직후 재오픈 (또는 Android side에서 View.INVISIBLE 처리).

---

## §4 스크린샷 테스트 & 보기 UI

> **Goal:** Screen Share Settings 화면 하단에 현재 설정된 캡처 방식으로 스크린샷을 테스트하고, 결과를 미리볼 수 있는 UI를 추가한다. 두 방식 모두 동일한 UI에서 테스트 가능.

### 4.1 테스트 섹션 UI 추가

- [x] **4.1.1** `screen_share_settings_screen.dart`의 `Privacy Notice` 카드 아래에 새 `_SectionCard` 추가:
  ```dart
  _SectionCard(
    title: 'Screenshot Test',
    child: _ScreenshotTestWidget(),
  ),
  ```

- [x] **4.1.2** `_ScreenshotTestWidget` StatefulWidget 구현:
  ```dart
  class _ScreenshotTestWidget extends StatefulWidget { ... }
  
  class _ScreenshotTestWidgetState extends State<_ScreenshotTestWidget> {
    ImageAttachment? _lastCapture;
    bool _isCapturing = false;
    String? _errorMessage;
    DateTime? _captureTime;
    int? _captureDurationMs;
    
    @override
    Widget build(BuildContext context) { ... }
  }
  ```

### 4.2 테스트 버튼

- [x] **4.2.1** "스크린샷 테스트" 버튼 구현 — 현재 선택된 캡처 방식으로 스크린샷 촬영:
  ```dart
  FilledButton.icon(
    icon: _isCapturing 
        ? SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
        : Icon(Icons.camera_alt),
    label: Text(_isCapturing ? '캡처 중...' : '스크린샷 테스트'),
    onPressed: _isCapturing ? null : _doTestCapture,
  ),
  ```

- [x] **4.2.2** `_doTestCapture()` 구현:
  ```dart
  Future<void> _doTestCapture() async {
    setState(() { _isCapturing = true; _errorMessage = null; });
    final stopwatch = Stopwatch()..start();
    try {
      final provider = context.read<ScreenShareProvider>();
      final settings = provider.settings;
      final unifiedService = UnifiedCaptureService();
      
      // 권한 확인
      final hasPerm = await unifiedService.hasPermission(settings.captureMethod);
      if (!hasPerm) {
        setState(() {
          _errorMessage = settings.captureMethod == CaptureMethod.adb
              ? 'Shizuku 권한이 필요합니다.'
              : 'MediaProjection 권한이 필요합니다.';
        });
        return;
      }
      
      final image = await unifiedService.capture(settings);
      stopwatch.stop();
      setState(() {
        _lastCapture = image;
        _captureTime = DateTime.now();
        _captureDurationMs = stopwatch.elapsedMilliseconds;
        if (image == null) _errorMessage = '캡처 후 이미지가 null입니다.';
      });
    } catch (e) {
      stopwatch.stop();
      setState(() {
        _errorMessage = '캡처 실패: $e';
        _captureDurationMs = stopwatch.elapsedMilliseconds;
      });
    } finally {
      setState(() { _isCapturing = false; });
    }
  }
  ```

### 4.3 캡처 결과 표시

- [x] **4.3.1** 캡처 메타정보 표시:
  ```dart
  if (_lastCapture != null || _errorMessage != null)
    Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: _errorMessage != null 
            ? Colors.red.withOpacity(0.1)
            : Colors.green.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (_errorMessage != null)
            Text('❌ $_errorMessage', style: TextStyle(color: Colors.red)),
          if (_lastCapture != null) ...[
            Text('✅ 캡처 성공'),
            Text('해상도: ${_lastCapture!.width} × ${_lastCapture!.height}'),
            Text('형식: ${_lastCapture!.mimeType}'),
            Text('데이터 크기: ${(_lastCapture!.base64Data.length * 3 / 4 / 1024).toStringAsFixed(1)} KB'),
          ],
          if (_captureDurationMs != null)
            Text('소요 시간: ${_captureDurationMs}ms'),
          if (_captureTime != null)
            Text('시각: ${_captureTime!.toIso8601String().substring(11, 19)}'),
        ],
      ),
    ),
  ```

### 4.4 이미지 미리보기

- [x] **4.4.1** 캡처 성공 시 썸네일 이미지 표시:
  ```dart
  if (_lastCapture != null && _lastCapture!.thumbnailPath != null)
    GestureDetector(
      onTap: _showFullScreenPreview,
      child: Container(
        margin: const EdgeInsets.only(top: 8),
        constraints: const BoxConstraints(maxHeight: 200),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: Image.file(
            File(_lastCapture!.thumbnailPath!),
            fit: BoxFit.contain,
          ),
        ),
      ),
    ),
  ```

- [x] **4.4.2** 썸네일 탭 시 전체 화면 미리보기 — `_showFullScreenPreview()`:
  ```dart
  void _showFullScreenPreview() {
    if (_lastCapture == null) return;
    showDialog(
      context: context,
      builder: (_) => Dialog.fullscreen(
        child: Stack(
          children: [
            InteractiveViewer(
              child: Center(
                child: Image.memory(
                  base64Decode(_lastCapture!.base64Data),
                  fit: BoxFit.contain,
                ),
              ),
            ),
            Positioned(
              top: 16, right: 16,
              child: IconButton(
                icon: const Icon(Icons.close, color: Colors.white),
                onPressed: () => Navigator.pop(context),
              ),
            ),
          ],
        ),
      ),
    );
  }
  ```

### 4.5 방식 비교 테스트

- [x] **4.5.1** "양쪽 방식 모두 테스트" 버튼 추가 (선택적) — MediaProjection과 ADB를 순차 실행하여 결과 비교:
  ```dart
  OutlinedButton.icon(
    icon: const Icon(Icons.compare),
    label: const Text('양쪽 비교 테스트'),
    onPressed: _doBothCaptureTest,
  ),
  ```

- [x] **4.5.2** `_doBothCaptureTest()` — 두 방식의 캡처 결과를 나란히 표시:
  - MediaProjection 결과: 좌측
  - ADB 결과: 우측
  - 각각의 소요 시간, 해상도, 데이터 크기 비교

---

## Implementation Order

| Phase | 작업 | 의존성 | 복잡도 |
|-------|------|--------|--------|
| **Phase 1** | §1 (설정 모델/UI에 captureMethod 추가) | 없음 | 🟢 Low |
| **Phase 2** | §2.1–2.3 (Android Shizuku 통합 + MethodChannel) | 없음 | 🔴 High — Shizuku API 통합 |
| **Phase 3** | §2.4–2.5 (Flutter ADB 서비스 + 통합 서비스) | Phase 2 | 🟡 Medium |
| **Phase 4** | §2.6 (Shizuku 연결 상태 UI) | Phase 3 | 🟢 Low |
| **Phase 5** | §3 (Mini Menu captureAndSend 수정, 오버레이 숨김) | Phase 3 | 🟡 Medium |
| **Phase 6** | §4 (스크린샷 테스트 & 보기 UI) | Phase 3 | 🟡 Medium |

### Recommended Critical Path

```
Phase 1 (설정 모델 확장) → Phase 2 (Shizuku Android 통합)
→ Phase 3 (Flutter ADB 서비스) → Phase 4 (연결 상태 UI)
→ Phase 5 (Mini Menu 연동) → Phase 6 (테스트 UI)
```

---

## Key Files Reference

| 파일 | 역할 | §§ |
|-----|------|-----|
| `lib/models/screen_share_settings.dart` | `ScreenShareSettings` 모델 — `CaptureMethod` enum 추가 | §1 |
| `lib/providers/screen_share_provider.dart` | 설정 관리/영속화 — `setCaptureMethod()` 추가 | §1 |
| `lib/screens/screen_share_settings_screen.dart` | 설정 화면 UI — 캡처 방식 선택, Shizuku 상태, 테스트 UI | §1, §2.6, §4 |
| `lib/services/screen_capture_service.dart` | 기존 MediaProjection 캡처 서비스 (변경 없음, 호환용) | §2.5 |
| `lib/services/adb_screen_capture_service.dart` | **신규** — Shizuku/ADB 캡처 Flutter 서비스 | §2.4 |
| `lib/services/unified_capture_service.dart` | **신규** — 설정에 따라 MediaProjection/ADB 분기하는 통합 facade | §2.5 |
| `lib/providers/screen_capture_provider.dart` | 캡처 상태 관리 — `UnifiedCaptureService` 사용으로 리팩터링 | §2.5 |
| `android/app/build.gradle` | Shizuku 의존성 추가 | §2.1 |
| `android/app/src/main/AndroidManifest.xml` | Shizuku provider 선언 | §2.1 |
| `android/.../AdbScreenCapturePlugin.kt` | **신규** — Android native ADB 캡처 플러그인 | §2.2 |
| `android/.../MainActivity.kt` | ADB MethodChannel 등록 | §2.3 |
| `android/.../ScreenCapturePlugin.kt` | 기존 MediaProjection 플러그인 (변경 없음) | — |
| `lib/services/mini_menu_service.dart` | MiniMenu MethodChannel 핸들러 (구조 변경 없음) | §3 |
| `lib/main.dart` | `captureAndSend` 콜백 — `UnifiedCaptureService` 사용으로 수정 | §3.1 |
| `lib/services/notification_coordinator.dart` | 알림 응답 처리 (ImageAttachment 호환, 변경 없음) | §3.3 |
