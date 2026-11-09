import org.jetbrains.kotlin.gradle.dsl.JvmTarget

import com.vanniktech.maven.publish.AndroidSingleVariantLibrary

plugins {
    id("com.android.library")
    id("org.jetbrains.kotlin.android")
    id("com.vanniktech.maven.publish") version "0.37.0"
}

group = "ng.nways"
version = "1.0.1"

android {
    namespace = "ng.nways.maps"
    compileSdk = 36

    defaultConfig {
        minSdk = 23
        consumerProguardFiles("consumer-rules.pro")
        buildConfigField("String", "SDK_VERSION", "\"${project.version}\"")
    }

    buildFeatures {
        buildConfig = true
    }

    buildTypes {
        release {
            isMinifyEnabled = false
        }
    }

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    testOptions {
        unitTests.isReturnDefaultValues = true
    }

    lint {
        // MapLibre is pinned to the 11.x line and OkHttp to the 4.x MapLibre 11 is built on.
        disable += "NewerVersionAvailable"
    }
}

kotlin {
    explicitApi()
    compilerOptions {
        jvmTarget.set(JvmTarget.JVM_17)
        allWarningsAsErrors.set(true)
    }
}

dependencies {
    api(libs.maplibre.android)
    api(libs.okhttp)
    api(libs.serialization.json)
    implementation(libs.coroutines.android)

    testImplementation(libs.junit)
    testImplementation(libs.okhttp.mockwebserver)
    testImplementation(libs.coroutines.test)
}

// Publishing: Maven Central (ng.nways:maps) through the Central Portal, signed; the
// same publication goes to mavenLocal (./gradlew :nways-maps:publishToMavenLocal,
// what JitPack runs). Credentials and the signing key live in ~/.gradle/gradle.properties
// (mavenCentralUsername, mavenCentralPassword, signingInMemoryKey*), never here.
//   ./gradlew :nways-maps:publishToMavenCentral   (automatic release once validated)
mavenPublishing {
    publishToMavenCentral(automaticRelease = true)
    if (providers.gradleProperty("signingInMemoryKey").isPresent) signAllPublications()
    coordinates("ng.nways", "maps", project.version.toString())
    configure(AndroidSingleVariantLibrary(variant = "release", sourcesJar = true, publishJavadocJar = true))
    pom {
        name.set("N-Ways Maps for Android")
        description.set("N-Ways maps of West Africa on MapLibre Native, with geocoding, postcodes, places and routes.")
        url.set("https://nways.ng/developers/android-sdk")
        inceptionYear.set("2026")
        licenses {
            license {
                name.set("Apache-2.0")
                url.set("https://www.apache.org/licenses/LICENSE-2.0.txt")
                distribution.set("repo")
            }
        }
        organization {
            name.set("N-WAYS LIMITED")
            url.set("https://nways.ng")
        }
        developers {
            developer {
                id.set("n-ways")
                name.set("N-WAYS LIMITED")
                email.set("hello@nways.ng")
                url.set("https://nways.ng")
            }
        }
        scm {
            url.set("https://github.com/n-ways/sdk-native")
            connection.set("scm:git:https://github.com/n-ways/sdk-native.git")
            developerConnection.set("scm:git:ssh://git@github.com/n-ways/sdk-native.git")
        }
    }
}
