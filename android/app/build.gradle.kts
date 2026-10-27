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

    // Firma de DEMO, la misma en todo lado (CI y local): así el SHA-1 no cambia,
    // la llave de Google Maps se puede restringir a la app y un APK nuevo se
    // instala encima del anterior sin desinstalar. NO es la firma de Play Store.
    signingConfigs {
        create("demo") {
            storeFile = file("../keystore/gosmart-demo.jks")
            storePassword = "gosmart-demo"
            keyAlias = "gosmart-demo"
            keyPassword = "gosmart-demo"
        }
    }

    buildTypes {
        debug {
            signingConfig = signingConfigs.getByName("demo")
        }
        release {
            signingConfig = signingConfigs.getByName("demo")
        }
    }
}

flutter {
    source = "../.."
}

// Push (FCM) es opcional: sin android/app/google-services.json la app compila
// y funciona igual, solo que sin notificaciones.
if (file("google-services.json").exists()) {
    apply(plugin = "com.google.gms.google-services")
}

dependencies {
    implementation("com.google.android.material:material:1.12.0")
}
