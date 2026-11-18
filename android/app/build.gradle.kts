plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
    // Reads android/app/google-services.json (from the Firebase console) and
    // wires this app to your Firebase project at build time.
    id("com.google.gms.google-services")
}

android {
    namespace = "my.fyp.voya"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
        // flutter_local_notifications (added for the push-notification
        // feature) requires core library desugaring to be enabled -- see
        // the coreLibraryDesugaring dependency below.
        isCoreLibraryDesugaringEnabled = true
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_17.toString()
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "my.fyp.voya"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        // Raised from flutter.minSdkVersion — current firebase_auth/cloud_firestore
        // need API 23+.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    buildTypes {
        release {
            // TODO: Add your own signing config for the release build.
            // Signing with the debug keys for now, so `flutter run --release` works.
            signingConfig = signingConfigs.getByName("debug")
        }
    }
}

// flutter_stripe's native Payment Sheet needs an AppCompat theme
// (see values/styles.xml) built on top of this library — added
// explicitly rather than relying on it coming in transitively from
// another plugin.
dependencies {
    implementation("androidx.appcompat:appcompat:1.7.0")
    // Required by flutter_local_notifications when core library
    // desugaring is enabled above.
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")

    // google_mlkit_text_recognition (used by receipt_ocr_service.dart for
    // the Chinese/Japanese/Korean receipt scanning added this session)
    // declares its non-Latin script recognizers as `compileOnly` in its own
    // android/build.gradle -- they compile fine but are NOT bundled into
    // the APK unless the app itself also declares them here. Without this,
    // the moment scan() picks TextRecognitionScript.japanese/korean/chinese
    // (for a Japan/Korea/China-destination trip), the native recognizer
    // class is missing at runtime and the app crashes with
    // ClassNotFoundException / NoClassDefFoundError. Latin (the default
    // for every other destination) ships as a normal `implementation`
    // dependency of the plugin already, so it was never affected.
    // Version pinned to match the plugin's own (0.16.0) declared version.
    implementation("com.google.mlkit:text-recognition-chinese:16.0.1")
    implementation("com.google.mlkit:text-recognition-japanese:16.0.1")
    implementation("com.google.mlkit:text-recognition-korean:16.0.1")
    implementation("com.google.mlkit:text-recognition-devanagari:16.0.1")
}

flutter {
    source = "../.."
}
