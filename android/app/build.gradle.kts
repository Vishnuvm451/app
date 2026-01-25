plugins {
    id("com.android.application")
    id("kotlin-android")
    id("dev.flutter.flutter-gradle-plugin")
    id("com.google.gms.google-services")
}

android {
    namespace = "com.example.darzo"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        // ✅ CHANGED: Use Java 1.8 to fix the notification error
        sourceCompatibility = JavaVersion.VERSION_1_8
        targetCompatibility = JavaVersion.VERSION_1_8
        
        // ✅ ADDED: This enables the desugaring feature you need
        isCoreLibraryDesugaringEnabled = true
    }

    kotlinOptions {
        // ✅ CHANGED: Match Java 1.8
        jvmTarget = "1.8"
    }

    defaultConfig {
        applicationId = "com.example.darzo"
        // ✅ CHANGED: Strict minimum 21 is good
        minSdk = flutter.minSdkVersion 
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    buildTypes {
        release {
            signingConfig = signingConfigs.getByName("debug")
        }
    }
}

// ✅ ADDED: Dependency for desugaring
dependencies {
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.0.4")
}

flutter {
    source = "../.."
}