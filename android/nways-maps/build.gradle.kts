import org.jetbrains.kotlin.gradle.dsl.JvmTarget

plugins {
    id("com.android.library")
    id("org.jetbrains.kotlin.android")
    `maven-publish`
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

    publishing {
        singleVariant("release") {
            withSourcesJar()
        }
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

// Local publishing only (./gradlew :nways-maps:publishToMavenLocal).
// Maven Central publishing is not set up: the owner decides when.
publishing {
    publications {
        register<MavenPublication>("release") {
            groupId = "ng.nways"
            artifactId = "maps"
            version = project.version.toString()
            afterEvaluate { from(components["release"]) }
            pom {
                name.set("N-Ways Maps for Android")
                description.set("N-Ways maps, geocoding, places and routes on MapLibre Native.")
                url.set("https://nways.ng/developers/")
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
            }
        }
    }
}
