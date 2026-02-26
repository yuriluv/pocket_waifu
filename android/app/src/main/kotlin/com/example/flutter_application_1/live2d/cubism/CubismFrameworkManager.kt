package com.example.flutter_application_1.live2d.cubism

import com.example.flutter_application_1.live2d.core.Live2DLogger

/**
 * Cubism SDK Framework Manager (Singleton)
 * 
 * 
 * CRITICAL RULES:
 * 
 * 
 * State Diagram:
 * ```
 * [NOT_INITIALIZED] -> loadSdk() -> [SDK_LOADED] or [FALLBACK]
 *                   -> initialize() -> [FRAMEWORK_READY] or [FALLBACK]
 * ```
 * 
 * Phase 7-1 Checklist:
 * 1. Place libLive2DCubismCore.so in:
 *    android/app/src/main/jniLibs/
 *      ├── arm64-v8a/libLive2DCubismCore.so
 *      ├── armeabi-v7a/libLive2DCubismCore.so
 *      └── x86_64/libLive2DCubismCore.so
 * 2. Run flutter run
 * 3. Look for log: "[Phase7-1] Live2D Cubism SDK native library loaded successfully."
 * 
 */
object CubismFrameworkManager {
    
    private const val TAG = "CubismFramework"
    private const val NATIVE_LIB_NAME = "Live2DCubismCore"
    
    // ========================================================================
    // State Flags - WHY these exist:
    // 
    // ========================================================================
    
    // 1. Native library loaded via System.loadLibrary() 
    @Volatile
    private var isSdkLoaded = false
    
    // 2. CubismFramework.initialize() completed successfully
    @Volatile
    private var isFrameworkInitialized = false
    
    // 3. Running in fallback mode (texture-only rendering)
    @Volatile
    private var isFallbackMode = true
    
    // 4. initialization attempted (prevents repeated attempts)
    @Volatile
    private var isInitialized = false
    
    // 5. Error message if initialization failed
    @Volatile
    private var lastError: String? = null
    
    private val allocator = CubismAllocator()
    
    private var sdkVersion: String = "Not initialized"
    
    /**
     * 
     * Thread-safe via @Synchronized
     * 
     */
    @Synchronized
    fun loadSdk(): Boolean {
        if (isSdkLoaded) {
            Live2DLogger.d("$TAG: SDK already loaded", null)
            return true
        }
        
        Live2DLogger.d("$TAG: Attempting to load native library", "lib$NATIVE_LIB_NAME.so")
        
        return try {
            System.loadLibrary(NATIVE_LIB_NAME)
            isSdkLoaded = true
            lastError = null
            
            // Phase 7-1 Success Log - This is the key verification point
            Live2DLogger.i("$TAG: ✓ Native library loaded", "lib$NATIVE_LIB_NAME.so")
            Live2DLogger.i("$TAG: [Phase7-1] Live2D Cubism SDK native library loaded successfully.", null)
            Live2DLogger.i("$TAG: [Phase7-1] SDK is loadable and detectable at runtime.", null)
            true
        } catch (e: UnsatisfiedLinkError) {
            val errorMsg = "lib$NATIVE_LIB_NAME.so not found: ${e.message}"
            lastError = errorMsg
            Live2DLogger.w("$TAG: ✗ Native library not found", "lib$NATIVE_LIB_NAME.so")
            Live2DLogger.w("$TAG: [Phase7-1] SDK native library NOT present - cannot render Live2D models.", null)
            Live2DLogger.i("$TAG: Running in FALLBACK MODE", "Texture preview only")
            Live2DLogger.i("$TAG: To enable SDK", "Place .so files in jniLibs/{abi}/")
            false
        } catch (e: SecurityException) {
            lastError = "Security exception: ${e.message}"
            Live2DLogger.e("$TAG: ✗ Security exception", e)
            Live2DLogger.w("$TAG: [Phase7-1] SDK load FAILED due to security exception.", null)
            false
        } catch (e: Exception) {
            lastError = "Unexpected error: ${e.message}"
            Live2DLogger.e("$TAG: ✗ Unexpected error loading SDK", e)
            Live2DLogger.w("$TAG: [Phase7-1] SDK load FAILED due to unexpected error.", null)
            false
        }
    }
    
    /**
     * 
     * 
     * 
     */
    // Context used for AssetManager access
    @Volatile
    private var appContext: android.content.Context? = null

    @Synchronized
    fun initialize(context: android.content.Context? = null): Boolean {
        if (context != null) {
            appContext = context.applicationContext
        }
        if (isInitialized) {
            Live2DLogger.d("$TAG: Already initialized", getStatusSummary())
            return true
        }
        
        Live2DLogger.d("$TAG: Starting initialization", null)
        
        val sdkLoadResult = if (!isSdkLoaded) {
            loadSdk()
        } else {
            true
        }
        
        if (sdkLoadResult && isSdkLoaded) {
            try {
                val frameworkResult = initializeSdkFramework()
                if (frameworkResult) {
                    isFrameworkInitialized = true
                    isFallbackMode = false
                    Live2DLogger.i("$TAG: ✓ SDK mode activated", sdkVersion)
                } else {
                    isFallbackMode = true
                    Live2DLogger.w("$TAG: Framework init failed", "switching to fallback")
                }
            } catch (e: Exception) {
                lastError = "Framework init exception: ${e.message}"
                isFallbackMode = true
                Live2DLogger.e("$TAG: Framework init exception", e)
            }
        } else {
            isFallbackMode = true
        }
        
        isInitialized = true
        
        if (isFallbackMode) {
            sdkVersion = "Fallback Mode (Texture Preview)"
            Live2DLogger.i("$TAG: ✓ Initialized in FALLBACK mode", lastError ?: "SDK not installed")
        }
        
        Live2DLogger.i("$TAG: Init complete", getStatusSummary())
        
        return true  // Always succeed - fallback is a valid state
    }
    
    /**
     * 
     */
    private fun initializeSdkFramework(): Boolean {
        return try {
            Live2DLogger.i("$TAG: [Phase7-2] Starting Cubism Framework initialization (JNI)", null)

            if (!Live2DNativeBridge.ensureLoaded()) {
                lastError = "JNI library load failed"
                return false
            }

            // Pass AssetManager to native before framework init (for shader file loading)
            val ctx = appContext
            if (ctx == null) {
                lastError = "AppContext not set — cannot load shaders"
                Live2DLogger.e("$TAG: [Phase7-2] AppContext is null, shader loading will fail", null)
                return false
            }
            Live2DNativeBridge.nativeSetAssetManager(ctx.assets)
            Live2DLogger.d("$TAG: [Phase7-2] AssetManager passed to native", null)

            val initResult = Live2DNativeBridge.nativeInitializeFramework()
            if (!initResult) {
                lastError = "Native framework init failed"
                Live2DLogger.w("$TAG: [Phase7-2] Native framework init failed", null)
                return false
            }

            val version = Live2DNativeBridge.nativeGetVersion()
            val major = (version shr 24) and 0xFF
            val minor = (version shr 16) and 0xFF
            val patch = version and 0xFFFF
            sdkVersion = "Cubism SDK $major.$minor.$patch"

            Live2DLogger.i("$TAG: [Phase7-2] Cubism framework initialized", sdkVersion)
            Live2DLogger.i("$TAG: SDK Version", sdkVersion)

            Live2DLogger.i("$TAG: [Phase7-2] Shader loading verification:", 
                "AssetManager set=true, Framework init=true")

            true

        } catch (e: Exception) {
            Live2DLogger.e("$TAG: [Phase7-2] Framework init exception", e)
            lastError = "Framework init failed: ${e.message}"
            false
        }
    }
    
    /**
     */
    fun isReady(): Boolean = isInitialized
    
    /**
     * 
     * Returns true ONLY if:
     * 1. Native .so is present and loadable
     * 2. Framework initialization has NOT yet been executed
     *    OR Framework is already initialized successfully
     * 
     * This method is the primary Phase 7-1 verification point.
     * If this returns true, the SDK is correctly installed.
     * 
     */
    fun isSdkAvailable(): Boolean {
        // If already loaded, we know it's available
        if (isSdkLoaded) {
            return true
        }
        
        // If not yet loaded, try to load now (this is safe to call multiple times)
        // This allows checking availability without explicit initialization
        return loadSdk()
    }
    
    /**
     * 
     * True only when:
     * 1. Native .so loaded
     * 2. CubismFramework initialized
     * 3. Not in fallback mode
     * 
     * Use this to check if actual moc3 rendering is possible.
     * 
     */
    fun isSdkRenderingReady(): Boolean = isSdkLoaded && isFrameworkInitialized && !isFallbackMode
    
    /**
     * 
     * True when SDK rendering is NOT available (use texture preview instead)
     */
    fun isFallbackModeActive(): Boolean = isFallbackMode
    
    /**
     */
    fun isSdkLibraryLoaded(): Boolean = isSdkLoaded
    
    /**
     * Phase 7-1 Runtime Verification Hook
     * 
     * Safely checks if the Live2D Cubism SDK native library is present and loadable.
     * This method will:
     * - NOT crash even if SDK is missing
     * - Attempt to load the native library if not already loaded
     * - Log clear success/failure messages
     * 
     * Call this method after flutter run to verify Phase 7-1 installation.
     * 
     * @return true if SDK is correctly installed and loadable
     */
    fun checkSdkLoadStatus(): Boolean {
        Live2DLogger.i("$TAG: ========================================", null)
        Live2DLogger.i("$TAG: Phase 7-1 SDK Load Status Check", null)
        Live2DLogger.i("$TAG: ========================================", null)
        
        return try {
            val result = if (isSdkLoaded) {
                // Already loaded successfully
                Live2DLogger.i("$TAG: [Phase7-1] SUCCESS - SDK already loaded.", null)
                true
            } else {
                // Attempt to load
                val loadResult = loadSdk()
                if (loadResult) {
                    Live2DLogger.i("$TAG: [Phase7-1] SUCCESS - SDK loaded on verification.", null)
                } else {
                    Live2DLogger.w("$TAG: [Phase7-1] FAILED - SDK could not be loaded.", null)
                    Live2DLogger.i("$TAG: [Phase7-1] Expected location:", null)
                    Live2DLogger.i("$TAG:   android/app/src/main/jniLibs/arm64-v8a/libLive2DCubismCore.so", null)
                    Live2DLogger.i("$TAG:   android/app/src/main/jniLibs/armeabi-v7a/libLive2DCubismCore.so", null)
                    Live2DLogger.i("$TAG:   android/app/src/main/jniLibs/x86_64/libLive2DCubismCore.so", null)
                }
                loadResult
            }
            
            // Summary
            Live2DLogger.i("$TAG: ----------------------------------------", null)
            Live2DLogger.i("$TAG: Phase 7-1 Result: ${if (result) "PASSED ✓" else "FAILED ✗"}", null)
            Live2DLogger.i("$TAG: SDK Loaded: $isSdkLoaded", null)
            Live2DLogger.i("$TAG: Framework Initialized: $isFrameworkInitialized", null)
            Live2DLogger.i("$TAG: Fallback Mode: $isFallbackMode", null)
            lastError?.let { Live2DLogger.i("$TAG: Last Error: $it", null) }
            Live2DLogger.i("$TAG: ========================================", null)
            
            result
        } catch (e: Exception) {
            Live2DLogger.e("$TAG: [Phase7-1] Unexpected error during verification", e)
            Live2DLogger.i("$TAG: Phase 7-1 Result: FAILED ✗ (exception)", null)
            Live2DLogger.i("$TAG: ========================================", null)
            false
        }
    }
    
    /**
     */
    fun getLastError(): String? = lastError
    
    /**
     * 
     */
    @Synchronized
    fun dispose() {
        if (!isInitialized) {
            Live2DLogger.d("$TAG: Not initialized", "nothing to dispose")
            return
        }
        
        try {
            if (isFrameworkInitialized && !isFallbackMode) {
                Live2DLogger.d("$TAG: [Phase7-2] Disposing CubismFramework (JNI)", null)
                Live2DNativeBridge.nativeDisposeFramework()
                Live2DLogger.d("$TAG: [Phase7-2] CubismFramework disposed", null)
            }
            
            isFrameworkInitialized = false
            isInitialized = false
            
            Live2DLogger.i("$TAG: ✓ Framework disposed", null)
            
        } catch (e: Exception) {
            Live2DLogger.e("$TAG: ✗ Framework dispose failed", e)
        }
    }
    
    /**
     */
    fun getVersionString(): String = sdkVersion
    
    /**
     */
    fun getStatusInfo(): Map<String, Any?> {
        return mapOf(
            "sdkLoaded" to isSdkLoaded,
            "frameworkInitialized" to isFrameworkInitialized,
            "initialized" to isInitialized,
            "fallbackMode" to isFallbackMode,
            "version" to sdkVersion,
            "lastError" to lastError,
            "mode" to when {
                !isInitialized -> "Not initialized"
                isFallbackMode -> "Fallback (Texture Preview)"
                isSdkLoaded && isFrameworkInitialized -> "Native SDK (Full Live2D)"
                isSdkLoaded -> "SDK Loaded (Framework pending)"
                else -> "Unknown"
            }
        )
    }
    
    /**
     */
    fun getStatusSummary(): String {
        return buildString {
            append("CubismSDK: ")
            when {
                !isInitialized -> append("NOT_INIT")
                isFallbackMode -> append("FALLBACK")
                isFrameworkInitialized -> append("SDK_READY")
                isSdkLoaded -> append("SDK_LOADED")
                else -> append("UNKNOWN")
            }
            if (lastError != null) {
                append(" [err]")
            }
        }
    }
    
    /**
     * 
     */
    @Synchronized
    fun reinitialize(): Boolean {
        if (!isSdkLoaded) {
            Live2DLogger.w("$TAG: Cannot reinitialize - SDK not loaded", null)
            return false
        }
        
        isFrameworkInitialized = false
        isInitialized = false
        isFallbackMode = true  // Reset until proven otherwise
        
        return initialize()
    }
}
