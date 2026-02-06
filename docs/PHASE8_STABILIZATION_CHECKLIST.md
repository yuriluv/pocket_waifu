# Phase 8: FINAL Stabilization & Optimization

> **STATUS**: Implemented (Core Items Complete)  
> **GOAL**: Long-runtime stability (hours to days), predictable Android lifecycle behavior, easy future maintenance  
> **RULE**: No new systems. Features are frozen. Prefer clarity over clever abstractions.

---

## Implementation Summary

### Completed Items ✅

1. **State Synchronization** - Flutter↔Native state sync via periodic broadcasts and callbacks
2. **Permission Revocation Recovery** - Auto-detect and graceful shutdown when permission revoked
3. **Memory Leak Prevention** - Shared TextureManager instance, proper resource cleanup
4. **Double-Dispose Guards** - Prevents crashes from multiple dispose() calls
5. **Debug Health Checks** - `getHealthStatus()` / `forceReset()` endpoints for diagnostics
6. **WHY Documentation** - Added explanatory comments to key decision points

### Pending Items ⏳

- Frame drop counter & metrics (Priority 4 - nice to have)
- Process death state persistence (Priority 3 - consider if needed)
- UX micro-polish (Priority 4 - optional)

---

## Architecture Summary (As-Is)

### Android Native Layer

| File | Lines | Purpose |
|------|-------|---------|
| `Live2DOverlayService.kt` | 590 | Foreground Service managing overlay window, gesture handling |
| `Live2DGLRenderer.kt` | 548 | OpenGL ES 2.0 renderer with dual-mode (SDK + Fallback) |
| `CubismModel.kt` | 380 | SDK facade - delegates to LAppModel or TextureModelRenderer |
| `LAppModel.kt` | 490 | Direct SDK wrapper (pending SDK activation) |
| `CubismFrameworkManager.kt` | 354 | SDK lifecycle singleton (load/init/dispose) |
| `CubismMotionManager.kt` | 398 | Motion playback and priority queue |
| `Live2DManager.kt` | 75 | Simple delegation wrapper |

### Flutter Layer

| File | Lines | Purpose |
|------|-------|---------|
| `live2d_native_bridge.dart` | 579 | Platform Channel (MethodChannel + EventChannel) |
| `live2d_overlay_service.dart` | 416 | High-level overlay API for Flutter |

### State Flow

```
Flutter (Live2DOverlayService)         Platform Channel         Native (Live2DOverlayService)
        │                                    │                           │
        ├─ _isOverlayVisible ───────► showOverlay() ──────────► isRunning (@Volatile)
        │                                    │                           │
        │                               MethodChannel                GLSurfaceView
        │                                    │                           │
        └─ _currentModelPath ───────► loadModel() ────────────► Live2DGLRenderer
                                             │                           │
                                         EventChannel                cubismModel
                                             │                           │
                                    <── nativeLog() <─────────── Live2DLogger
```

---

## Prioritized Stability Checklist

### Priority 1: CRITICAL (Do First)

#### 1.1 State Synchronization Single Source of Truth

**Problem**: Flutter `_isOverlayVisible` can desync from native `isRunning` after process restart or permission revocation.

**Fix in `live2d_overlay_service.dart`**:
```dart
// BEFORE: Trust local state
bool get isOverlayVisible => _isOverlayVisible;

// AFTER: Always verify with native when accessed externally
Future<bool> syncOverlayState() async {
  final nativeState = await _bridge.isOverlayVisible();
  if (_isOverlayVisible != nativeState) {
    live2dLog.warning(_tag, 'State desync detected', 
      details: 'local=$_isOverlayVisible, native=$nativeState');
    _isOverlayVisible = nativeState;
  }
  return nativeState;
}
```

**Fix in `Live2DOverlayService.kt`**:
```kotlin
// Add periodic state broadcast (every 30s when running)
private val stateCheckHandler = Handler(Looper.getMainLooper())
private val stateCheckRunnable = object : Runnable {
    override fun run() {
        if (isRunning) {
            broadcastState()
            stateCheckHandler.postDelayed(this, 30_000)
        }
    }
}

private fun broadcastState() {
    flutterEventSink?.success(mapOf(
        "type" to "stateSync",
        "isRunning" to isRunning,
        "modelLoaded" to (renderer?.hasModel() == true)
    ))
}
```

#### 1.2 Permission Revocation Recovery

**Problem**: If user revokes overlay permission while service is running, service becomes zombie.

**Fix in `Live2DOverlayService.kt`**:
```kotlin
// In showOverlay() or onStartCommand():
private fun checkAndRecoverPermissions(): Boolean {
    if (!Settings.canDrawOverlays(this)) {
        Live2DLogger.w(TAG, "Overlay permission revoked", "stopping service")
        hideOverlayInternal()
        stopSelf()
        return false
    }
    return true
}

// Add periodic permission check
private val permissionCheckRunnable = object : Runnable {
    override fun run() {
        if (!checkAndRecoverPermissions()) return
        stateCheckHandler.postDelayed(this, 60_000) // Check every minute
    }
}
```

#### 1.3 GLSurfaceView Surface Recreation Safety

**Problem**: Race condition when surface is recreated - model path may be cleared before restoration attempt.

**Fix in `Live2DGLRenderer.kt`**:
```kotlin
// Add atomic save/restore latch
private val surfaceRestorationLock = Object()
private var pendingRestoration: ModelRestoration? = null

data class ModelRestoration(
    val path: String,
    val name: String,
    val timestamp: Long = System.currentTimeMillis()
)

override fun onSurfaceCreated(gl: GL10?, config: EGLConfig?) {
    Live2DLogger.i(TAG, "Surface created", null)
    
    synchronized(surfaceRestorationLock) {
        pendingRestoration?.let { restore ->
            // Only restore if request is recent (< 5s)
            if (System.currentTimeMillis() - restore.timestamp < 5000) {
                Live2DLogger.i(TAG, "Restoring model after surface recreate", restore.path)
                handler.post { loadModel(restore.path, restore.name) }
            }
            pendingRestoration = null
        }
    }
}
```

---

### Priority 2: HIGH (Important for Stability)

#### 2.1 Memory Leak Prevention - TextureManager

**Problem**: `LAppModel.loadTexture()` creates new `CubismTextureManager` instance per call - wasteful and potential leak.

**Fix in `LAppModel.kt`**:
```kotlin
// BEFORE:
private fun loadTexture(path: String): Int {
    val manager = CubismTextureManager()  // ← Creates new instance!
    val ids = manager.loadTextures(listOf(path))
    return ids.firstOrNull() ?: 0
}

// AFTER:
// Reuse single texture manager instance
private val textureManager = CubismTextureManager()

private fun loadTexture(path: String): Int {
    return textureManager.loadTexture(path)
}

// Update release() to clear the shared manager:
fun release() {
    // ... existing code ...
    textureManager.release()  // Add this
}
```

#### 2.2 ByteBuffer Cleanup in CubismMotionManager

**Problem**: `motionDataCache` uses `ByteBuffer.allocateDirect()` which allocates off-heap memory. Cache clear doesn't guarantee immediate deallocation.

**Fix in `CubismMotionManager.kt`**:
```kotlin
@Synchronized
fun release() {
    // ... existing code ...
    
    // Explicitly clear buffers before removing references
    motionDataCache.values.forEach { buffer ->
        buffer.clear()  // Reset position/limit
    }
    motionDataCache.clear()
    
    // Suggest GC for off-heap memory
    System.gc()
    
    isReleased = true
}
```

#### 2.3 Renderer Double-Dispose Guard

**Problem**: `Live2DGLRenderer.dispose()` could be called multiple times in edge cases.

**Fix in `Live2DGLRenderer.kt`**:
```kotlin
@Volatile private var isDisposed = false

fun dispose() {
    if (isDisposed) {
        Live2DLogger.d(TAG, "Already disposed", null)
        return
    }
    
    Live2DLogger.i(TAG, "Disposing renderer", null)
    
    synchronized(this) {
        if (isDisposed) return  // Double-check under lock
        isDisposed = true
        
        // Existing dispose logic...
        cubismModel?.release()
        cubismModel = null
        currentModel?.release()
        currentModel = null
        textureRenderer?.release()
        textureRenderer = null
    }
}
```

---

### Priority 3: MEDIUM (Defensive Improvements)

#### 3.1 Debug Health Check Endpoint

**Add to `Live2DNativeBridge.kt`**:
```kotlin
"getHealthStatus" -> {
    val status = mapOf(
        "service" to mapOf(
            "isRunning" to Live2DOverlayService.isRunning,
            "uptimeMs" to (if (Live2DOverlayService.isRunning) 
                System.currentTimeMillis() - serviceStartTime else 0)
        ),
        "renderer" to mapOf(
            "hasModel" to (renderer?.hasModel() == true),
            "frameCount" to frameCount,
            "lastFrameTimeMs" to lastFrameTimeMs
        ),
        "sdk" to CubismFrameworkManager.getStatusInfo(),
        "memory" to mapOf(
            "heapUsedMB" to (Runtime.getRuntime().totalMemory() - 
                Runtime.getRuntime().freeMemory()) / 1024 / 1024,
            "heapMaxMB" to Runtime.getRuntime().maxMemory() / 1024 / 1024
        )
    )
    result.success(status)
}
```

**Add to `live2d_native_bridge.dart`**:
```dart
Future<Map<String, dynamic>> getHealthStatus() async {
  try {
    final result = await _methodChannel.invokeMethod<Map>('getHealthStatus');
    return Map<String, dynamic>.from(result ?? {});
  } catch (e) {
    return {'error': e.toString()};
  }
}
```

#### 3.2 Force Reset Mechanism

**Add to `Live2DNativeBridge.kt`**:
```kotlin
"forceReset" -> {
    Live2DLogger.w(TAG, "Force reset requested", null)
    
    try {
        // 1. Stop renderer
        renderer?.dispose()
        renderer = null
        
        // 2. Reinitialize SDK
        CubismFrameworkManager.reinitialize()
        
        // 3. Recreate renderer
        renderer = Live2DGLRenderer(context)
        
        result.success(true)
    } catch (e: Exception) {
        Live2DLogger.e(TAG, "Force reset failed", e)
        result.success(false)
    }
}
```

#### 3.3 Process Death State Persistence

**Add SharedPreferences state save in `Live2DOverlayService.kt`**:
```kotlin
private fun saveState() {
    val prefs = getSharedPreferences("live2d_state", Context.MODE_PRIVATE)
    prefs.edit().apply {
        putBoolean("was_running", isRunning)
        putString("last_model_path", currentModelInfo?.path)
        putLong("last_active", System.currentTimeMillis())
        apply()
    }
}

private fun restoreStateIfRecent(): Boolean {
    val prefs = getSharedPreferences("live2d_state", Context.MODE_PRIVATE)
    val wasRunning = prefs.getBoolean("was_running", false)
    val lastActive = prefs.getLong("last_active", 0)
    
    // Only restore if crashed within last 5 minutes
    if (wasRunning && System.currentTimeMillis() - lastActive < 300_000) {
        val modelPath = prefs.getString("last_model_path", null)
        Live2DLogger.i(TAG, "Restoring after process death", "modelPath=$modelPath")
        return modelPath != null
    }
    return false
}
```

---

### Priority 4: LOW (Nice to Have)

#### 4.1 Frame Drop Counter

```kotlin
// In Live2DGLRenderer.kt
private var frameCount = 0L
private var droppedFrameCount = 0L
private var lastFrameTime = 0L

override fun onDrawFrame(gl: GL10?) {
    val now = System.nanoTime()
    val frameTime = now - lastFrameTime
    lastFrameTime = now
    
    // Count dropped frames (> 2x target frame time)
    if (frameTimeMs > 0 && frameTime > frameTimeMs * 2_000_000) {
        droppedFrameCount++
    }
    frameCount++
    
    // ... existing draw logic
}

fun getFrameStats(): Map<String, Long> = mapOf(
    "frameCount" to frameCount,
    "droppedFrames" to droppedFrameCount,
    "dropRate" to if (frameCount > 0) (droppedFrameCount * 100 / frameCount) else 0
)
```

#### 4.2 UX Micro-Polish

- Add haptic feedback on drag start/end
- Smooth position interpolation on release
- Add subtle shadow under character

---

## WHY Documentation Additions

Add these comments to key decision points:

### `CubismFrameworkManager.kt`
```kotlin
// WHY fallback mode defaults to true:
// This is a defensive design choice. The app must function even without 
// the SDK .so files installed. We only flip to SDK mode AFTER loading 
// succeeds, not before. This prevents partial initialization states where 
// the app thinks SDK is available but it isn't.
@Volatile
private var isFallbackMode = true  // Default to fallback until proven otherwise
```

### `Live2DGLRenderer.kt`
```kotlin
// WHY dual model references (cubismModel + currentModel):
// - cubismModel: CubismModel wrapper that delegates to LAppModel (SDK) or TextureModelRenderer (fallback)
// - currentModel: Legacy Live2DModel for backwards compat
// This duplication exists because we migrated from a simpler rendering 
// architecture. In a future refactor, unify to just CubismModel.
```

### `Live2DOverlayService.kt`
```kotlin
// WHY isRunning is in companion object:
// The service can be stopped and restarted by Android at any time.
// Companion object survives service recreation within the same process.
// This allows Flutter to query state even if service instance changed.
// CAVEAT: Does not survive process death - Flutter should verify via isOverlayVisible() call.
```

---

## Known Limitations (Intentionally Unsolved)

### 1. SDK Not Yet Activated
**Status**: Expected  
**Reason**: Cubism SDK .so files not installed. All SDK code paths are commented with TODOs.  
**Impact**: Texture-only preview, no animation. Functionally complete for current needs.

### 2. No Cross-Process State Sync
**Status**: Accepted Risk  
**Reason**: Would require ContentProvider or Binder IPC - overkill for single-app use.  
**Impact**: If Flutter process dies while service runs, state desyncs until next isOverlayVisible() call.

### 3. Memory Growth Over Time
**Status**: Monitor  
**Reason**: ByteBuffer.allocateDirect() doesn't immediately free on clear(). JVM will collect eventually.  
**Impact**: May see gradual memory increase during long sessions. Restart clears it.

### 4. No Hot Reload of Models
**Status**: By Design  
**Reason**: Changing models while overlay is visible requires dispose/recreate cycle.  
**Impact**: User must hide overlay → change model → show overlay.

### 5. Gesture Conflicts with System UI
**Status**: Android Limitation  
**Reason**: TYPE_APPLICATION_OVERLAY can't capture gestures that Android reserves (back, home, recents).  
**Impact**: Character can't be placed too close to system nav areas.

---

## Implementation Order

1. **Week 1**: Priority 1 items (state sync, permission recovery, surface safety)
2. **Week 2**: Priority 2 items (memory leaks, double-dispose)
3. **Week 3**: Priority 3 items (debug endpoints, reset mechanism)
4. **Optional**: Priority 4 items (metrics, UX polish)

---

## Verification Checklist

Before marking Phase 8 complete:

- [ ] Run overlay for 4+ hours continuously - no crashes
- [ ] Toggle overlay 50+ times - no state desync
- [ ] Load/unload models 20+ times - no memory growth
- [ ] Revoke/grant overlay permission - graceful recovery
- [ ] Force stop app while overlay visible - clean restart
- [ ] Run `adb shell dumpsys meminfo` - heap stays under 100MB
- [ ] All TODO comments have matching tracking issue or "Phase 9" tag

---

*Document created: Phase 8 Stabilization*  
*Last updated: In Progress*
