import java.io.File
import java.io.FileInputStream
import java.util.Properties

plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android Gradle plugin.
    id("dev.flutter.flutter-gradle-plugin")
    id("com.google.gms.google-services")
}

val releaseSigningProperties = Properties()
val releaseSigningPropertiesFile = rootProject.file("key.properties")
if (releaseSigningPropertiesFile.exists()) {
    FileInputStream(releaseSigningPropertiesFile).use { stream ->
        releaseSigningProperties.load(stream)
    }
}

fun readDotEnv(file: File): Map<String, String> {
    if (!file.exists()) return emptyMap()

    return file.readLines()
        .mapNotNull { rawLine ->
            val line = rawLine.trim()
            if (line.isEmpty() || line.startsWith("#")) return@mapNotNull null

            val separatorIndex = line.indexOf('=')
            if (separatorIndex <= 0) return@mapNotNull null

            val key = line.substring(0, separatorIndex).trim().removePrefix("export ").trim()
            val value = line.substring(separatorIndex + 1)
                .trim()
                .removeSurrounding("\"")
                .removeSurrounding("'")
            key to value
        }
        .toMap()
}

val appEnv = readDotEnv(rootProject.projectDir.parentFile.resolve(".env"))
val googleTestAdmobAppId = "ca-app-pub-3940256099942544~3347511713"
val productionAdmobAppId = appEnv["ADMOB_ANDROID_APP_ID"].orEmpty()
val releaseTaskRequested = gradle.startParameter.taskNames.any {
    it.contains("release", ignoreCase = true)
}

if (releaseTaskRequested) {
    if (!releaseSigningPropertiesFile.exists()) {
        throw GradleException(
            "Release signing yapılandırılmamış. android/key.properties oluşturup upload/release keystore bilgilerini ekleyin."
        )
    }

    if (productionAdmobAppId.isBlank() || productionAdmobAppId == googleTestAdmobAppId) {
        throw GradleException(
            "Release AdMob App ID yapılandırılmamış. .env içine gerçek ADMOB_ANDROID_APP_ID ekleyin."
        )
    }
}

android {
    namespace = "com.winds.hard_kapitalizm"
    compileSdk = 36
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        applicationId = "com.winds.hard_kapitalizm"
        minSdk = flutter.minSdkVersion
        targetSdk = 36
        versionCode = flutter.versionCode
        versionName = flutter.versionName

        // Debug/profile builds use Google's official test App ID by default.
        manifestPlaceholders["ADMOB_APP_ID"] = googleTestAdmobAppId
    }

    signingConfigs {
        create("release") {
            if (releaseSigningPropertiesFile.exists()) {
                keyAlias = releaseSigningProperties.getProperty("keyAlias")
                keyPassword = releaseSigningProperties.getProperty("keyPassword")
                storeFile = file(releaseSigningProperties.getProperty("storeFile"))
                storePassword = releaseSigningProperties.getProperty("storePassword")
            }
        }
    }

    buildTypes {
        getByName("debug") {
            manifestPlaceholders["ADMOB_APP_ID"] = googleTestAdmobAppId
        }

        getByName("release") {
            signingConfig = if (releaseSigningPropertiesFile.exists()) {
                signingConfigs.getByName("release")
            } else {
                null
            }

            // Release build is fail-closed above when this value is missing/test.
            manifestPlaceholders["ADMOB_APP_ID"] = productionAdmobAppId.ifBlank {
                "missing-admob-app-id"
            }
        }
    }
}

kotlin {
    compilerOptions {
        jvmTarget.set(org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17)
    }
}

flutter {
    source = "../.."
}
