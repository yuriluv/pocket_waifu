cmake_minimum_required(VERSION 3.22.1)
project(live2d_jni)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_CXX_EXTENSIONS OFF)

if(NOT DEFINED CUBISM_SDK_ROOT)
    message(FATAL_ERROR "CUBISM_SDK_ROOT is not set. Add cubism.sdk.path to android/local.properties")
endif()

# Normalize to forward slashes to avoid Windows escape sequences like \U
file(TO_CMAKE_PATH "${CUBISM_SDK_ROOT}" CUBISM_SDK_ROOT)
set(FRAMEWORK_SRC_DIR "${CUBISM_SDK_ROOT}/Framework/src")

file(GLOB_RECURSE FRAMEWORK_SRC
    "${FRAMEWORK_SRC_DIR}/*.cpp"
)

# Exclude non-OpenGL backends
list(FILTER FRAMEWORK_SRC EXCLUDE REGEX "Rendering/D3D")
list(FILTER FRAMEWORK_SRC EXCLUDE REGEX "Rendering/Metal")
list(FILTER FRAMEWORK_SRC EXCLUDE REGEX "Rendering/Vulkan")

add_library(live2d_jni SHARED
    Live2DNative.cpp
    ${FRAMEWORK_SRC}
)

target_include_directories(live2d_jni PRIVATE
    ${FRAMEWORK_SRC_DIR}
    ${CUBISM_SDK_ROOT}/Core/include
)

add_library(Live2DCubismCore SHARED IMPORTED)
set_target_properties(Live2DCubismCore PROPERTIES
    IMPORTED_LOCATION "${CMAKE_CURRENT_LIST_DIR}/../jniLibs/${ANDROID_ABI}/libLive2DCubismCore.so"
)

find_library(log-lib log)
find_library(android-lib android)
find_library(gles-lib GLESv2)
find_library(egl-lib EGL)

target_compile_definitions(live2d_jni PRIVATE
    CSM_TARGET_ANDROID=1
    CSM_TARGET_ANDROID_ES2=1
)

# Suppress warnings from SDK headers we cannot modify
target_compile_options(live2d_jni PRIVATE
    -Wno-inconsistent-missing-override
)

target_link_libraries(live2d_jni
    Live2DCubismCore
    ${log-lib}
    ${android-lib}
    ${gles-lib}
    ${egl-lib}
)
