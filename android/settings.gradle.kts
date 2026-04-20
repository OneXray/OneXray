pluginManagement {
    val flutterSdkPath = run {
        val properties = java.util.Properties()
        file("local.properties").inputStream().use { properties.load(it) }
        val flutterSdkPath = properties.getProperty("flutter.sdk")
        require(flutterSdkPath != null) { "flutter.sdk not set in local.properties" }
        flutterSdkPath
    }

    includeBuild("$flutterSdkPath/packages/flutter_tools/gradle")

    repositories {
        google()
        mavenCentral()
        gradlePluginPortal()
    }
}

plugins {
    val kotlinVersion = "2.3.20"
    id("dev.flutter.flutter-plugin-loader") version "1.0.0"
    id("com.android.application") version "8.13.2" apply false
    // START: FlutterFire Configuration
    id("com.google.gms.google-services") version ("4.4.4") apply false
    id("com.google.firebase.crashlytics") version ("3.0.6") apply false
    // END: FlutterFire Configuration
    id("org.jetbrains.kotlin.android") version kotlinVersion apply false
    kotlin("plugin.serialization") version kotlinVersion apply false
}

include(":app")
