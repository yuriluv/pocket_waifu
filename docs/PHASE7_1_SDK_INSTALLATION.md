# Phase 7-1: Live2D Cubism SDK for Native (Android) Installation Guide

## Overview

This document explains how to install the Live2D Cubism SDK native libraries to enable actual Live2D model rendering.

**Current state**: Texture preview / fallback mode (SDK not installed)
**Goal state**: SDK loadable and detectable at runtime

---

## Step 1: Download Live2D Cubism SDK for Native

1. Go to: https://www.live2d.com/en/sdk/download/native/
2. Download "Cubism SDK for Native"
3. Accept the license agreement
4. Extract the downloaded archive

---

## Step 2: Locate Native Library Files

After extracting the SDK, find the Android native libraries:

```
CubismSdk_Native/
└── Core/
    └── lib/
        └── android/
            ├── arm64-v8a/
            │   └── libLive2DCubismCore.so
            ├── armeabi-v7a/
            │   └── libLive2DCubismCore.so
            └── x86_64/
                └── libLive2DCubismCore.so
```

---

## Step 3: Copy Libraries to Project

Copy the `.so` files to your project's jniLibs directory:

### Target Directory Structure

```
android/app/src/main/jniLibs/
├── arm64-v8a/
│   └── libLive2DCubismCore.so    ← Copy here
├── armeabi-v7a/
│   └── libLive2DCubismCore.so    ← Copy here
└── x86_64/
    └── libLive2DCubismCore.so    ← Copy here
```

### Commands (Windows)

```powershell
# From your SDK download location
$SDK_PATH = "C:\path\to\CubismSdk_Native\Core\lib\android"
$PROJECT_PATH = "C:\Users\hp\Desktop\sihu\flai\flutter_application_1\android\app\src\main\jniLibs"

Copy-Item "$SDK_PATH\arm64-v8a\libLive2DCubismCore.so" -Destination "$PROJECT_PATH\arm64-v8a\"
Copy-Item "$SDK_PATH\armeabi-v7a\libLive2DCubismCore.so" -Destination "$PROJECT_PATH\armeabi-v7a\"
Copy-Item "$SDK_PATH\x86_64\libLive2DCubismCore.so" -Destination "$PROJECT_PATH\x86_64\"
```

---

## Step 4: ABI (Application Binary Interface) Explanation

| ABI | Device Type | Required? |
|-----|-------------|-----------|
| `arm64-v8a` | Modern Android phones (64-bit ARM) | **YES** - Most devices |
| `armeabi-v7a` | Older Android phones (32-bit ARM) | Recommended |
| `x86_64` | Android emulators (64-bit x86) | For development/testing |

### Minimum Requirement
At minimum, include `arm64-v8a` for production. Include all three for full compatibility.

---

## Step 5: Verify Installation

### Run the App

```powershell
flutter run
```

### Look for These Logs

**Success** (SDK installed correctly):
```
I/CubismFramework: ✓ Native library loaded: libLive2DCubismCore.so
I/CubismFramework: [Phase7-1] Live2D Cubism SDK native library loaded successfully.
I/CubismFramework: [Phase7-1] SDK is loadable and detectable at runtime.
I/CubismFramework: Phase 7-1 Result: PASSED ✓
```

**Failure** (SDK not found):
```
W/CubismFramework: ✗ Native library not found: libLive2DCubismCore.so
W/CubismFramework: [Phase7-1] SDK native library NOT present - cannot render Live2D models.
I/CubismFramework: Running in FALLBACK MODE: Texture preview only
I/CubismFramework: Phase 7-1 Result: FAILED ✗
```

### Programmatic Verification

In Kotlin code, call:
```kotlin
val isAvailable = CubismFrameworkManager.checkSdkLoadStatus()
// Logs detailed verification status
// Returns true if SDK is correctly installed
```

Or quick check:
```kotlin
if (CubismFrameworkManager.isSdkAvailable()) {
    // SDK native library is present and loadable
}
```

---

## Gradle Configuration (Optional)

### When ABI Filters Are Needed

**NOT required** for Phase 7-1. Android Gradle Plugin automatically:
- Picks up `.so` files from `jniLibs/`
- Includes them in APK for matching ABIs

### When to Add ABI Filters

Add ABI filters only if you need to:
1. Reduce APK size (exclude unused ABIs)
2. Debug ABI-specific issues

```kotlin
// android/app/build.gradle.kts
android {
    defaultConfig {
        ndk {
            abiFilters += listOf("arm64-v8a", "armeabi-v7a", "x86_64")
        }
    }
}
```

**Recommendation**: Skip this for Phase 7-1. Add later if APK size optimization is needed.

---

## Troubleshooting

### Problem: "Native library not found"

1. **Check file names**: Must be exactly `libLive2DCubismCore.so`
2. **Check directory names**: Case-sensitive (`arm64-v8a`, not `ARM64-V8A`)
3. **Check file permissions**: Files must be readable
4. **Clean rebuild**: Run `flutter clean && flutter run`

### Problem: "UnsatisfiedLinkError"

The `.so` file exists but is incompatible:
- Wrong ABI version for your device/emulator
- Corrupted file during copy
- SDK version mismatch

Try: Re-download and re-copy the SDK files.

### Problem: "SecurityException"

App doesn't have permission to load native libraries:
- Rare on standard Android
- May occur on heavily customized OEM ROMs
- Check if running in restricted mode

---

## File Checklist

After installation, verify these files exist:

```
android/app/src/main/jniLibs/
├── arm64-v8a/
│   └── libLive2DCubismCore.so    (~1.5 MB)
├── armeabi-v7a/
│   └── libLive2DCubismCore.so    (~1.0 MB)
└── x86_64/
    └── libLive2DCubismCore.so    (~1.8 MB)
```

---

## What Phase 7-1 Does NOT Include

- ❌ CubismMoc creation
- ❌ CubismModel instantiation
- ❌ moc3 file loading
- ❌ Motion/expression rendering
- ❌ Physics simulation
- ❌ Any Flutter-side changes

Phase 7-1 is **ONLY** about confirming the native library is loadable.

---

## Next Steps (Phase 7-2+)

After Phase 7-1 verification passes:
1. Enable CubismFramework API imports
2. Initialize CubismFramework with allocator
3. Implement moc3 loading in LAppModel
4. Connect to Live2DGLRenderer

---

## Quick Reference

| Method | Purpose |
|--------|---------|
| `CubismFrameworkManager.isSdkAvailable()` | Check if SDK native lib is loadable |
| `CubismFrameworkManager.checkSdkLoadStatus()` | Full verification with detailed logs |
| `CubismFrameworkManager.isSdkLibraryLoaded()` | Check if lib was already loaded |
| `CubismFrameworkManager.isSdkRenderingReady()` | Check if full rendering is available |
