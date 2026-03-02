plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

import java.util.Properties

val localProperties = Properties()
val localPropertiesFile = rootProject.file("local.properties")
if (localPropertiesFile.exists()) {
    localPropertiesFile.inputStream().use { localProperties.load(it) }
}
val cubismSdkPath = localProperties.getProperty("cubism.sdk.path") ?: ""

val keyProperties = Properties()
val keyPropertiesFile = rootProject.file("key.properties")
if (keyPropertiesFile.exists()) {
    keyPropertiesFile.inputStream().use { keyProperties.load(it) }
}

val keystorePath =
    keyProperties.getProperty("storeFile")
        ?: System.getenv("ANDROID_KEYSTORE_PATH")
        ?: ""
val hasReleaseSigning =
    keystorePath.isNotBlank() &&
        (keyProperties.getProperty("storePassword") ?: System.getenv("ANDROID_KEYSTORE_PASSWORD") ?: "").isNotBlank() &&
        (keyProperties.getProperty("keyAlias") ?: System.getenv("ANDROID_KEY_ALIAS") ?: "").isNotBlank() &&
        (keyProperties.getProperty("keyPassword") ?: System.getenv("ANDROID_KEY_PASSWORD") ?: "").isNotBlank()

android {
    namespace = "com.example.flutter_application_1"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_17.toString()
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "com.example.flutter_application_1"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName

        ndk {
            abiFilters += listOf("arm64-v8a")
        }

        if (cubismSdkPath.isNotBlank()) {
            externalNativeBuild {
                cmake {
                    arguments += listOf("-DCUBISM_SDK_ROOT=$cubismSdkPath")
                    abiFilters("arm64-v8a")
                    cppFlags += listOf("-std=c++17", "-fexceptions")
                }
            }
        }
    }

    signingConfigs {
        if (hasReleaseSigning) {
            create("release") {
                storeFile = file(keystorePath)
                storePassword =
                    keyProperties.getProperty("storePassword")
                        ?: System.getenv("ANDROID_KEYSTORE_PASSWORD")
                keyAlias =
                    keyProperties.getProperty("keyAlias")
                        ?: System.getenv("ANDROID_KEY_ALIAS")
                keyPassword =
                    keyProperties.getProperty("keyPassword")
                        ?: System.getenv("ANDROID_KEY_PASSWORD")
            }
        }
    }

    buildTypes {
        release {
            if (hasReleaseSigning) {
                signingConfig = signingConfigs.getByName("release")
            } else {
                signingConfig = signingConfigs.getByName("debug")
            }
        }
    }

    if (cubismSdkPath.isNotBlank()) {
        externalNativeBuild {
            cmake {
                path = file("src/main/cpp/CMakeLists.txt")
            }
        }
    }
}

dependencies {
    implementation("androidx.webkit:webkit:1.9.0")
    implementation("dev.rikka.shizuku:api:13.1.5")
    implementation("dev.rikka.shizuku:provider:13.1.5")
}

flutter {
    source = "../.."
}
