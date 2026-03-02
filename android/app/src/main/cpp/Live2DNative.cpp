#include <jni.h>
#include <android/log.h>
#include <android/asset_manager.h>
#include <android/asset_manager_jni.h>
#include <vector>
#include <string>
#include <fstream>
#include <mutex>
#include <cstdlib>
#include <cstring>

// NOTE: Do NOT include "Live2DCubismCore.h" directly.
// CubismFramework.hpp includes "Live2DCubismCore.hpp" which wraps the C header
// inside namespace Live2D::Cubism::Core. Including the raw C header first would
// put types in the global namespace and block the namespace wrapper via #pragma once.
#include "CubismFramework.hpp"
#include "Id/CubismId.hpp"
#include "Model/CubismMoc.hpp"
#include "Model/CubismModel.hpp"
#include "Math/CubismMatrix44.hpp"
#include "Rendering/CubismRenderer.hpp"
#include "Rendering/OpenGL/CubismRenderer_OpenGLES2.hpp"

using namespace Live2D::Cubism::Framework;
using namespace Live2D::Cubism::Framework::Rendering;

namespace {
    const char* kTag = "Live2DNative";

    std::mutex gMutex;
    ICubismAllocator* gAllocator = nullptr;
    bool gFrameworkInitialized = false;

    // AssetManager for loading shader files from APK assets
    AAssetManager* gAssetManager = nullptr;

    // IMPORTANT: CubismFramework stores Option as a POINTER (not copy).
    // This must be global so it outlives nativeInitializeFramework().
    CubismFramework::Option gOption;

    CubismMoc* gMoc = nullptr;
    CubismModel* gModel = nullptr;
    CubismRenderer* gRenderer = nullptr;
    CubismRenderer_OpenGLES2* gRendererGL = nullptr;

    class SimpleAllocator : public ICubismAllocator {
    public:
        void* Allocate(csmSizeType size) override {
            return std::malloc(size);
        }
        void Deallocate(void* memory) override {
            std::free(memory);
        }
        void* AllocateAligned(csmSizeType size, csmUint32 alignment) override {
            void* aligned = nullptr;
            if (posix_memalign(&aligned, alignment, size) != 0) {
                return nullptr;
            }
            return aligned;
        }
        void DeallocateAligned(void* alignedMemory) override {
            std::free(alignedMemory);
        }
    };

    // ================================================================
    // File loader via Android AssetManager
    // Cubism SDK calls this to load shader .frag/.vert files.
    // It tries multiple asset paths to find the shader file.
    // ================================================================
    csmByte* LoadFileFromAssets(const std::string filePath, csmSizeInt* outSize) {
        if (!gAssetManager) {
            __android_log_print(ANDROID_LOG_ERROR, kTag,
                "LoadFileFromAssets: AssetManager not set! path=%s", filePath.c_str());
            return nullptr;
        }

        // Try multiple prefixes — SDK may request with bare filename or relative path
        const std::string prefixes[] = {
            "Live2DShaders/StandardES/",
            "Live2DShaders/",
            ""
        };

        for (const auto& prefix : prefixes) {
            std::string assetPath = prefix + filePath;
            AAsset* asset = AAssetManager_open(gAssetManager, assetPath.c_str(), AASSET_MODE_BUFFER);
            if (asset) {
                off_t length = AAsset_getLength(asset);
                if (length > 0) {
                    auto* buffer = static_cast<csmByte*>(std::malloc(static_cast<size_t>(length)));
                    if (buffer) {
                        int bytesRead = AAsset_read(asset, buffer, static_cast<size_t>(length));
                        AAsset_close(asset);
                        if (bytesRead == length) {
                            *outSize = static_cast<csmSizeInt>(length);
                            __android_log_print(ANDROID_LOG_DEBUG, kTag,
                                "LoadFileFromAssets OK: %s (%ld bytes)", assetPath.c_str(), (long)length);
                            return buffer;
                        }
                        std::free(buffer);
                    } else {
                        AAsset_close(asset);
                    }
                } else {
                    AAsset_close(asset);
                }
            }
        }

        __android_log_print(ANDROID_LOG_WARN, kTag,
            "LoadFileFromAssets FAILED: %s (tried all prefixes)", filePath.c_str());
        return nullptr;
    }

    void ReleaseBytes(csmByte* byteData) {
        std::free(byteData);
    }

    // SDK logging callback
    void CubismLogFunction(const char* message) {
        __android_log_print(ANDROID_LOG_INFO, kTag, "%s", message);
    }

    void ReleaseModelResources() {
        if (gRenderer) {
            CubismRenderer::Delete(gRenderer);
            gRenderer = nullptr;
            gRendererGL = nullptr;
        }
        if (gMoc && gModel) {
            gMoc->DeleteModel(gModel);
            gModel = nullptr;
        }
        if (gMoc) {
            CubismMoc::Delete(gMoc);
            gMoc = nullptr;
        }
    }

    bool ReadFileAllBytes(const std::string& path, std::vector<csmByte>& outBytes) {
        std::ifstream file(path, std::ios::binary);
        if (!file.is_open()) {
            return false;
        }
        file.seekg(0, std::ios::end);
        const std::streamsize size = file.tellg();
        if (size <= 0) {
            return false;
        }
        file.seekg(0, std::ios::beg);
        outBytes.resize(static_cast<size_t>(size));
        file.read(reinterpret_cast<char*>(outBytes.data()), size);
        return file.good();
    }
}

// ================================================================
// Set Android AssetManager for shader file loading
// MUST be called before nativeInitializeFramework()
// ================================================================
extern "C" JNIEXPORT void JNICALL
Java_com_example_flutter_1application_11_live2d_cubism_Live2DNativeBridge_nativeSetAssetManager(
    JNIEnv* env, jobject, jobject assetManager) {
    gAssetManager = AAssetManager_fromJava(env, assetManager);
    __android_log_print(ANDROID_LOG_INFO, kTag, "AssetManager set");
}

extern "C" JNIEXPORT jboolean JNICALL
Java_com_example_flutter_1application_11_live2d_cubism_Live2DNativeBridge_nativeInitializeFramework(
    JNIEnv*, jobject) {
    std::lock_guard<std::mutex> lock(gMutex);

    if (gFrameworkInitialized) {
        return JNI_TRUE;
    }

    if (!gAllocator) {
        gAllocator = new SimpleAllocator();
    }

    // Configure framework options with file loader and logging
    // Use global gOption because SDK stores pointer, NOT a copy!
    gOption.LogFunction = CubismLogFunction;
    gOption.LoggingLevel = CubismFramework::Option::LogLevel_Info;
    gOption.LoadFileFunction = LoadFileFromAssets;
    gOption.ReleaseBytesFunction = ReleaseBytes;

    if (!CubismFramework::StartUp(gAllocator, &gOption)) {
        __android_log_print(ANDROID_LOG_ERROR, kTag, "StartUp failed");
        return JNI_FALSE;
    }

    CubismFramework::Initialize();
    gFrameworkInitialized = true;

    __android_log_print(ANDROID_LOG_INFO, kTag, "[Phase7-2] CubismFramework initialized");
    return JNI_TRUE;
}

extern "C" JNIEXPORT jint JNICALL
Java_com_example_flutter_1application_11_live2d_cubism_Live2DNativeBridge_nativeGetVersion(
    JNIEnv*, jobject) {
    return static_cast<jint>(Live2D::Cubism::Core::csmGetVersion());
}

extern "C" JNIEXPORT void JNICALL
Java_com_example_flutter_1application_11_live2d_cubism_Live2DNativeBridge_nativeDisposeFramework(
    JNIEnv*, jobject) {
    std::lock_guard<std::mutex> lock(gMutex);

    ReleaseModelResources();

    if (gFrameworkInitialized) {
        CubismFramework::Dispose();
        gFrameworkInitialized = false;
    }

    // Do NOT delete gAllocator here! CubismFramework::StartUp() is a one-time call
    // that caches the allocator pointer. If we delete it, re-initialisation will
    // crash because StartUp() will report "already done" while gAllocator dangles.
    // Keep the allocator alive for the entire process lifetime.

    __android_log_print(ANDROID_LOG_INFO, kTag, "[Phase7-2] CubismFramework disposed");
}

extern "C" JNIEXPORT jboolean JNICALL
Java_com_example_flutter_1application_11_live2d_cubism_Live2DNativeBridge_nativeCreateModel(
    JNIEnv* env, jobject, jstring mocPath) {
    std::lock_guard<std::mutex> lock(gMutex);

    if (!gFrameworkInitialized) {
        __android_log_print(ANDROID_LOG_ERROR, kTag, "Framework not initialized");
        return JNI_FALSE;
    }

    const char* pathChars = env->GetStringUTFChars(mocPath, nullptr);
    std::string path(pathChars ? pathChars : "");
    env->ReleaseStringUTFChars(mocPath, pathChars);

    if (path.empty()) {
        __android_log_print(ANDROID_LOG_ERROR, kTag, "moc path is empty");
        return JNI_FALSE;
    }

    ReleaseModelResources();

    std::vector<csmByte> buffer;
    if (!ReadFileAllBytes(path, buffer)) {
        __android_log_print(ANDROID_LOG_ERROR, kTag, "Failed to read moc file: %s", path.c_str());
        return JNI_FALSE;
    }

    gMoc = CubismMoc::Create(buffer.data(), static_cast<csmSizeInt>(buffer.size()));
    if (!gMoc) {
        __android_log_print(ANDROID_LOG_ERROR, kTag, "CubismMoc::Create failed");
        return JNI_FALSE;
    }

    gModel = gMoc->CreateModel();
    if (!gModel) {
        __android_log_print(ANDROID_LOG_ERROR, kTag, "CreateModel failed");
        CubismMoc::Delete(gMoc);
        gMoc = nullptr;
        return JNI_FALSE;
    }

    __android_log_print(ANDROID_LOG_INFO, kTag, "[Phase7-2] moc3 loaded successfully");
    return JNI_TRUE;
}

extern "C" JNIEXPORT jint JNICALL
Java_com_example_flutter_1application_11_live2d_cubism_Live2DNativeBridge_nativeGetDrawableCount(
    JNIEnv*, jobject) {
    return gModel ? static_cast<jint>(gModel->GetDrawableCount()) : 0;
}

extern "C" JNIEXPORT jint JNICALL
Java_com_example_flutter_1application_11_live2d_cubism_Live2DNativeBridge_nativeGetParameterCount(
    JNIEnv*, jobject) {
    return gModel ? static_cast<jint>(gModel->GetParameterCount()) : 0;
}

extern "C" JNIEXPORT jobjectArray JNICALL
Java_com_example_flutter_1application_11_live2d_cubism_Live2DNativeBridge_nativeGetParameterIds(
    JNIEnv* env, jobject) {
    std::lock_guard<std::mutex> lock(gMutex);

    const jclass stringClass = env->FindClass("java/lang/String");
    if (!stringClass) {
        return nullptr;
    }
    if (!gModel) {
        return env->NewObjectArray(0, stringClass, nullptr);
    }

    const csmInt32 count = gModel->GetParameterCount();
    jobjectArray out = env->NewObjectArray(static_cast<jsize>(count), stringClass, nullptr);
    if (!out) {
        return env->NewObjectArray(0, stringClass, nullptr);
    }

    for (csmInt32 i = 0; i < count; ++i) {
        const CubismIdHandle idHandle = gModel->GetParameterId(static_cast<csmUint32>(i));
        const char* id = (idHandle != nullptr) ? idHandle->GetString().GetRawString() : nullptr;
        if (!id) {
            continue;
        }
        jstring jId = env->NewStringUTF(id);
        env->SetObjectArrayElement(out, static_cast<jsize>(i), jId);
        env->DeleteLocalRef(jId);
    }

    return out;
}

extern "C" JNIEXPORT jfloat JNICALL
Java_com_example_flutter_1application_11_live2d_cubism_Live2DNativeBridge_nativeGetParameterValue(
    JNIEnv* env, jobject, jstring paramId) {
    std::lock_guard<std::mutex> lock(gMutex);

    if (!gModel || !paramId) {
        return 0.0f;
    }

    const char* requested = env->GetStringUTFChars(paramId, nullptr);
    if (!requested) {
        return 0.0f;
    }

    const csmInt32 count = gModel->GetParameterCount();

    jfloat result = 0.0f;
    for (csmInt32 i = 0; i < count; ++i) {
        const CubismIdHandle idHandle = gModel->GetParameterId(static_cast<csmUint32>(i));
        const char* id = (idHandle != nullptr) ? idHandle->GetString().GetRawString() : nullptr;
        if (id && std::strcmp(id, requested) == 0) {
            result = gModel->GetParameterValue(i);
            break;
        }
    }

    env->ReleaseStringUTFChars(paramId, requested);
    return result;
}

extern "C" JNIEXPORT void JNICALL
Java_com_example_flutter_1application_11_live2d_cubism_Live2DNativeBridge_nativeSetParameterValue(
    JNIEnv* env, jobject, jstring paramId, jfloat value) {
    std::lock_guard<std::mutex> lock(gMutex);

    if (!gModel || !paramId) {
        return;
    }

    const char* requested = env->GetStringUTFChars(paramId, nullptr);
    if (!requested) {
        return;
    }

    const csmInt32 count = gModel->GetParameterCount();

    for (csmInt32 i = 0; i < count; ++i) {
        const CubismIdHandle idHandle = gModel->GetParameterId(static_cast<csmUint32>(i));
        const char* id = (idHandle != nullptr) ? idHandle->GetString().GetRawString() : nullptr;
        if (id && std::strcmp(id, requested) == 0) {
            gModel->SetParameterValue(i, value);
            break;
        }
    }

    env->ReleaseStringUTFChars(paramId, requested);
}

extern "C" JNIEXPORT jint JNICALL
Java_com_example_flutter_1application_11_live2d_cubism_Live2DNativeBridge_nativeGetPartCount(
    JNIEnv*, jobject) {
    return gModel ? static_cast<jint>(gModel->GetPartCount()) : 0;
}

extern "C" JNIEXPORT jfloat JNICALL
Java_com_example_flutter_1application_11_live2d_cubism_Live2DNativeBridge_nativeGetCanvasWidth(
    JNIEnv*, jobject) {
    return gModel ? gModel->GetCanvasWidth() : 0.0f;
}

extern "C" JNIEXPORT jfloat JNICALL
Java_com_example_flutter_1application_11_live2d_cubism_Live2DNativeBridge_nativeGetCanvasHeight(
    JNIEnv*, jobject) {
    return gModel ? gModel->GetCanvasHeight() : 0.0f;
}

extern "C" JNIEXPORT jboolean JNICALL
Java_com_example_flutter_1application_11_live2d_cubism_Live2DNativeBridge_nativeCreateRenderer(
    JNIEnv*, jobject) {
    std::lock_guard<std::mutex> lock(gMutex);

    if (!gModel) {
        __android_log_print(ANDROID_LOG_ERROR, kTag, "Model not created");
        return JNI_FALSE;
    }

    // Guard: CubismRenderer_OpenGLES2 loads shader files via the framework's
    // load/release callbacks. If they are not set, shader loading will crash.
    if (!CubismFramework::GetLoadFileFunction() || !CubismFramework::GetReleaseBytesFunction()) {
        __android_log_print(
            ANDROID_LOG_ERROR,
            kTag,
            "LoadFile/ReleaseBytes callbacks not set. Disable SDK rendering (fallback mode)."
        );
        return JNI_FALSE;
    }

    // Shader file pre-flight check: try to load one shader to verify asset pipeline
    {
        csmSizeInt shaderSize = 0;
        csmByte* shaderData = CubismFramework::GetLoadFileFunction()("VertShaderSrc.vert", &shaderSize);
        if (shaderData && shaderSize > 0) {
            CubismFramework::GetReleaseBytesFunction()(shaderData);
            __android_log_print(ANDROID_LOG_INFO, kTag,
                "[Phase7-2] Shader pre-flight OK: VertShaderSrc.vert (%d bytes)", (int)shaderSize);
        } else {
            __android_log_print(ANDROID_LOG_ERROR, kTag,
                "[Phase7-2] Shader pre-flight FAILED: cannot load VertShaderSrc.vert — SDK rendering disabled");
            return JNI_FALSE;
        }
    }

    if (gRenderer) {
        CubismRenderer::Delete(gRenderer);
        gRenderer = nullptr;
        gRendererGL = nullptr;
    }

    gRenderer = CubismRenderer::Create();
    if (!gRenderer) {
        __android_log_print(ANDROID_LOG_ERROR, kTag, "Renderer create failed");
        return JNI_FALSE;
    }

    gRenderer->Initialize(gModel);
    gRenderer->IsPremultipliedAlpha(true);
    gRenderer->IsCulling(true);

    gRendererGL = static_cast<CubismRenderer_OpenGLES2*>(gRenderer);

    __android_log_print(ANDROID_LOG_INFO, kTag, "[Phase7-2] Renderer initialized");
    return JNI_TRUE;
}

extern "C" JNIEXPORT void JNICALL
Java_com_example_flutter_1application_11_live2d_cubism_Live2DNativeBridge_nativeBindTexture(
    JNIEnv*, jobject, jint index, jint textureId) {
    if (gRendererGL) {
        gRendererGL->BindTexture(static_cast<csmUint32>(index), static_cast<GLuint>(textureId));
    }
}

extern "C" JNIEXPORT void JNICALL
Java_com_example_flutter_1application_11_live2d_cubism_Live2DNativeBridge_nativeUpdate(
    JNIEnv*, jobject) {
    if (gModel) {
        gModel->Update();
    }
}

extern "C" JNIEXPORT void JNICALL
Java_com_example_flutter_1application_11_live2d_cubism_Live2DNativeBridge_nativeDraw(
    JNIEnv* env, jobject, jfloatArray mvpArray) {
    if (!gRenderer || !gModel || !mvpArray) return;

    jfloat* mvp = env->GetFloatArrayElements(mvpArray, nullptr);
    if (!mvp) return;

    CubismMatrix44 matrix;
    matrix.SetMatrix(mvp);
    gRenderer->SetMvpMatrix(&matrix);
    gRenderer->DrawModel();

    env->ReleaseFloatArrayElements(mvpArray, mvp, 0);
}

extern "C" JNIEXPORT void JNICALL
Java_com_example_flutter_1application_11_live2d_cubism_Live2DNativeBridge_nativeReleaseModel(
    JNIEnv*, jobject) {
    std::lock_guard<std::mutex> lock(gMutex);
    ReleaseModelResources();
    __android_log_print(ANDROID_LOG_INFO, kTag, "[Phase7-2] Model released");
}
