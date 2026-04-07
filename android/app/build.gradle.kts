import java.util.Properties
import java.io.FileInputStream

plugins {
    id("com.android.application")
    id("org.jetbrains.kotlin.android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

// Ensure Gradle uses a JDK with jlink via Toolchains (avoids IDE JBR without jlink)
java {
    toolchain {
        languageVersion.set(JavaLanguageVersion.of(17))
        // vendor can be omitted; Gradle will auto-provision a matching JDK that includes jlink
    }
}

kotlin {
    jvmToolchain(17)
}

// Load signing properties from android/key.properties if present
val keyProps: Properties = Properties().apply {
    val keyFile = File(rootDir, "android/key.properties")
    if (keyFile.exists()) FileInputStream(keyFile).use { load(it) }
}

fun propOrEnvOrKey(name: String, keyName: String): String? {
    val fromGradle = providers.gradleProperty(name)
    if (fromGradle.isPresent) return fromGradle.get()
    val fromEnv = providers.environmentVariable(name)
    if (fromEnv.isPresent) return fromEnv.get()
    return keyProps.getProperty(keyName)
}

android {
    namespace = "com.example.truckercore1"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    packaging {
        resources {
            excludes += "META-INF/*"
        }
    }

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    buildFeatures {
        buildConfig = true
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_17.toString()
    }

    // Exclude checked-in GeneratedPluginRegistrant. Flutter will generate it under build/ at compile time.
    sourceSets.named("main") {
        java.exclude("io/flutter/plugins/GeneratedPluginRegistrant.java")
    }

    defaultConfig {
        applicationId = "com.example.truckercore1"
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
        testInstrumentationRunner = "androidx.test.runner.AndroidJUnitRunner"

        // Expose some defaults; replaced by flavors below via BuildConfig
        buildConfigField("String", "SUPABASE_URL", "\"\"")
        buildConfigField("String", "SUPABASE_KEY", "\"\"")
        buildConfigField("String", "MAPS_KEY", "\"\"")
        buildConfigField("String", "STRIPE_PK", "\"\"")
    }


    // Configure signing configs; prefer release keystore if android/key.properties is present
    signingConfigs {
        create("release") {
            val keyAliasProp = keyProps.getProperty("keyAlias")
            val keyPasswordProp = keyProps.getProperty("keyPassword")
            val storeFileProp = keyProps.getProperty("storeFile")
            val storePasswordProp = keyProps.getProperty("storePassword")

            if (storeFileProp != null && keyAliasProp != null && keyPasswordProp != null && storePasswordProp != null) {
                keyAlias = keyAliasProp
                keyPassword = keyPasswordProp
                storeFile = file(storeFileProp)
                storePassword = storePasswordProp
            }
        }
    }

    buildTypes {
        release {
            // Use release signing if a keystore is configured; otherwise fall back to debug signing
            val hasReleaseKeystore = keyProps.getProperty("storeFile") != null
            signingConfig = if (hasReleaseKeystore) signingConfigs.getByName("release") else signingConfigs.getByName("debug")
            isMinifyEnabled = true
            isShrinkResources = true
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro"
            )
        }
        debug {
            // Ensure debug builds use the default Android debug keystore
            signingConfig = signingConfigs.getByName("debug")
            // Helpful flags in debug
            applicationIdSuffix = ".debug"
            versionNameSuffix = "-debug"
        }
    }

    flavorDimensions += listOf("env")
    productFlavors {
        create("dev") {
            dimension = "env"
            applicationId = "com.example.truckercore1.dev"
            versionNameSuffix = "-dev"

            val supabaseUrl = providers.gradleProperty("DEV_SUPABASE_URL").orElse(providers.environmentVariable("DEV_SUPABASE_URL")).getOrElse("")
            val supabaseKey = providers.gradleProperty("DEV_SUPABASE_KEY").orElse(providers.environmentVariable("DEV_SUPABASE_KEY")).getOrElse("")
            val mapsKey = providers.gradleProperty("DEV_MAPS_KEY").orElse(providers.environmentVariable("DEV_MAPS_KEY")).getOrElse("")
            val stripePk = providers.gradleProperty("DEV_STRIPE_PK").orElse(providers.environmentVariable("DEV_STRIPE_PK")).getOrElse("")
            buildConfigField("String", "SUPABASE_URL", "\"$supabaseUrl\"")
            buildConfigField("String", "SUPABASE_KEY", "\"$supabaseKey\"")
            buildConfigField("String", "MAPS_KEY", "\"$mapsKey\"")
            buildConfigField("String", "STRIPE_PK", "\"$stripePk\"")
            resValue("string", "app_name", "TruckerCore (Dev)")
        }
        create("stage") {
            dimension = "env"
            applicationId = "com.example.truckercore1.stage"
            versionNameSuffix = "-stage"
            val supabaseUrl = providers.gradleProperty("STAGE_SUPABASE_URL").orElse(providers.environmentVariable("STAGE_SUPABASE_URL")).getOrElse("")
            val supabaseKey = providers.gradleProperty("STAGE_SUPABASE_KEY").orElse(providers.environmentVariable("STAGE_SUPABASE_KEY")).getOrElse("")
            val mapsKey = providers.gradleProperty("STAGE_MAPS_KEY").orElse(providers.environmentVariable("STAGE_MAPS_KEY")).getOrElse("")
            val stripePk = providers.gradleProperty("STAGE_STRIPE_PK").orElse(providers.environmentVariable("STAGE_STRIPE_PK")).getOrElse("")
            buildConfigField("String", "SUPABASE_URL", "\"$supabaseUrl\"")
            buildConfigField("String", "SUPABASE_KEY", "\"$supabaseKey\"")
            buildConfigField("String", "MAPS_KEY", "\"$mapsKey\"")
            buildConfigField("String", "STRIPE_PK", "\"$stripePk\"")
            resValue("string", "app_name", "TruckerCore (Stage)")
        }
        create("prod") {
            dimension = "env"
            applicationId = "com.example.truckercore1"
            val supabaseUrl = providers.gradleProperty("PROD_SUPABASE_URL").orElse(providers.environmentVariable("PROD_SUPABASE_URL")).getOrElse("")
            val supabaseKey = providers.gradleProperty("PROD_SUPABASE_KEY").orElse(providers.environmentVariable("PROD_SUPABASE_KEY")).getOrElse("")
            val mapsKey = providers.gradleProperty("PROD_MAPS_KEY").orElse(providers.environmentVariable("PROD_MAPS_KEY")).getOrElse("")
            val stripePk = providers.gradleProperty("PROD_STRIPE_PK").orElse(providers.environmentVariable("PROD_STRIPE_PK")).getOrElse("")
            buildConfigField("String", "SUPABASE_URL", "\"$supabaseUrl\"")
            buildConfigField("String", "SUPABASE_KEY", "\"$supabaseKey\"")
            buildConfigField("String", "MAPS_KEY", "\"$mapsKey\"")
            buildConfigField("String", "STRIPE_PK", "\"$stripePk\"")
            resValue("string", "app_name", "TruckerCore")
        }
    }
}

dependencies {
    androidTestImplementation("androidx.test.ext:junit:1.2.1")
    androidTestImplementation("androidx.test.espresso:espresso-core:3.6.1")
    // Ensure Flutter embedding is available for Kotlin sources in release builds
    val flutterEngineRev = "1.0.0-1e9a811bf8e70466596bcf0ea3a8b5adb5f17f7f"
    implementation("io.flutter:flutter_embedding_release:$flutterEngineRev")

    // Baseline Profile installer and AndroidX Startup
    implementation("androidx.core:core-ktx:1.13.1")
    implementation("androidx.profileinstaller:profileinstaller:1.3.1")
    implementation("androidx.startup:startup-runtime:1.1.1")
}

flutter {
    source = "../.."
}

// --- Signing validation task (optional guardrail) ---
// Configure via Gradle/ENV properties:
//  - SIGNING_PROPS_PATH: path to key.properties (default: android/key.properties)
//  - REQUIRE_SIGNING_PROPS_FOR_DEBUG=true to make assembleDevDebug depend on this task
val signingPropsPathProp = providers.gradleProperty("SIGNING_PROPS_PATH")
    .orElse(providers.environmentVariable("SIGNING_PROPS_PATH"))
val signingPropsPath = signingPropsPathProp.getOrElse("android/key.properties")
val requirePropsForDebug = providers.gradleProperty("REQUIRE_SIGNING_PROPS_FOR_DEBUG")
    .orElse(providers.environmentVariable("REQUIRE_SIGNING_PROPS_FOR_DEBUG"))
    .map { it.equals("true", ignoreCase = true) }
    .getOrElse(false)

tasks.register("validateSigningProperties") {
    group = "verification"
    description = "Validates that the signing properties file exists (path configurable)."
    doLast {
        val propsFile = File(rootDir, signingPropsPath)
        if (propsFile.exists()) {
            println("Found signing properties file at: ${propsFile.path}")
        } else {
            val msg = "Signing properties file not found at: ${propsFile.path}. " +
                    "Override with -PSIGNING_PROPS_PATH=<path> or env SIGNING_PROPS_PATH."
            if (requirePropsForDebug) {
                throw GradleException(msg)
            } else {
                println("[validateSigningProperties] $msg (non-fatal for debug builds)")
            }
        }
    }
}

// Only enforce the validation for DevDebug if explicitly requested via property/ENV.
if (requirePropsForDebug) {
    tasks.named("assembleDevDebug").configure {
        dependsOn("validateSigningProperties")
    }
}


// --- Flutter compatibility: produce app-release.apk alias ---
// Flutter tooling expects an APK at build/outputs/flutter-apk/app-release.apk.
// Our project uses flavors (dev/stage/prod), and the default Gradle task
// 'assembleRelease' may not produce a direct 'release' APK (it assembled stageRelease).
// The task below finds any flavor release APK and copies it to the expected location.

val ensureFlutterApk = tasks.register("ensureFlutterApk") {
    group = "build"
    description = "Copies the built flavor APK to outputs/flutter-apk/app-release.apk for Flutter tooling."
    doLast {
        val apkRoot = File(buildDir, "outputs/apk")
        if (!apkRoot.exists()) {
            throw GradleException("APK outputs directory not found: ${apkRoot.path}")
        }
        val candidates = apkRoot.walkTopDown()
            .filter { it.isFile && it.name.endsWith("-release.apk") }
            .toList()
        if (candidates.isEmpty()) {
            throw GradleException("No *-release.apk found under ${apkRoot.path}")
        }
        val apk = candidates.first()
        val destDir = File(buildDir, "outputs/flutter-apk")
        if (!destDir.exists()) destDir.mkdirs()
        copy {
            from(apk)
            into(destDir)
            rename { "app-release.apk" }
        }
        println("[ensureFlutterApk] Copied ${apk.name} to ${destDir.path}\\app-release.apk")
    }
}

// Ensure that running assembleRelease will build the stage flavor and then place
// the artifact where Flutter expects it.
try {
    tasks.named("assembleRelease").configure {
        dependsOn("assembleStageRelease")
        finalizedBy(ensureFlutterApk)
    }
} catch (_: Throwable) {
    // If task names differ (e.g., older/newer AGP), fail silently – manual build still works.
}

// --- Alias task to avoid ambiguous :app:compileJava ---
// Some tooling invokes :app:compileJava, which is ambiguous with Android's variant-specific tasks
// like compileDevDebugJavaWithJavac. We provide a deterministic alias that defaults to devDebug,
// and can be overridden via -PVARIANT=<flavor><BuildType> (e.g., -PVARIANT=prodRelease).
val requestedVariant = providers.gradleProperty("VARIANT")
    .orElse(providers.environmentVariable("VARIANT"))
    .getOrElse("devDebug")

val targetCompileTaskNameProvider = providers.provider {
    val cap = requestedVariant.replaceFirstChar { it.uppercaseChar() }
    "compile${cap}JavaWithJavac"
}

// Register the alias task
val compileJavaAlias = tasks.register("compileJava") {
    group = "build"
    description = "Alias for ${'$'}{targetCompileTaskNameProvider.get()} (set -PVARIANT=<flavor><BuildType> to choose)."
}

// After projects are evaluated and AGP has created variant tasks, wire the dependency or provide a helpful error.
gradle.projectsEvaluated {
    val targetName = targetCompileTaskNameProvider.get()
    val targetTask = tasks.findByName(targetName)
    if (targetTask != null) {
        compileJavaAlias.configure { dependsOn(targetName) }
    } else {
        compileJavaAlias.configure {
            doLast {
                val candidates = tasks.names
                    .filter { it.startsWith("compile") && it.endsWith("JavaWithJavac") }
                    .sorted()
                throw GradleException(
                    "Variant '${'$'}requestedVariant' not found. Expected task '${'$'}targetName'. Available Java compile tasks:\n" +
                            candidates.joinToString(", ")
                )
            }
        }
    }
}
