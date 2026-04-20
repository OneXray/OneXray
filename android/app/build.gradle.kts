import org.jetbrains.kotlin.gradle.dsl.JvmTarget
import java.util.Properties

plugins {
    id("com.android.application")
    // START: FlutterFire Configuration
    id("com.google.gms.google-services")
    id("com.google.firebase.crashlytics")
    // END: FlutterFire Configuration
    id("kotlin-android")
    kotlin("android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
    id("org.jetbrains.kotlin.plugin.serialization")
}

// Optional upload-signing config. The keystore directory is gitignored, so
// fresh clones won't have this file — in that case we fall back to the default
// debug keystore so `./gradlew assembleDebug` / `flutter run` works out of the
// box without any signing setup.
val keystoreFile = rootProject.file("keystore/keystore.properties")
val keystoreProperties: Properties? = if (keystoreFile.exists()) {
    Properties().apply { keystoreFile.inputStream().use { load(it) } }
} else {
    null
}

android {
    namespace = "net.yuandev.onexray"
    compileSdk = 36
    ndkVersion = "29.0.14206865"

    compileOptions {
        isCoreLibraryDesugaringEnabled = true
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        applicationId = "net.yuandev.onexray"
        minSdk = 29
        targetSdk = 36
        versionCode = flutter.versionCode
        versionName = flutter.versionName

        ndk {
            abiFilters += listOf("armeabi-v7a", "arm64-v8a", "x86_64")
        }

        // AdMob APPLICATION_ID — read from env var at build time so the real id
        // isn't committed to the repo. Falls back to Google's test App ID so a
        // fresh clone without the env set can still build and run (with test ads).
        manifestPlaceholders["admobAppId"] = System.getenv("ADMOB_APP_ID_ANDROID")
            ?: "ca-app-pub-3940256099942544~3347511713"
    }

    signingConfigs {
        keystoreProperties?.let { props ->
            create("upload") {
                keyAlias = props["keyAlias"] as String
                keyPassword = props["keyPassword"] as String
                storeFile = file(props["storeFile"] as String)
                storePassword = props["storePassword"] as String
            }
        }
    }

    buildTypes {
        release {
            // Real releases use the upload key when keystore/keystore.properties is
            // present. Without it, fall back to the debug keystore so a contributor
            // can still run `./gradlew assembleRelease` locally — the resulting APK
            // is debug-signed and can be installed on a test device but cannot be
            // published to Play Store.
            signingConfig = signingConfigs.findByName("upload")
                ?: signingConfigs.getByName("debug")
        }
    }
}

kotlin {
    compilerOptions {
        jvmTarget = JvmTarget.fromTarget("17")
    }
}

flutter {
    source = "../.."
}

dependencies {
    val coreVersion = "1.18.0"
    implementation("androidx.core:core-ktx:$coreVersion")

    implementation("androidx.fragment:fragment-ktx:1.8.9")
    implementation("androidx.activity:activity-ktx:1.13.0")

    implementation("com.google.android.play:integrity:1.6.0")
    implementation("com.google.android.gms:play-services-ads:25.1.0")

    implementation("androidx.datastore:datastore:1.2.1")

    val kotlinxCoroutinesVersion = "1.10.2"
    implementation("org.jetbrains.kotlinx:kotlinx-coroutines-core:$kotlinxCoroutinesVersion")
    implementation("org.jetbrains.kotlinx:kotlinx-coroutines-android:$kotlinxCoroutinesVersion")
    implementation("org.jetbrains.kotlinx:kotlinx-serialization-json:1.10.0")

    implementation("com.github.getActivity:XXPermissions:21.3")
    implementation("com.elvishew:xlog:1.11.1")

    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.5")

    implementation(fileTree(mapOf("dir" to "libs", "include" to listOf("*.jar", "*.aar"))))
}
