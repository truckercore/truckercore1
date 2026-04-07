pluginManagement {
    repositories {
        google()
        mavenCentral()
        gradlePluginPortal()
        maven { url = uri("https://storage.googleapis.com/download.flutter.io") }
    }
}

dependencyResolutionManagement {
    // Allow project-level repositories if declared
    repositoriesMode.set(RepositoriesMode.PREFER_SETTINGS)
    repositories {
        google()
        mavenCentral()
        // Flutter engine and embedding artifacts
        maven {
            // Local engine repo produced by Flutter during builds
            url = uri("${rootDir}\\..\\build\\host\\outputs\\repo")
        }
        maven {
            // Remote cache for prebuilt engine artifacts
            url = uri("https://storage.googleapis.com/download.flutter.io")
        }
    }
}

// keep Flutter wiring
val flutterSdkPath = run {
    val properties = java.util.Properties()
    file("local.properties").inputStream().use { properties.load(it) }
    val flutterSdkPath = properties.getProperty("flutter.sdk")
    require(flutterSdkPath != null) { "flutter.sdk not set in local.properties" }
    flutterSdkPath
}
includeBuild("$flutterSdkPath/packages/flutter_tools/gradle")

plugins {
    id("com.android.application") version "8.12.0" apply false
    id("org.jetbrains.kotlin.android") version "2.1.0" apply false
    id("com.github.ben-manes.versions") version "0.51.0" apply false
}

rootProject.name = "truckercore1_android"
include(":app")
include(":baselineprofile")
include(":macrobenchmark")
