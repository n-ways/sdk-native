import java.util.Properties
import org.jetbrains.kotlin.gradle.dsl.JvmTarget

plugins {
    id("com.android.application")
    id("org.jetbrains.kotlin.android")
}

// The API key comes from local.properties (never committed): nways.apiKey=…
val localProps = Properties().apply {
    rootProject.file("local.properties").takeIf { it.exists() }?.inputStream()?.use { load(it) }
}
val apiKey: String = localProps.getProperty("nways.apiKey")?.takeIf { it.isNotBlank() } ?: "YOUR_API_KEY"
val baseUrl: String = localProps.getProperty("nways.baseUrl")?.takeIf { it.isNotBlank() } ?: "https://nways.ng"

android {
    namespace = "ng.nways.sample"
    compileSdk = 36

    defaultConfig {
        applicationId = "ng.nways.sample"
        minSdk = 23
        targetSdk = 36
        versionCode = 1
        versionName = "1.0.0"
        buildConfigField("String", "NWAYS_API_KEY", "\"$apiKey\"")
        buildConfigField("String", "NWAYS_BASE_URL", "\"$baseUrl\"")
    }

    buildFeatures {
        buildConfig = true
    }

    packaging {
        // MapLibre's native library ships already stripped; no NDK needed to package it.
        jniLibs.keepDebugSymbols += "**/libmaplibre.so"
    }

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }
}

kotlin {
    compilerOptions {
        jvmTarget.set(JvmTarget.JVM_17)
        allWarningsAsErrors.set(true)
    }
}

dependencies {
    implementation(project(":nways-maps"))
    implementation(libs.coroutines.android)
}
