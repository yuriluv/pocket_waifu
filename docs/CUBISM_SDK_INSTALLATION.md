# Live2D Cubism SDK 설치 가이드

> **Phase 7 완료를 위한 필수 단계**

## 📥 1. SDK 다운로드

### 1.1 Live2D 공식 사이트 접속
1. https://www.live2d.com/download/cubism-sdk/ 접속
2. **Cubism SDK for Native** 선택
3. 라이센스 동의 후 다운로드

### 1.2 라이센스 확인
| 라이센스 | 용도 | 제한 |
|---------|------|------|
| **Free** | 개인/비상업적 | 연간 매출 1,000만엔 미만 |
| **PRO** | 상업적 | 유료 라이센스 필요 |

---

## 📁 2. SDK 파일 배치

### 2.1 네이티브 라이브러리 (.so 파일)

SDK 압축 해제 후 다음 파일들을 복사:

```
[SDK 폴더]/Core/lib/android/
├── arm64-v8a/libLive2DCubismCore.so
├── armeabi-v7a/libLive2DCubismCore.so
└── x86_64/libLive2DCubismCore.so
```

복사 위치:
```
android/app/src/main/jniLibs/
├── arm64-v8a/
│   └── libLive2DCubismCore.so    ← 여기에 복사
├── armeabi-v7a/
│   └── libLive2DCubismCore.so    ← 여기에 복사
└── x86_64/
    └── libLive2DCubismCore.so    ← 여기에 복사
```

### 2.2 파일 복사 명령어 (Windows PowerShell)

```powershell
# SDK 다운로드 경로 (예시)
$SDK_PATH = "C:\Users\YourName\Downloads\CubismSdkForNative-5-r.1"

# 프로젝트 경로
$PROJECT_PATH = "c:\Users\hp\Desktop\sihu\flai\flutter_application_1"

# 복사
Copy-Item "$SDK_PATH\Core\lib\android\arm64-v8a\libLive2DCubismCore.so" `
          "$PROJECT_PATH\android\app\src\main\jniLibs\arm64-v8a\"

Copy-Item "$SDK_PATH\Core\lib\android\armeabi-v7a\libLive2DCubismCore.so" `
          "$PROJECT_PATH\android\app\src\main\jniLibs\armeabi-v7a\"

Copy-Item "$SDK_PATH\Core\lib\android\x86_64\libLive2DCubismCore.so" `
          "$PROJECT_PATH\android\app\src\main\jniLibs\x86_64\"
```

### 2.3 파일 확인

```powershell
Get-ChildItem -Recurse "$PROJECT_PATH\android\app\src\main\jniLibs" -Filter "*.so"
```

예상 출력:
```
    Directory: ...\jniLibs\arm64-v8a
libLive2DCubismCore.so

    Directory: ...\jniLibs\armeabi-v7a
libLive2DCubismCore.so

    Directory: ...\jniLibs\x86_64
libLive2DCubismCore.so
```

---

## 🔧 3. 코드 활성화

SDK 설치 후 다음 파일들의 TODO 주석을 해제해야 합니다:

### 3.1 CubismFrameworkManager.kt

```kotlin
// 파일: live2d/cubism/CubismFrameworkManager.kt
// 위치: initialize() 메서드 내부

// 변경 전 (주석 상태):
// CubismFramework.startUp(...)
// CubismFramework.initialize()

// 변경 후 (활성화):
import com.live2d.sdk.cubism.framework.CubismFramework
import com.live2d.sdk.cubism.framework.ICubismAllocator

CubismFramework.startUp(object : ICubismAllocator {
    override fun allocate(size: Int) = allocator.allocate(size)
    override fun deallocate(buffer: ByteBuffer?) = allocator.deallocate(buffer)
    override fun allocateAligned(size: Int, alignment: Int) = allocator.allocateAligned(size, alignment)
    override fun deallocateAligned(buffer: ByteBuffer?) = allocator.deallocateAligned(buffer)
}, null)

CubismFramework.initialize()
```

### 3.2 CubismModel.kt

```kotlin
// 파일: live2d/cubism/CubismModel.kt

// 주요 변경 위치:
// 1. load() - moc3 로드
// 2. update() - 모션/물리 업데이트
// 3. draw() - 렌더링
// 4. playMotion() - 모션 재생
```

---

## ✅ 4. 설치 확인

### 4.1 앱 빌드 및 실행

```powershell
cd c:\Users\hp\Desktop\sihu\flai\flutter_application_1
flutter run
```

### 4.2 로그 확인

```powershell
adb logcat | Select-String "CubismFramework|Live2D"
```

**성공 시 예상 로그:**
```
I CubismFramework: ✓ Native library loaded: libLive2DCubismCore.so
I CubismFramework: ✓ Framework initialized
I CubismFramework:   Version: Cubism SDK 5.0.0
```

**실패 시 예상 로그:**
```
E CubismFramework: ✗ Failed to load native library: ...
W CubismFramework: SDK not installed. Running in fallback mode.
```

---

## 🔍 5. 문제 해결

### 5.1 UnsatisfiedLinkError

**원인**: .so 파일이 없거나 잘못된 위치

**해결**:
1. jniLibs 폴더 경로 확인
2. 파일 이름이 정확히 `libLive2DCubismCore.so`인지 확인
3. 디바이스 ABI와 일치하는 폴더에 파일이 있는지 확인

### 5.2 특정 기기에서만 크래시

**원인**: 해당 ABI용 .so 파일 누락

**해결**:
```powershell
# 기기의 ABI 확인
adb shell getprop ro.product.cpu.abi
# 예: arm64-v8a

# 해당 폴더에 .so 파일 있는지 확인
```

### 5.3 SDK 버전 불일치

**원인**: SDK와 Android/Kotlin 버전 호환성 문제

**해결**:
1. 최신 Cubism SDK 버전 사용
2. build.gradle에서 minSdk 버전 확인 (21 이상 권장)

---

## 📚 6. 참고 자료

- [Cubism SDK Documentation](https://docs.live2d.com/cubism-sdk-manual/top/)
- [Cubism SDK for Native Manual](https://docs.live2d.com/cubism-sdk-manual/cubism-sdk-for-native/)
- [Sample Project (GitHub)](https://github.com/Live2D/CubismNativeSamples)

---

## ⏭️ 7. 다음 단계

SDK 설치 완료 후:

1. **코드 활성화**: TODO 주석 해제
2. **빌드 테스트**: `flutter run`
3. **Phase 7 EXIT 체크리스트 실행**: [PHASE7_EXECUTION_PLAN.md](./PHASE7_EXECUTION_PLAN.md) 참조
4. **Phase 8 진입**: 고급 기능 구현 (물리, 표정 등)
