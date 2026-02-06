# Phase 7: Live2D Cubism SDK Integration — Execution Plan

> **Project**: Pocket Waifu  
> **Target**: Android Native OpenGL Live2D Rendering  
> **Date**: 2026-02-06  
> **Status**: Ready for Execution

---

## SECTION 1 — Phase 7 Strategy Overview

### 1.1 MVP Scope Definition

| IN SCOPE (Required for Phase 7 Completion) | OUT OF SCOPE (Deferred to Phase 8) |
|-------------------------------------------|-----------------------------------|
| ✅ Cubism SDK library installation (.so files) | ❌ Physics simulation |
| ✅ CubismFramework single initialization | ❌ Eye blink automation |
| ✅ moc3 file loading and parsing | ❌ Breathing animation |
| ✅ Texture loading via SDK | ❌ Gaze/LookAt tracking |
| ✅ Basic mesh rendering (static pose) | ❌ Expression blending |
| ✅ ONE Idle motion playback | ❌ Lip sync |
| ✅ Overlay lifecycle survival | ❌ Hit area detection |
| ✅ Surface recreation handling | ❌ Multiple motion layering |
| ✅ Memory-safe model reload | ❌ Parameter manual control |

### 1.2 Risk Minimization Strategy

1. **Incremental Integration**: SDK is integrated in isolation first, then connected to existing renderer
2. **Fallback Preservation**: TextureModelRenderer remains as fallback if SDK fails
3. **Single Responsibility**: New `CubismModel` wrapper handles ALL SDK interactions
4. **Thread Safety**: All SDK calls happen on GL thread via `queueEvent()`
5. **Early Validation**: SDK load verification before any rendering attempt

### 1.3 Success Criteria (Phase 7 Exit Gate)

```
□ Model loads without crash (moc3 + textures)
□ Model renders with correct mesh (not texture preview)
□ Idle motion plays and loops
□ Hide/show overlay preserves model state
□ Surface recreation does not crash
□ Model reload does not leak memory
□ No GL errors in logcat during normal operation
```

---

## SECTION 2 — File-Level Change Map

### 2.1 Files to CREATE (New)

| File Path | Purpose |
|-----------|---------|
| 🆕 `live2d/cubism/CubismFrameworkManager.kt` | Singleton for SDK lifecycle (init/dispose) |
| 🆕 `live2d/cubism/CubismModel.kt` | SDK model wrapper (load, update, draw) |
| 🆕 `live2d/cubism/CubismMotionManager.kt` | Motion loading and playback |
| 🆕 `live2d/cubism/CubismTextureManager.kt` | Texture loading via SDK |
| 🆕 `live2d/cubism/CubismRenderer.kt` | SDK draw call integration |
| 🆕 `live2d/cubism/CubismAllocator.kt` | Memory allocator for SDK |

### 2.2 Files to MODIFY (Existing)

| File Path | Modification Reason |
|-----------|---------------------|
| ✅ `live2d/core/Live2DManager.kt` | Remove placeholder, delegate to CubismFrameworkManager |
| ✅ `live2d/core/Live2DModel.kt` | Add CubismModel integration, keep parsing logic |
| ✅ `live2d/renderer/Live2DGLRenderer.kt` | Replace TextureModelRenderer calls with CubismRenderer |
| ✅ `android/app/build.gradle.kts` | Add jniLibs configuration if needed |

### 2.3 Files to LEAVE UNTOUCHED

| File Path | Reason |
|-----------|--------|
| ⛔ `live2d/Live2DPlugin.kt` | Channel setup is complete |
| ⛔ `live2d/Live2DMethodHandler.kt` | API contract is stable |
| ⛔ `live2d/Live2DEventStreamHandler.kt` | Event system is complete |
| ⛔ `live2d/overlay/Live2DOverlayService.kt` | Overlay management is complete |
| ⛔ `live2d/overlay/Live2DOverlayWindow.kt` | Window management is complete |
| ⛔ `live2d/gesture/*` | Gesture system is independent |
| ⛔ `live2d/renderer/PlaceholderShader.kt` | Keep for fallback |
| ⛔ `live2d/renderer/TextureModelRenderer.kt` | Keep for fallback |
| ⛔ `live2d/renderer/Live2DGLSurfaceView.kt` | Surface management is complete |
| ⛔ `live2d/core/Model3JsonParser.kt` | Parsing logic is complete |
| ⛔ `live2d/core/Live2DLogger.kt` | Logging is complete |

---

## SECTION 3 — Step-by-Step Execution Plan

### Step 1: SDK Library Installation & Verification

**Objective**: Install Cubism SDK native libraries and verify they load correctly

**Files Involved**:
- `android/app/src/main/jniLibs/arm64-v8a/libLive2DCubismCore.so`
- `android/app/src/main/jniLibs/armeabi-v7a/libLive2DCubismCore.so`
- `android/app/src/main/jniLibs/x86_64/libLive2DCubismCore.so`
- `android/app/build.gradle.kts`

**Implementation Details**:

1. Download Cubism SDK for Native from: https://www.live2d.com/download/cubism-sdk/
2. Extract and locate the Core library files:
   ```
   CubismSdkForNative/Core/lib/android/
   ├── arm64-v8a/libLive2DCubismCore.so
   ├── armeabi-v7a/libLive2DCubismCore.so
   └── x86_64/libLive2DCubismCore.so
   ```
3. Copy .so files to corresponding jniLibs folders
4. Create verification code:

```kotlin
// Temporary verification in Live2DManager.kt
fun verifySdkLoad(): Boolean {
    return try {
        System.loadLibrary("Live2DCubismCore")
        Live2DLogger.i("SDK Load", "SUCCESS - libLive2DCubismCore.so loaded")
        true
    } catch (e: UnsatisfiedLinkError) {
        Live2DLogger.e("SDK Load", "FAILED - ${e.message}")
        false
    }
}
```

**Common Pitfalls**:
- Wrong ABI folder (arm64-v8a vs armeabi-v7a)
- Missing library for device architecture
- Incorrect library name (must be exact: `libLive2DCubismCore.so`)
- Gradle not picking up jniLibs (check sourceSets config)

**Verification**:
```
✓ PASS: Log shows "SUCCESS - libLive2DCubismCore.so loaded"
✗ FAIL: UnsatisfiedLinkError in logcat
```

---

### Step 2: CubismFramework Lifecycle Implementation

**Objective**: Create singleton manager for SDK initialization with proper lifecycle

**Files Involved**:
- 🆕 `live2d/cubism/CubismFrameworkManager.kt`
- 🆕 `live2d/cubism/CubismAllocator.kt`
- ✅ `live2d/core/Live2DManager.kt`

**Implementation Details**:

```kotlin
// CubismAllocator.kt
package com.example.flutter_application_1.live2d.cubism

import com.live2d.sdk.cubism.framework.CubismFramework
import com.live2d.sdk.cubism.framework.ICubismAllocator
import java.nio.ByteBuffer

/**
 * Cubism SDK Memory Allocator
 */
class CubismAllocator : ICubismAllocator {
    override fun allocate(size: Int): ByteBuffer {
        return ByteBuffer.allocateDirect(size)
    }

    override fun deallocate(buffer: ByteBuffer) {
        // Direct buffers are GC'd automatically
    }

    override fun allocateAligned(size: Int, alignment: Int): ByteBuffer {
        return ByteBuffer.allocateDirect(size + alignment)
    }

    override fun deallocateAligned(buffer: ByteBuffer) {
        // Direct buffers are GC'd automatically
    }
}
```

```kotlin
// CubismFrameworkManager.kt
package com.example.flutter_application_1.live2d.cubism

import com.example.flutter_application_1.live2d.core.Live2DLogger
import com.live2d.sdk.cubism.framework.CubismFramework

/**
 * Cubism SDK Framework Manager (Singleton)
 * 
 * CRITICAL: initialize() must be called ONCE on GL thread
 * CRITICAL: dispose() must be called before app termination
 */
object CubismFrameworkManager {
    
    private var isInitialized = false
    private var isSdkLoaded = false
    private val allocator = CubismAllocator()
    
    /**
     * Load native library
     * Can be called from any thread, but only once
     */
    @Synchronized
    fun loadSdk(): Boolean {
        if (isSdkLoaded) return true
        
        return try {
            System.loadLibrary("Live2DCubismCore")
            isSdkLoaded = true
            Live2DLogger.i("CubismFramework", "Native library loaded")
            true
        } catch (e: UnsatisfiedLinkError) {
            Live2DLogger.e("CubismFramework", "Failed to load native library: ${e.message}")
            false
        }
    }
    
    /**
     * Initialize Cubism Framework
     * MUST be called on GL thread
     * MUST be called only once
     */
    @Synchronized
    fun initialize(): Boolean {
        if (isInitialized) {
            Live2DLogger.w("CubismFramework", "Already initialized, skipping")
            return true
        }
        
        if (!isSdkLoaded) {
            if (!loadSdk()) return false
        }
        
        return try {
            // Initialize with allocator
            CubismFramework.startUp(allocator, null)
            CubismFramework.initialize()
            isInitialized = true
            
            val version = CubismFramework.getVersion()
            Live2DLogger.i("CubismFramework", "Initialized - Version: $version")
            true
        } catch (e: Exception) {
            Live2DLogger.e("CubismFramework", "Initialization failed: ${e.message}")
            false
        }
    }
    
    /**
     * Check if framework is ready
     */
    fun isReady(): Boolean = isInitialized && isSdkLoaded
    
    /**
     * Dispose framework
     * MUST be called on GL thread
     */
    @Synchronized
    fun dispose() {
        if (!isInitialized) return
        
        try {
            CubismFramework.dispose()
            isInitialized = false
            Live2DLogger.i("CubismFramework", "Disposed")
        } catch (e: Exception) {
            Live2DLogger.e("CubismFramework", "Dispose failed: ${e.message}")
        }
    }
    
    /**
     * Get SDK version string
     */
    fun getVersionString(): String {
        return if (isInitialized) {
            "Cubism SDK ${CubismFramework.getVersion()}"
        } else {
            "Not initialized"
        }
    }
}
```

**Update Live2DManager.kt**:
```kotlin
// Replace placeholder with delegation
fun initialize(context: Context): Boolean {
    return CubismFrameworkManager.initialize()
}

fun isSdkAvailable(): Boolean = CubismFrameworkManager.isReady()

fun dispose() {
    CubismFrameworkManager.dispose()
}
```

**Common Pitfalls**:
- Calling `initialize()` twice → SDK crash
- Calling `initialize()` off GL thread → undefined behavior
- Not calling `dispose()` → memory leak on repeated app launches
- Calling SDK methods before `initialize()` → crash

**Verification**:
```
✓ PASS: Log shows "CubismFramework Initialized - Version: X.X.X"
✓ PASS: Second initialize() call shows "Already initialized, skipping"
✗ FAIL: Any crash or exception during initialization
```

---

### Step 3: Model Loading Pipeline

**Objective**: Load moc3 file and textures using SDK APIs

**Files Involved**:
- 🆕 `live2d/cubism/CubismModel.kt`
- 🆕 `live2d/cubism/CubismTextureManager.kt`
- ✅ `live2d/core/Live2DModel.kt`

**Implementation Details**:

```kotlin
// CubismTextureManager.kt
package com.example.flutter_application_1.live2d.cubism

import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.opengl.GLES20
import android.opengl.GLUtils
import com.example.flutter_application_1.live2d.core.Live2DLogger
import java.io.File

/**
 * Texture Manager for Cubism Models
 * Handles loading textures to OpenGL and binding them to model
 */
class CubismTextureManager {
    
    private val textureIds = mutableListOf<Int>()
    
    /**
     * Load textures from file paths
     * MUST be called on GL thread
     * 
     * @param texturePaths List of absolute texture file paths
     * @return List of OpenGL texture IDs
     */
    fun loadTextures(texturePaths: List<String>): List<Int> {
        release() // Release any existing textures
        
        for ((index, path) in texturePaths.withIndex()) {
            val textureId = loadSingleTexture(path)
            if (textureId != 0) {
                textureIds.add(textureId)
                Live2DLogger.GL.d("Texture loaded", "[$index] $path -> ID: $textureId")
            } else {
                Live2DLogger.GL.e("Texture load failed", "[$index] $path")
                // Add placeholder to maintain index alignment
                textureIds.add(0)
            }
        }
        
        Live2DLogger.GL.i("Textures loaded", "${textureIds.count { it != 0 }}/${texturePaths.size}")
        return textureIds.toList()
    }
    
    private fun loadSingleTexture(path: String): Int {
        val file = File(path)
        if (!file.exists()) {
            Live2DLogger.GL.w("Texture file not found", path)
            return 0
        }
        
        val options = BitmapFactory.Options().apply {
            inScaled = false
            inPreferredConfig = Bitmap.Config.ARGB_8888
        }
        
        val bitmap = BitmapFactory.decodeFile(path, options) ?: return 0
        
        val textureHandle = IntArray(1)
        GLES20.glGenTextures(1, textureHandle, 0)
        
        if (textureHandle[0] == 0) {
            bitmap.recycle()
            return 0
        }
        
        GLES20.glBindTexture(GLES20.GL_TEXTURE_2D, textureHandle[0])
        
        // Texture parameters
        GLES20.glTexParameteri(GLES20.GL_TEXTURE_2D, GLES20.GL_TEXTURE_MIN_FILTER, GLES20.GL_LINEAR_MIPMAP_LINEAR)
        GLES20.glTexParameteri(GLES20.GL_TEXTURE_2D, GLES20.GL_TEXTURE_MAG_FILTER, GLES20.GL_LINEAR)
        GLES20.glTexParameteri(GLES20.GL_TEXTURE_2D, GLES20.GL_TEXTURE_WRAP_S, GLES20.GL_CLAMP_TO_EDGE)
        GLES20.glTexParameteri(GLES20.GL_TEXTURE_2D, GLES20.GL_TEXTURE_WRAP_T, GLES20.GL_CLAMP_TO_EDGE)
        
        // Upload to GPU
        GLUtils.texImage2D(GLES20.GL_TEXTURE_2D, 0, bitmap, 0)
        GLES20.glGenerateMipmap(GLES20.GL_TEXTURE_2D)
        
        bitmap.recycle()
        
        return textureHandle[0]
    }
    
    /**
     * Get texture ID by index
     */
    fun getTextureId(index: Int): Int {
        return textureIds.getOrNull(index) ?: 0
    }
    
    /**
     * Release all textures
     * MUST be called on GL thread
     */
    fun release() {
        if (textureIds.isNotEmpty()) {
            val ids = textureIds.filter { it != 0 }.toIntArray()
            if (ids.isNotEmpty()) {
                GLES20.glDeleteTextures(ids.size, ids, 0)
            }
            textureIds.clear()
            Live2DLogger.GL.d("Textures released", "${ids.size} textures")
        }
    }
}
```

```kotlin
// CubismModel.kt
package com.example.flutter_application_1.live2d.cubism

import com.example.flutter_application_1.live2d.core.Live2DLogger
import com.example.flutter_application_1.live2d.core.Model3JsonParser
import com.live2d.sdk.cubism.framework.CubismFramework
import com.live2d.sdk.cubism.framework.CubismModelSettingJson
import com.live2d.sdk.cubism.framework.model.CubismUserModel
import com.live2d.sdk.cubism.framework.motion.CubismMotion
import com.live2d.sdk.cubism.framework.motion.CubismMotionManager
import java.io.File

/**
 * Cubism SDK Model Wrapper
 * 
 * Encapsulates all SDK model operations including:
 * - moc3 loading
 * - Texture binding
 * - Motion management
 * - Update loop
 * - Rendering
 */
class CubismModel(
    private val modelPath: String,
    private val modelName: String
) {
    // SDK Model instance
    private var model: CubismUserModel? = null
    private var modelSetting: CubismModelSettingJson? = null
    
    // Texture manager
    private val textureManager = CubismTextureManager()
    
    // Motion manager
    private var motionManager: CubismMotionManager? = null
    private val loadedMotions = mutableMapOf<String, CubismMotion>()
    
    // Model directory
    private val modelDir: File = File(modelPath).parentFile ?: File("")
    
    // State
    private var isLoaded = false
    
    // Transform
    private var posX = 0f
    private var posY = 0f
    private var scale = 1f
    private var rotation = 0f
    private var opacity = 1f
    
    /**
     * Load model from model3.json
     * MUST be called on GL thread
     */
    fun load(): Boolean {
        if (isLoaded) {
            Live2DLogger.Model.w("CubismModel", "Already loaded: $modelName")
            return true
        }
        
        if (!CubismFrameworkManager.isReady()) {
            Live2DLogger.Model.e("CubismModel", "Framework not initialized")
            return false
        }
        
        try {
            // Parse model3.json
            val parser = Model3JsonParser(modelPath)
            if (!parser.parse()) {
                Live2DLogger.Model.e("CubismModel", "Failed to parse model3.json")
                return false
            }
            
            // Load moc3 file
            val mocPath = parser.mocFile
            if (mocPath == null || !File(mocPath).exists()) {
                Live2DLogger.Model.e("CubismModel", "moc3 file not found: $mocPath")
                return false
            }
            
            // Read moc3 bytes
            val mocBytes = File(mocPath).readBytes()
            
            // Create model
            model = CubismUserModel()
            model?.loadModel(mocBytes)
            
            // Load textures
            val textureIds = textureManager.loadTextures(parser.textures)
            
            // Bind textures to model renderer
            model?.let { m ->
                val renderer = m.renderer
                for ((index, textureId) in textureIds.withIndex()) {
                    if (textureId != 0) {
                        renderer.bindTexture(index, textureId)
                    }
                }
            }
            
            // Initialize motion manager
            motionManager = CubismMotionManager()
            
            isLoaded = true
            Live2DLogger.Model.i("CubismModel", "Loaded: $modelName (moc: $mocPath)")
            return true
            
        } catch (e: Exception) {
            Live2DLogger.Model.e("CubismModel", "Load failed: ${e.message}")
            release()
            return false
        }
    }
    
    /**
     * Update model state (called every frame)
     * MUST be called on GL thread
     * 
     * @param deltaTime Time since last frame in seconds
     */
    fun update(deltaTime: Float) {
        if (!isLoaded || model == null) return
        
        model?.let { m ->
            // Update motion
            motionManager?.updateMotion(m.model, deltaTime)
            
            // Update model
            m.model.update()
        }
    }
    
    /**
     * Draw model
     * MUST be called on GL thread
     * 
     * @param projectionMatrix 4x4 projection matrix
     */
    fun draw(projectionMatrix: FloatArray) {
        if (!isLoaded || model == null) return
        
        model?.let { m ->
            // Apply transforms
            val modelMatrix = m.modelMatrix
            modelMatrix.loadIdentity()
            modelMatrix.translate(posX, posY)
            modelMatrix.scale(scale, scale)
            
            // Calculate MVP
            val mvp = FloatArray(16)
            android.opengl.Matrix.multiplyMM(mvp, 0, projectionMatrix, 0, modelMatrix.array, 0)
            
            // Set opacity
            m.opacity = opacity
            
            // Draw
            m.renderer.setMvpMatrix(mvp)
            m.renderer.drawModel()
        }
    }
    
    /**
     * Play motion by group and index
     * 
     * @param group Motion group name (e.g., "Idle", "TapBody")
     * @param index Motion index within group
     * @param priority Motion priority (0=None, 1=Idle, 2=Normal, 3=Force)
     */
    fun playMotion(group: String, index: Int, priority: Int = 2): Boolean {
        if (!isLoaded || model == null) return false
        
        val motionKey = "$group:$index"
        
        // Check if motion already loaded
        var motion = loadedMotions[motionKey]
        
        if (motion == null) {
            // Load motion file
            motion = loadMotionFromGroup(group, index)
            if (motion != null) {
                loadedMotions[motionKey] = motion
            }
        }
        
        if (motion == null) {
            Live2DLogger.Model.w("CubismModel", "Motion not found: $motionKey")
            return false
        }
        
        // Start motion
        motionManager?.startMotionPriority(motion, priority)
        Live2DLogger.Model.d("CubismModel", "Playing motion: $motionKey")
        return true
    }
    
    private fun loadMotionFromGroup(group: String, index: Int): CubismMotion? {
        // Parse model3.json to get motion file
        val parser = Model3JsonParser(modelPath)
        if (!parser.parse()) return null
        
        val motions = parser.motionGroups[group] ?: return null
        if (index >= motions.size) return null
        
        val motionInfo = motions[index]
        val motionPath = motionInfo.absolutePath.ifEmpty {
            File(modelDir, motionInfo.file).absolutePath
        }
        
        if (!File(motionPath).exists()) {
            Live2DLogger.Model.w("CubismModel", "Motion file not found: $motionPath")
            return null
        }
        
        return try {
            val motionBytes = File(motionPath).readBytes()
            CubismMotion.create(motionBytes).also {
                it.setFadeInTime(motionInfo.fadeInTime)
                it.setFadeOutTime(motionInfo.fadeOutTime)
                it.isLoop = (group.equals("Idle", ignoreCase = true))
            }
        } catch (e: Exception) {
            Live2DLogger.Model.e("CubismModel", "Failed to load motion: ${e.message}")
            null
        }
    }
    
    // Transform setters
    fun setPosition(x: Float, y: Float) { posX = x; posY = y }
    fun setScale(s: Float) { scale = s.coerceIn(0.1f, 5f) }
    fun setRotation(degrees: Float) { rotation = degrees }
    fun setOpacity(o: Float) { opacity = o.coerceIn(0f, 1f) }
    
    // Getters
    fun getX() = posX
    fun getY() = posY
    fun getScale() = scale
    fun getRotation() = rotation
    fun getOpacity() = opacity
    fun isReady() = isLoaded
    
    /**
     * Release all resources
     * MUST be called on GL thread
     */
    fun release() {
        loadedMotions.values.forEach { it.delete() }
        loadedMotions.clear()
        motionManager = null
        
        textureManager.release()
        
        model?.delete()
        model = null
        
        isLoaded = false
        Live2DLogger.Model.d("CubismModel", "Released: $modelName")
    }
}
```

**Common Pitfalls**:
- moc3 file path is relative in model3.json → must resolve to absolute
- Texture index mismatch between model and loaded textures
- Loading large textures on non-GL thread
- Not calling `release()` before loading new model

**Verification**:
```
✓ PASS: Log shows "Loaded: [modelName] (moc: [path])"
✓ PASS: Log shows texture load success for all textures
✗ FAIL: "moc3 file not found" or "Framework not initialized"
```

---

### Step 4: Renderer Replacement

**Objective**: Replace TextureModelRenderer with CubismModel rendering in Live2DGLRenderer

**Files Involved**:
- ✅ `live2d/renderer/Live2DGLRenderer.kt`
- 🆕 `live2d/cubism/CubismRenderer.kt` (optional wrapper)

**Implementation Details**:

Modify `Live2DGLRenderer.kt`:

```kotlin
// Add imports
import com.example.flutter_application_1.live2d.cubism.CubismFrameworkManager
import com.example.flutter_application_1.live2d.cubism.CubismModel

// Replace currentModel type
private var cubismModel: CubismModel? = null

// In onSurfaceCreated:
override fun onSurfaceCreated(gl: GL10?, config: EGLConfig?) {
    Live2DLogger.Renderer.i("Surface created", "OpenGL ES 2.0 초기화 시작")
    
    // OpenGL 설정
    GLES20.glClearColor(bgRed, bgGreen, bgBlue, bgAlpha)
    GLES20.glEnable(GLES20.GL_BLEND)
    GLES20.glBlendFunc(GLES20.GL_SRC_ALPHA, GLES20.GL_ONE_MINUS_SRC_ALPHA)
    
    // Initialize Cubism Framework (CRITICAL: Only once, on GL thread)
    val sdkResult = CubismFrameworkManager.initialize()
    Live2DLogger.Renderer.i("Cubism SDK", if (sdkResult) "초기화 성공" else "초기화 실패 - 텍스처 모드로 폴백")
    
    // Keep placeholder/texture renderers for fallback
    placeholderShader = PlaceholderShader()
    placeholderShader?.initialize()
    
    textureRenderer = TextureModelRenderer()
    textureRenderer?.initialize()
    
    isReady = true
    lastFrameTime = System.currentTimeMillis()
    
    // Load pending model
    pendingModelPath?.let { path ->
        pendingModelName?.let { name ->
            loadModelInternal(path, name)
            pendingModelPath = null
            pendingModelName = null
        }
    }
}

// Replace onDrawFrame:
override fun onDrawFrame(gl: GL10?) {
    if (!isReady || isPaused) return
    
    // FPS limiting (keep existing logic)
    val currentTime = System.currentTimeMillis()
    val elapsed = currentTime - lastFrameTime
    if (enableFpsLimit && elapsed < frameTimeMs) return
    lastFrameTime = currentTime
    
    val deltaTime = elapsed.coerceAtLeast(1L) / 1000f
    
    // Clear
    GLES20.glClear(GLES20.GL_COLOR_BUFFER_BIT or GLES20.GL_DEPTH_BUFFER_BIT)
    
    // Render model
    cubismModel?.let { model ->
        if (model.isReady()) {
            // Update and draw with Cubism SDK
            model.update(deltaTime)
            model.draw(mvpMatrix)
        } else {
            // Fallback to texture renderer
            renderWithTextureFallback()
        }
    } ?: run {
        renderNoModelPlaceholder()
    }
    
    // Check GL errors (debug)
    checkGLError("onDrawFrame")
}

// Add GL error checker
private fun checkGLError(tag: String) {
    val error = GLES20.glGetError()
    if (error != GLES20.GL_NO_ERROR) {
        Live2DLogger.GL.e("GL Error", "$tag: $error")
    }
}

// Replace loadModelInternal:
private fun loadModelInternal(modelPath: String, modelName: String): Boolean {
    try {
        Live2DLogger.Model.i("모델 로드 시작", "path=$modelPath, name=$modelName")
        
        // Release existing model
        cubismModel?.release()
        
        // Create and load new model
        val model = CubismModel(modelPath, modelName)
        
        if (CubismFrameworkManager.isReady() && model.load()) {
            cubismModel = model
            
            // Try to play idle motion
            model.playMotion("Idle", 0, 1)
            
            Live2DLogger.Model.i("Cubism 모델 로드 성공", modelName)
            return true
        } else {
            // Fallback: keep texture renderer logic
            Live2DLogger.Model.w("Cubism 로드 실패", "텍스처 폴백 모드")
            cubismModel = null
            
            // Load with old Live2DModel for texture preview
            currentModel = Live2DModel(modelPath, modelName)
            currentModel?.load()
            currentModel?.getFirstTexturePath()?.let { textureRenderer?.loadTexture(it) }
            return true
        }
    } catch (e: Exception) {
        Live2DLogger.Model.e("모델 로드 예외", e)
        return false
    }
}

// Update dispose:
fun dispose() {
    cubismModel?.release()
    cubismModel = null
    currentModel?.dispose()
    currentModel = null
    placeholderShader?.dispose()
    textureRenderer?.dispose()
    isReady = false
}
```

**Common Pitfalls**:
- Calling SDK draw without valid OpenGL context
- MVP matrix not matching SDK expected format
- Blend mode conflicts with SDK's internal blend settings
- Not clearing GL error state before draw

**Verification**:
```
✓ PASS: Model renders with proper mesh (not flat texture)
✓ PASS: Model has visible parts/layers
✓ PASS: No GL errors in logcat
✗ FAIL: Black screen, pink squares, or crashes
```

---

### Step 5: Motion Playback Integration

**Objective**: Load and play at least one Idle motion

**Files Involved**:
- ✅ `live2d/cubism/CubismModel.kt` (already included in Step 3)
- ✅ `live2d/renderer/Live2DGLRenderer.kt`

**Implementation Details**:

Motion playback is included in CubismModel. Ensure:

1. After model load, call `playMotion("Idle", 0, 1)`:
```kotlin
// In loadModelInternal after successful load:
if (model.load()) {
    cubismModel = model
    
    // Auto-start Idle motion
    if (!model.playMotion("Idle", 0, 1)) {
        // Try alternative group names
        model.playMotion("idle", 0, 1) ||
        model.playMotion("IDLE", 0, 1) ||
        model.playMotion("待機", 0, 1)  // Japanese "Idle"
    }
}
```

2. Motion update timing in `onDrawFrame`:
```kotlin
// deltaTime must be in seconds (not milliseconds)
val deltaTime = elapsed.coerceAtLeast(1L) / 1000f  // Correct
// val deltaTime = elapsed  // Wrong - would be way too fast
```

3. Motion looping (in CubismModel.loadMotionFromGroup):
```kotlin
CubismMotion.create(motionBytes).also {
    it.setFadeInTime(motionInfo.fadeInTime)
    it.setFadeOutTime(motionInfo.fadeOutTime)
    // Loop only for Idle motions
    it.isLoop = group.equals("Idle", ignoreCase = true)
}
```

**Common Pitfalls**:
- Idle motion group name case sensitivity (`Idle` vs `idle`)
- deltaTime in wrong units (ms vs seconds)
- Motion file not found (relative path resolution)
- Motion not looping (forgetting `isLoop = true`)

**Verification**:
```
✓ PASS: Model animates smoothly (breathing, blinking, etc.)
✓ PASS: Animation loops indefinitely
✓ PASS: No jitter or speed issues
✗ FAIL: Static pose, jerky animation, or "Motion not found" log
```

---

### Step 6: Lifecycle Robustness

**Objective**: Ensure overlay hide/show and surface recreation don't crash

**Files Involved**:
- ✅ `live2d/renderer/Live2DGLRenderer.kt`
- ✅ `live2d/renderer/Live2DGLSurfaceView.kt`
- ✅ `live2d/overlay/Live2DOverlayService.kt`

**Implementation Details**:

1. **Surface Recreation Handling** in Live2DGLRenderer:

```kotlin
// Track if we need to reload model after surface recreation
private var savedModelPath: String? = null
private var savedModelName: String? = null

override fun onSurfaceCreated(gl: GL10?, config: EGLConfig?) {
    // ... existing initialization ...
    
    // Check if this is a surface recreation (not first creation)
    val wasInitialized = isReady
    
    // Re-initialize framework if needed
    CubismFrameworkManager.initialize()
    
    // ... rest of initialization ...
    
    // Reload model if we had one before surface recreation
    if (wasInitialized && savedModelPath != null) {
        loadModelInternal(savedModelPath!!, savedModelName ?: "model")
    } else {
        // Load pending model (first time)
        pendingModelPath?.let { ... }
    }
}

// Save model info before potential surface destruction
fun beforeSurfaceDestroyed() {
    cubismModel?.let {
        savedModelPath = modelPath
        savedModelName = modelName
    }
}
```

2. **Pause/Resume Handling** in Live2DGLSurfaceView:

```kotlin
override fun onPause() {
    renderer?.onPause()
    super.onPause()
}

override fun onResume() {
    super.onResume()
    renderer?.onResume()
}
```

3. **Service Hide/Show** in Live2DOverlayService:

```kotlin
private fun hideOverlay() {
    // Save state before destroying
    glSurfaceView?.renderer?.beforeSurfaceDestroyed()
    
    overlayView?.let { view ->
        glSurfaceView?.let { gl ->
            gl.onPause()
            // DON'T call dispose() here - we want to preserve framework state
        }
        windowManager.removeView(view)
    }
    // ... rest of cleanup ...
}

private fun showOverlay() {
    // Surface will be recreated, triggering onSurfaceCreated
    // Framework re-initialization is handled there
    // ... existing show logic ...
}
```

**Common Pitfalls**:
- Calling SDK methods after surface destroyed
- Double initialization on surface recreation
- Losing model state on hide/show
- GL context invalid after surface change

**Verification**:
```
✓ PASS: Hide overlay → Show overlay → Model still renders
✓ PASS: Rotate device (if applicable) → No crash
✓ PASS: Multiple hide/show cycles work
✗ FAIL: Crash on show after hide, black screen on recreation
```

---

### Step 7: Memory Leak Prevention & Model Reload

**Objective**: Ensure no memory leaks on model reload

**Files Involved**:
- ✅ `live2d/cubism/CubismModel.kt`
- ✅ `live2d/cubism/CubismTextureManager.kt`
- ✅ `live2d/renderer/Live2DGLRenderer.kt`

**Implementation Details**:

1. **Proper Release Order** in CubismModel:

```kotlin
fun release() {
    // Order matters! Release in reverse of creation
    
    // 1. Stop and release motions
    motionManager?.stopAllMotions()
    loadedMotions.values.forEach { 
        try { it.delete() } catch (e: Exception) { }
    }
    loadedMotions.clear()
    motionManager = null
    
    // 2. Release textures (GPU resources)
    textureManager.release()
    
    // 3. Release model (SDK resources)
    model?.let {
        try { it.delete() } catch (e: Exception) { }
    }
    model = null
    
    isLoaded = false
    Live2DLogger.Model.d("CubismModel", "Released: $modelName")
}
```

2. **Texture Id Tracking** in CubismTextureManager:

```kotlin
fun release() {
    if (textureIds.isNotEmpty()) {
        val validIds = textureIds.filter { it != 0 }.toIntArray()
        if (validIds.isNotEmpty()) {
            GLES20.glDeleteTextures(validIds.size, validIds, 0)
            checkGLError("deleteTextures")
        }
        textureIds.clear()
    }
}

private fun checkGLError(tag: String) {
    var error: Int
    while (GLES20.glGetError().also { error = it } != GLES20.GL_NO_ERROR) {
        Live2DLogger.GL.w("GL Error in $tag", "Code: $error")
    }
}
```

3. **Safe Model Reload** in Live2DGLRenderer:

```kotlin
private fun loadModelInternal(modelPath: String, modelName: String): Boolean {
    // CRITICAL: Release existing model BEFORE creating new one
    cubismModel?.let { oldModel ->
        Live2DLogger.Model.d("Releasing old model", oldModel.toString())
        oldModel.release()
    }
    cubismModel = null
    
    // Small delay to ensure GL resources are released
    // (Not strictly necessary but can help with edge cases)
    
    // Create new model
    val newModel = CubismModel(modelPath, modelName)
    if (newModel.load()) {
        cubismModel = newModel
        // ... success handling ...
    } else {
        newModel.release() // Clean up failed model
        // ... fallback handling ...
    }
}
```

**Memory Verification Protocol**:
```bash
# In terminal, run while testing:
adb shell dumpsys meminfo com.example.flutter_application_1 | grep -E "Native|TOTAL"

# Test sequence:
1. Load model A → Note memory
2. Load model B → Memory should be similar (slight variance OK)
3. Load model A → Memory should be similar
4. Repeat 10 times
5. Final memory should be within 10% of initial
```

**Common Pitfalls**:
- Forgetting to delete CubismMotion objects
- Not clearing motion map
- GL texture leak (forgetting glDeleteTextures)
- Creating new model before releasing old one

**Verification**:
```
✓ PASS: Load different models 10 times → No significant memory growth
✓ PASS: No "OutOfMemoryError" in logcat
✓ PASS: No texture ID accumulation (debug log shows recycling)
✗ FAIL: Memory grows linearly with each load, eventual crash
```

---

## SECTION 4 — CubismFramework Lifecycle Design

### 4.1 Lifecycle Diagram (Text-Based)

```
┌─────────────────────────────────────────────────────────────────────┐
│                        APP LIFECYCLE                                 │
├─────────────────────────────────────────────────────────────────────┤
│                                                                      │
│  App Start                                                          │
│      │                                                              │
│      ▼                                                              │
│  ┌──────────────────────────────────────────────────┐              │
│  │ MainActivity.onCreate()                          │              │
│  │   └─> Live2DPlugin attached                      │              │
│  │       └─> (No SDK init here!)                    │              │
│  └──────────────────────────────────────────────────┘              │
│      │                                                              │
│      ▼                                                              │
│  ┌──────────────────────────────────────────────────┐              │
│  │ User triggers: showOverlay()                     │              │
│  │   └─> Live2DOverlayService starts               │              │
│  │       └─> GLSurfaceView created                 │              │
│  └──────────────────────────────────────────────────┘              │
│      │                                                              │
│      ▼                                                              │
│  ╔══════════════════════════════════════════════════╗              │
│  ║ onSurfaceCreated() [GL Thread]                   ║              │
│  ║   └─> CubismFrameworkManager.initialize()  ◄───────── ONLY HERE │
│  ║       ├─> loadSdk() if not loaded               ║              │
│  ║       └─> CubismFramework.startUp()             ║              │
│  ║           CubismFramework.initialize()           ║              │
│  ╚══════════════════════════════════════════════════╝              │
│      │                                                              │
│      ▼                                                              │
│  ┌──────────────────────────────────────────────────┐              │
│  │ Normal Operation                                 │              │
│  │   └─> onDrawFrame() calls model.update/draw     │              │
│  │       loadModel() creates CubismModel instances │              │
│  └──────────────────────────────────────────────────┘              │
│      │                                                              │
│      │  [User hides overlay]                                       │
│      ▼                                                              │
│  ┌──────────────────────────────────────────────────┐              │
│  │ hideOverlay()                                    │              │
│  │   └─> GLSurfaceView.onPause()                   │              │
│  │       GLSurfaceView removed from window         │              │
│  │   └─> (Framework stays initialized!)            │              │
│  └──────────────────────────────────────────────────┘              │
│      │                                                              │
│      │  [User shows overlay again]                                 │
│      ▼                                                              │
│  ┌──────────────────────────────────────────────────┐              │
│  │ showOverlay() → New GLSurfaceView               │              │
│  │   └─> onSurfaceCreated()                        │              │
│  │       └─> initialize() returns immediately       │              │
│  │           (already initialized - no-op)          │              │
│  └──────────────────────────────────────────────────┘              │
│      │                                                              │
│      │  [App termination]                                          │
│      ▼                                                              │
│  ╔══════════════════════════════════════════════════╗              │
│  ║ Service.onDestroy() or App killed               ║              │
│  ║   └─> (Framework auto-cleanup by Android)        ║              │
│  ║       OR explicit dispose() if needed            ║              │
│  ╚══════════════════════════════════════════════════╝              │
│                                                                      │
└─────────────────────────────────────────────────────────────────────┘
```

### 4.2 Initialization Rules

| Rule | Explanation |
|------|-------------|
| **WHERE to call `initialize()`** | ONLY in `onSurfaceCreated()` on GL thread |
| **WHERE NOT to call `initialize()`** | Service.onCreate(), MainActivity.onCreate(), any non-GL thread |
| **How to prevent double init** | Singleton pattern with `isInitialized` flag + `@Synchronized` |
| **When to call `dispose()`** | App termination, or never (Android cleans up) |
| **How to handle surface recreation** | `initialize()` no-ops if already done |

### 4.3 Thread Safety Matrix

| Method | Thread | Safe to call multiple times? |
|--------|--------|------------------------------|
| `loadSdk()` | Any | Yes (no-op if loaded) |
| `initialize()` | GL only | Yes (no-op if initialized) |
| `isReady()` | Any | Yes |
| `dispose()` | GL only | Yes (no-op if not initialized) |

---

## SECTION 5 — Rendering Pipeline Replacement

### 5.1 Current Pipeline (Texture Preview)

```
onDrawFrame()
    │
    ├─> glClear()
    │
    ├─> Check currentModel exists?
    │       │
    │       ├─> YES: textureRenderer.render(mvp, transform)
    │       │         └─> Draws single quad with texture_00.png
    │       │
    │       └─> NO: placeholderShader.drawCircle()
    │
    └─> End frame
```

### 5.2 Target Pipeline (Cubism SDK)

```
onDrawFrame()
    │
    ├─> glClear()
    │
    ├─> Check cubismModel exists and isReady?
    │       │
    │       ├─> YES: 
    │       │     │
    │       │     ├─> model.update(deltaTime)
    │       │     │     ├─> motionManager.updateMotion()
    │       │     │     └─> model.getModel().update()
    │       │     │
    │       │     └─> model.draw(mvpMatrix)
    │       │           ├─> Apply transforms to modelMatrix
    │       │           ├─> Calculate final MVP
    │       │           └─> renderer.drawModel()
    │       │                 └─> SDK draws all mesh parts
    │       │
    │       └─> NO: Fall back to texture preview
    │             └─> textureRenderer.render() or placeholder
    │
    └─> End frame
```

### 5.3 MVP Matrix Handling

```kotlin
// Current projection setup (keep this)
override fun onSurfaceChanged(gl: GL10?, width: Int, height: Int) {
    GLES20.glViewport(0, 0, width, height)
    
    val ratio = width.toFloat() / height.toFloat()
    Matrix.orthoM(projectionMatrix, 0, -ratio, ratio, -1f, 1f, -1f, 1f)
    Matrix.setLookAtM(viewMatrix, 0, 0f, 0f, 1f, 0f, 0f, 0f, 0f, 1f, 0f)
    Matrix.multiplyMM(mvpMatrix, 0, projectionMatrix, 0, viewMatrix, 0)
}

// In CubismModel.draw():
fun draw(projectionMatrix: FloatArray) {
    model?.let { m ->
        // Cubism SDK uses its own matrix system
        val modelMatrix = m.modelMatrix
        modelMatrix.loadIdentity()
        
        // Apply user transforms
        modelMatrix.translate(posX, posY)
        modelMatrix.scale(scale, scale)
        
        // Combine with projection
        val mvp = FloatArray(16)
        Matrix.multiplyMM(mvp, 0, projectionMatrix, 0, modelMatrix.array, 0)
        
        // Pass to SDK renderer
        m.renderer.setMvpMatrix(mvp)
        m.renderer.drawModel()
    }
}
```

### 5.4 OpenGL ES Version Decision

| Factor | Decision |
|--------|----------|
| **SDK Requirement** | Cubism SDK for Native supports ES 2.0+ |
| **Current Setup** | Already using ES 2.0 |
| **Recommendation** | Stay with ES 2.0 for maximum compatibility |
| **If ES 3.0 needed** | Change `setEGLContextClientVersion(3)` in GLSurfaceView |

### 5.5 Blend Mode Preservation

```kotlin
// In onSurfaceCreated - BEFORE SDK init:
GLES20.glEnable(GLES20.GL_BLEND)
GLES20.glBlendFunc(GLES20.GL_SRC_ALPHA, GLES20.GL_ONE_MINUS_SRC_ALPHA)

// After SDK draws, it may change blend state
// Reset if needed for custom rendering after model:
fun resetBlendState() {
    GLES20.glEnable(GLES20.GL_BLEND)
    GLES20.glBlendFunc(GLES20.GL_SRC_ALPHA, GLES20.GL_ONE_MINUS_SRC_ALPHA)
}
```

---

## SECTION 6 — Motion Playback (Minimal)

### 6.1 Motion Discovery from model3.json

```json
// Example model3.json structure
{
  "FileReferences": {
    "Motions": {
      "Idle": [
        { "File": "motions/idle_00.motion3.json", "FadeInTime": 0.5, "FadeOutTime": 0.5 },
        { "File": "motions/idle_01.motion3.json" }
      ],
      "TapBody": [
        { "File": "motions/tap_body_00.motion3.json" }
      ]
    }
  }
}
```

```kotlin
// Model3JsonParser already handles this:
val motionGroups: Map<String, List<MotionInfo>>
// motionGroups["Idle"] -> List<MotionInfo>
// motionGroups["Idle"][0].file -> "motions/idle_00.motion3.json"
```

### 6.2 Loading ONE Idle Motion

```kotlin
// In CubismModel, after successful model load:
fun autoStartIdleMotion() {
    val idleGroups = listOf("Idle", "idle", "IDLE", "待機", "idle_00")
    
    for (groupName in idleGroups) {
        if (playMotion(groupName, 0, PRIORITY_IDLE)) {
            Live2DLogger.Model.d("CubismModel", "Auto-started idle: $groupName")
            return
        }
    }
    
    // If no idle found, try first motion of any group
    parser.motionGroups.keys.firstOrNull()?.let { firstGroup ->
        playMotion(firstGroup, 0, PRIORITY_IDLE)
    }
}

companion object {
    const val PRIORITY_NONE = 0
    const val PRIORITY_IDLE = 1
    const val PRIORITY_NORMAL = 2
    const val PRIORITY_FORCE = 3
}
```

### 6.3 Priority Handling (Simplified)

```kotlin
// CubismMotionManager handles priority internally
// Higher priority interrupts lower priority

fun playMotion(group: String, index: Int, priority: Int): Boolean {
    // Don't interrupt higher priority motions
    val currentPriority = motionManager?.getCurrentPriority() ?: 0
    if (priority < currentPriority) {
        return false // Reject lower priority
    }
    
    val motion = loadMotionFromGroup(group, index) ?: return false
    motionManager?.startMotionPriority(motion, priority)
    return true
}
```

### 6.4 Update Loop Timing

```kotlin
// CRITICAL: deltaTime must be SECONDS, not milliseconds

override fun onDrawFrame(gl: GL10?) {
    val currentTime = System.currentTimeMillis()
    val elapsedMs = currentTime - lastFrameTime
    lastFrameTime = currentTime
    
    // Convert to seconds for SDK
    val deltaSeconds = elapsedMs / 1000f
    
    // Clamp to reasonable range (prevent huge jumps on resume)
    val safeDelta = deltaSeconds.coerceIn(0.001f, 0.1f)
    
    cubismModel?.update(safeDelta)
}
```

---

## SECTION 7 — Debug & Logging Checklist

### 7.1 Mandatory Log Points

| Stage | Log Call | Purpose |
|-------|----------|---------|
| SDK Load | `"Native library loaded"` or error | Verify .so files found |
| Framework Init | `"CubismFramework Initialized - Version: X"` | Confirm SDK started |
| Model Load Start | `"Loading model: [name]"` | Track load attempts |
| moc3 Load | `"moc3 loaded: [path]"` | Confirm moc3 found |
| Texture Load | `"Texture [N] loaded: ID=[X]"` | Track each texture |
| Model Load Complete | `"Model ready: [name]"` | Confirm ready state |
| Motion Load | `"Motion loaded: [group]:[index]"` | Track motion loading |
| Motion Start | `"Playing motion: [group]:[index]"` | Track motion playback |
| Model Release | `"Model released: [name]"` | Confirm cleanup |
| GL Error | `"GL Error: [code] at [location]"` | Catch rendering issues |

### 7.2 GL Error Check Pattern

```kotlin
private fun checkGLError(location: String) {
    var error: Int
    var hasError = false
    while (GLES20.glGetError().also { error = it } != GLES20.GL_NO_ERROR) {
        hasError = true
        val errorStr = when (error) {
            GLES20.GL_INVALID_ENUM -> "GL_INVALID_ENUM"
            GLES20.GL_INVALID_VALUE -> "GL_INVALID_VALUE"
            GLES20.GL_INVALID_OPERATION -> "GL_INVALID_OPERATION"
            GLES20.GL_OUT_OF_MEMORY -> "GL_OUT_OF_MEMORY"
            else -> "Unknown ($error)"
        }
        Live2DLogger.GL.e("GL Error", "$location: $errorStr")
    }
    if (!hasError) {
        // Optional: Log success for critical operations
        // Live2DLogger.GL.d("GL OK", location)
    }
}

// Usage - add after critical GL operations:
checkGLError("onSurfaceCreated")
checkGLError("textureLoad")
checkGLError("afterDraw")
```

### 7.3 Typical Crash Causes & Identification

| Crash Symptom | Likely Cause | How to Identify |
|---------------|--------------|-----------------|
| `UnsatisfiedLinkError` | Missing .so file | Check jniLibs folder has correct ABI |
| `SIGSEGV` on init | Double initialization | Check for "Already initialized" log |
| `SIGSEGV` on draw | NULL model or invalid GL context | Add null checks, verify surface exists |
| Black screen | Draw not called or wrong blend mode | Add log in onDrawFrame, check blend |
| Pink/magenta squares | Missing textures | Check texture load logs |
| Frozen animation | deltaTime issue | Log deltaTime value each frame |
| Memory crash | Leak on reload | Monitor with `adb shell dumpsys meminfo` |
| `GL_INVALID_OPERATION` | Wrong GL state or thread | Check all GL calls are on GL thread |

### 7.4 Debug Build Configuration

Add to `android/app/build.gradle.kts`:
```kotlin
android {
    buildTypes {
        debug {
            // Enable native debugging
            isDebuggable = true
            isJniDebuggable = true
        }
    }
}
```

---

## SECTION 8 — Phase 7 Exit Checklist

Before declaring Phase 7 complete, verify ALL items:

### 8.1 Functional Checks

| # | Check | How to Verify | Pass? |
|---|-------|---------------|-------|
| F1 | SDK loads without crash | App starts, no crash in logcat | ☐ |
| F2 | Model loads (moc3 + textures) | Log shows "Model ready" | ☐ |
| F3 | Model renders with mesh | Visual: see proper character, not flat image | ☐ |
| F4 | Idle motion plays | Visual: character moves/breathes | ☐ |
| F5 | Idle motion loops | Watch for 1+ minute, animation continues | ☐ |
| F6 | Transparent background | Overlay shows only character, no black box | ☐ |

### 8.2 Lifecycle Checks

| # | Check | How to Verify | Pass? |
|---|-------|---------------|-------|
| L1 | Hide overlay works | Tap hide → overlay disappears | ☐ |
| L2 | Show after hide works | Hide → Show → model appears | ☐ |
| L3 | Model state preserved | Hide → Show → same model loads | ☐ |
| L4 | 5x hide/show cycle | Repeat 5 times, no crash | ☐ |
| L5 | Service restart works | Force stop app → Relaunch → Show overlay | ☐ |
| L6 | Surface recreation | If possible: rotate → no crash | ☐ |

### 8.3 Performance & Stability Checks

| # | Check | How to Verify | Pass? |
|---|-------|---------------|-------|
| P1 | No GL errors | `adb logcat | grep "GL Error"` shows nothing | ☐ |
| P2 | Reasonable FPS | Visual smoothness, or FPS counter ~30-60 | ☐ |
| P3 | No memory leak | Load model 10x, memory stable (±10%) | ☐ |
| P4 | Different model loads | Load Model A, then Model B, both work | ☐ |
| P5 | 10min stability | Leave running 10min, no crash | ☐ |

### 8.4 Final Approval Gate

```
All F checks passed:  ☐ YES  /  ☐ NO
All L checks passed:  ☐ YES  /  ☐ NO
All P checks passed:  ☐ YES  /  ☐ NO

─────────────────────────────────
PHASE 7 COMPLETE:    ☐ YES  /  ☐ NO
─────────────────────────────────

If NO: Document failing checks and blockers
If YES: Proceed to Phase 8
```

---

## Appendix A: SDK Class Reference (Cubism SDK for Native)

> Note: Exact class names may vary by SDK version. Verify against downloaded SDK.

| Class | Purpose |
|-------|---------|
| `CubismFramework` | Static framework lifecycle |
| `ICubismAllocator` | Memory allocation interface |
| `CubismUserModel` | Model container |
| `CubismModel` | Core model data |
| `CubismModelMatrix` | Model transform matrix |
| `CubismRenderer_OpenGLES2` | OpenGL ES 2.0 renderer |
| `CubismMotion` | Motion clip |
| `CubismMotionManager` | Motion playback manager |
| `CubismModelSettingJson` | model3.json parser |

---

## Appendix B: Quick Command Reference

```powershell
# Check if .so files are in APK
cd android
.\gradlew assembleDebug
# Then extract APK and check lib/ folder

# Monitor memory
adb shell dumpsys meminfo com.example.flutter_application_1

# Filter Live2D logs
adb logcat | Select-String "Live2D|Cubism|GL Error"

# Clear and watch logs
adb logcat -c; adb logcat | Select-String "Live2D"
```

---

**END OF PHASE 7 EXECUTION PLAN**
