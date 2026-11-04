import org.gradle.api.GradleException

plugins {
    id("com.android.application")
    id("kotlin-android")
    id("com.google.gms.google-services")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

// Flutter passes the selected device architecture to Gradle when running on a
// connected phone or emulator. Build only that ABI for faster native CMake
// builds. The local LLM plugin currently ships native code for ARM64 only;
// x64 emulators can still run the app, but that plugin safely disables itself.
val abiByFlutterPlatform = mapOf(
    "android-arm" to "armeabi-v7a",
    "android-arm64" to "arm64-v8a",
    "android-x64" to "x86_64",
)
val targetPlatformAbis = providers.gradleProperty("target-platform")
    .orNull
    ?.split(",")
    ?.map { platform ->
        abiByFlutterPlatform[platform]
            ?: throw GradleException(
                "Unsupported Flutter Android target platform '$platform'. " +
                    "Use android-arm, android-arm64, or android-x64."
            )
    }
    ?.distinct()
    ?: listOf("arm64-v8a", "armeabi-v7a", "x86_64")

android {
    namespace = "com.hawkabuild.hawkabuild"
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
        // Must match the Android app registered in google-services.json.
        applicationId = "com.gerardosison.app_builder_hackathon"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = 26
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName

        ndk {
            abiFilters += targetPlatformAbis
        }

        externalNativeBuild {
            cmake {
                cppFlags += listOf("-std=c++17")
            }
        }
    }

    externalNativeBuild {
        cmake {
            path = file("src/main/cpp/CMakeLists.txt")
            version = "3.22.1"
        }
    }

    buildTypes {
        release {
            // TODO: Add your own signing config for the release build.
            // Signing with the debug keys for now, so `flutter run --release` works.
            signingConfig = signingConfigs.getByName("debug")
        }
    }
}

flutter {
    source = "../.."
}

dependencies {
    implementation("org.jetbrains.kotlinx:kotlinx-coroutines-android:1.9.0")
}

// A release advertised with offline AI must contain real verified weights.
// Failing at build time avoids shipping an APK whose core screens cannot run.
val verifyLocalAiReleaseAssets = tasks.register("verifyLocalAiReleaseAssets") {
    group = "verification"
    description = "Verify Whisper/Qwen weights and integrity manifests before release packaging"
    doLast {
        val appRoot = rootProject.projectDir.parentFile
        val models = listOf(
            "llm" to "qwen3-0.6b-q4_k_m.gguf",
            "whisper" to "ggml-base-q5_1.bin",
        )
        for ((folder, filename) in models) {
            val directory = File(appRoot, "assets/models/$folder")
            val model = File(directory, filename)
            val manifest = File(directory, "model-integrity.json")
            val remedy = "Run python scripts/prepare_model_assets.py --download from the project root, " +
                "then python scripts/verify_model_hashes.py before building again."
            if (!model.isFile || !manifest.isFile) {
                throw GradleException("Offline AI release is missing $filename or its integrity manifest. $remedy")
            }
            val metadata = try {
                groovy.json.JsonSlurper().parse(manifest) as Map<*, *>
            } catch (error: Exception) {
                throw GradleException("Invalid model integrity manifest for $filename. $remedy", error)
            }
            val expectedHash = metadata["sha256"] as? String ?: ""
            val expectedBytes = (metadata["sizeBytes"] as? Number)?.toLong() ?: -1L
            if (metadata["fileName"] != filename ||
                !expectedHash.matches(Regex("[0-9a-fA-F]{64}")) ||
                expectedBytes <= 1024L * 1024L || model.length() != expectedBytes) {
                throw GradleException("Offline AI artifact identity/size is invalid for $filename. $remedy")
            }
            val digest = java.security.MessageDigest.getInstance("SHA-256")
            model.inputStream().buffered().use { input ->
                val buffer = ByteArray(128 * 1024)
                while (true) {
                    val count = input.read(buffer)
                    if (count < 0) break
                    digest.update(buffer, 0, count)
                }
            }
            val actualHash = digest.digest().joinToString("") { "%02x".format(it) }
            if (!actualHash.equals(expectedHash, ignoreCase = true)) {
                throw GradleException("Offline AI checksum verification failed for $filename. $remedy")
            }
        }
    }
}
tasks.matching { it.name == "preReleaseBuild" }.configureEach {
    dependsOn(verifyLocalAiReleaseAssets)
}
