#include <jni.h>
#include <android/log.h>
#include <vector>
#include <string>
#include <fstream>
#include <mutex>
#include <cstdlib>

// NOTE: Do NOT include "Live2DCubismCore.h" directly.
// CubismFramework.hpp includes "Live2DCubismCore.hpp" which wraps the C header
// inside namespace Live2D::Cubism::Core. Including the raw C header first would
// put types in the global namespace and block the namespace wrapper via #pragma once.
#include "CubismFramework.hpp"
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

    if (!CubismFramework::StartUp(gAllocator, nullptr)) {
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

    if (gAllocator) {
        delete gAllocator;
        gAllocator = nullptr;
    }

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
