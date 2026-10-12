import java.io.File

// La clave de Google Maps sale del mismo .env de la app (GOOGLE_MAPS_API_KEY) o
// de una variable de entorno en CI. Nunca se escribe en el repo.
fun mapsApiKey(root: File): String {
    System.getenv("GOOGLE_MAPS_API_KEY")?.let { if (it.isNotBlank()) return it }
    val env = File(root, "../.env")
    if (!env.exists()) return ""
    return env.readLines()
        .map { it.trim() }
        .firstOrNull { it.startsWith("GOOGLE_MAPS_API_KEY=") }
        ?.substringAfter("=")?.trim() ?: ""
}

plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.example.gosmart"
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
        applicationId = "com.example.gosmart"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
        manifestPlaceholders["MAPS_API_KEY"] = mapsApiKey(rootProject.projectDir)
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
    implementation("com.google.android.material:material:1.12.0")
}
