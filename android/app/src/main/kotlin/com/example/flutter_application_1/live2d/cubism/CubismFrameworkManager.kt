package com.example.flutter_application_1.live2d.cubism

import com.example.flutter_application_1.live2d.core.Live2DLogger

/**
 * Cubism SDK Framework Manager (Singleton)
 * 
 * Live2D Cubism SDK의 초기화 및 생명주기를 관리합니다.
 * 
 * CRITICAL RULES:
 * - initialize()는 GL 스레드에서만 호출
 * - initialize()는 프로세스 생명주기 동안 한 번만 호출
 * - dispose()는 앱 종료 시 호출 (선택적)
 * 
 * SDK가 설치되지 않은 경우 폴백 모드로 동작합니다.
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
 * Phase 7 완성 상태:
 * - SDK .so 파일 설치 필요: jniLibs/{abi}/libLive2DCubismCore.so
 * - SDK 설치 후 TODO 주석 해제하여 활성화
 */
object CubismFrameworkManager {
    
    private const val TAG = "CubismFramework"
    private const val NATIVE_LIB_NAME = "Live2DCubismCore"
    
    // ========================================================================
    // State Flags - WHY these exist:
    // 
    // SDK 초기화는 여러 단계로 이루어지며, 각 단계가 독립적으로 실패할 수 있습니다.
    // 이 플래그들은 정확히 어느 단계까지 성공했는지 추적하여:
    // 1. 부분 초기화 상태에서도 적절한 폴백이 가능하고
    // 2. 재초기화 시 어느 단계부터 다시 시작할지 결정할 수 있게 합니다.
    // ========================================================================
    
    // 1. Native library loaded via System.loadLibrary() 
    @Volatile
    private var isSdkLoaded = false
    
    // 2. CubismFramework.initialize() completed successfully
    @Volatile
    private var isFrameworkInitialized = false
    
    // 3. Running in fallback mode (texture-only rendering)
    // WHY default to true: 방어적 설계 원칙. SDK가 없어도 앱이 작동해야 합니다.
    // SDK 로드가 성공한 후에만 false로 변경됩니다. 실패 시 텍스처 프리뷰로 폴백합니다.
    @Volatile
    private var isFallbackMode = true
    
    // 4. initialization attempted (prevents repeated attempts)
    @Volatile
    private var isInitialized = false
    
    // 5. Error message if initialization failed
    @Volatile
    private var lastError: String? = null
    
    // 메모리 할당자 (SDK용)
    private val allocator = CubismAllocator()
    
    // SDK 버전 (로드 후 설정)
    private var sdkVersion: String = "Not initialized"
    
    /**
     * 네이티브 라이브러리 로드
     * 
     * 어떤 스레드에서든 호출 가능하지만, 한 번만 실행됨
     * Thread-safe via @Synchronized
     * 
     * @return SDK 로드 성공 여부
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
     * Cubism Framework 초기화
     * 
     * MUST: GL 스레드에서만 호출할 것
     * MUST: 프로세스 생명주기 동안 한 번만 호출할 것
     * 
     * SDK가 없어도 초기화는 "성공"으로 처리됩니다 (폴백 모드).
     * 이는 앱이 SDK 없이도 작동하도록 보장합니다.
     * 
     * @return 초기화 완료 여부 (폴백 모드 포함, 항상 true)
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
        
        // 1. SDK 로드 시도
        val sdkLoadResult = if (!isSdkLoaded) {
            loadSdk()
        } else {
            true
        }
        
        // 2. SDK가 로드되었으면 Framework 초기화 시도
        if (sdkLoadResult && isSdkLoaded) {
            try {
                val frameworkResult = initializeSdkFramework()
                if (frameworkResult) {
                    isFrameworkInitialized = true
                    isFallbackMode = false
                    Live2DLogger.i("$TAG: ✓ SDK mode activated", sdkVersion)
                } else {
                    // Framework 초기화 실패 → 폴백
                    isFallbackMode = true
                    Live2DLogger.w("$TAG: Framework init failed", "switching to fallback")
                }
            } catch (e: Exception) {
                lastError = "Framework init exception: ${e.message}"
                isFallbackMode = true
                Live2DLogger.e("$TAG: Framework init exception", e)
            }
        } else {
            // SDK 로드 실패 → 폴백 확정
            isFallbackMode = true
        }
        
        // 3. 상태 확정
        isInitialized = true
        
        if (isFallbackMode) {
            sdkVersion = "Fallback Mode (Texture Preview)"
            Live2DLogger.i("$TAG: ✓ Initialized in FALLBACK mode", lastError ?: "SDK not installed")
        }
        
        // 상태 요약 로그
        Live2DLogger.i("$TAG: Init complete", getStatusSummary())
        
        return true  // Always succeed - fallback is a valid state
    }
    
    /**
     * SDK Framework 실제 초기화
     * 
     * Phase 7-2: JNI 브릿지를 통해 Native Framework 초기화
     */
    private fun initializeSdkFramework(): Boolean {
        return try {
            Live2DLogger.i("$TAG: [Phase7-2] Starting Cubism Framework initialization (JNI)", null)

            if (!Live2DNativeBridge.ensureLoaded()) {
                lastError = "JNI library load failed"
                return false
            }

            // Pass AssetManager to native before framework init (for shader file loading)
            // CRITICAL: AssetManager가 없으면 셰이더 로딩이 실패합니다.
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

            // 셰이더 로딩 검증
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
     * 전체 초기화 상태 확인
     */
    fun isReady(): Boolean = isInitialized
    
    /**
     * SDK 가용성 확인 (Phase 7-1 Definition)
     * 
     * Returns true ONLY if:
     * 1. Native .so is present and loadable
     * 2. Framework initialization has NOT yet been executed
     *    OR Framework is already initialized successfully
     * 
     * This method is the primary Phase 7-1 verification point.
     * If this returns true, the SDK is correctly installed.
     * 
     * @return SDK native library가 로드 가능하면 true
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
     * SDK Rendering 가능 여부 (Framework 초기화 완료 필요)
     * 
     * True only when:
     * 1. Native .so loaded
     * 2. CubismFramework initialized
     * 3. Not in fallback mode
     * 
     * Use this to check if actual moc3 rendering is possible.
     * 
     * @return SDK가 로드되고 Framework가 초기화되었으면 true
     */
    fun isSdkRenderingReady(): Boolean = isSdkLoaded && isFrameworkInitialized && !isFallbackMode
    
    /**
     * 폴백 모드 여부
     * 
     * True when SDK rendering is NOT available (use texture preview instead)
     */
    fun isFallbackModeActive(): Boolean = isFallbackMode
    
    /**
     * SDK .so 로드 여부 (Framework 초기화와 별개)
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
     * 마지막 오류 메시지
     */
    fun getLastError(): String? = lastError
    
    /**
     * Framework 정리
     * 
     * MUST: GL 스레드에서만 호출할 것
     * 앱 종료 시 호출 (Android는 보통 자동 정리)
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
            // isSdkLoaded는 유지 (라이브러리는 프로세스 종료까지 로드 상태)
            
            Live2DLogger.i("$TAG: ✓ Framework disposed", null)
            
        } catch (e: Exception) {
            Live2DLogger.e("$TAG: ✗ Framework dispose failed", e)
        }
    }
    
    /**
     * SDK 버전 문자열 반환
     */
    fun getVersionString(): String = sdkVersion
    
    /**
     * 상태 정보 반환 (디버깅용)
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
     * 상태 요약 문자열 (로깅용)
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
     * 재초기화 (Surface 재생성 시 사용)
     * 
     * Note: GL context가 새로 생성된 경우에만 호출
     * Native library는 다시 로드할 필요 없음
     */
    @Synchronized
    fun reinitialize(): Boolean {
        if (!isSdkLoaded) {
            Live2DLogger.w("$TAG: Cannot reinitialize - SDK not loaded", null)
            return false
        }
        
        // Framework 초기화만 다시 수행
        isFrameworkInitialized = false
        isInitialized = false
        isFallbackMode = true  // Reset until proven otherwise
        
        return initialize()
    }
}
