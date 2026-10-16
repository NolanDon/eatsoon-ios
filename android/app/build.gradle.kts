import java.util.Properties

val releaseProperties = Properties().apply {
    val path = System.getenv("ANDROID_SIGNING_PROPERTIES") ?: ""
    if (path.isNotEmpty()) file(path).inputStream().use { load(it) }
}
val playIntegrityCloudProjectNumber = (
    providers.gradleProperty("PLAY_INTEGRITY_CLOUD_PROJECT_NUMBER")
        .orElse(providers.environmentVariable("PLAY_INTEGRITY_CLOUD_PROJECT_NUMBER"))
        .orNull ?: "0"
).toLongOrNull() ?: throw GradleException("PLAY_INTEGRITY_CLOUD_PROJECT_NUMBER must be numeric.")
gradle.taskGraph.whenReady {
    if (allTasks.any { it.name.contains("release", ignoreCase = true) } &&
        playIntegrityCloudProjectNumber <= 0L
    ) {
        throw GradleException("Set PLAY_INTEGRITY_CLOUD_PROJECT_NUMBER to the Play-linked Cloud project number before building a release.")
    }
}

plugins {
    id("com.android.application")
    id("org.jetbrains.kotlin.android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.boxill.eatsoon"
    compileSdk = 36
    ndkVersion = flutter.ndkVersion
    buildFeatures {
        buildConfig = true
    }

    compileOptions {
        isCoreLibraryDesugaringEnabled = true
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        applicationId = "com.boxill.eatsoon"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = 26
        targetSdk = 36
        // Uses the version code from pubspec.yaml. When using split APKs, 1000 * ABI_VERSION
        // is added automatically by Flutter. (https://developer.android.com/studio/build/configure-apk-splits#configure-APK-versions)
        // You can force using the value of versionCode by specifying the `-P force-version-code-ignoring-abi=true`
        // flag during build.
        versionCode = flutter.versionCode
        versionName = flutter.versionName
        buildConfigField("long", "PLAY_INTEGRITY_CLOUD_PROJECT_NUMBER", "${playIntegrityCloudProjectNumber}L")
        ndk {
            abiFilters += listOf("arm64-v8a", "x86_64")
        }
    }

    signingConfigs {
        create("release") {
            if (releaseProperties.isNotEmpty()) {
                storeFile = file(releaseProperties.getProperty("storeFile"))
                storePassword = releaseProperties.getProperty("storePassword")
                keyAlias = releaseProperties.getProperty("keyAlias")
                keyPassword = releaseProperties.getProperty("keyPassword")
            }
        }
    }
    packaging {
        jniLibs {
            excludes += "lib/armeabi-v7a/**"
        }
    }
    buildTypes {
        release {
            // Keep the first Android releases fully inspectable. Dart remains
            // release/AOT compiled; native shrinking can be enabled separately.
            isMinifyEnabled = false
            isShrinkResources = false
            signingConfig = signingConfigs.getByName("release")
        }
    }
}

kotlin {
    compilerOptions {
        jvmTarget = org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17
    }
}

flutter {
    source = "../.."
}

dependencies {
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.5")
    implementation("com.google.android.gms:play-services-mlkit-subject-segmentation:16.0.0-beta1")
    implementation("com.google.android.play:integrity:1.6.0")
}
