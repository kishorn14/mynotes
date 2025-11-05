plugins {
    id("com.android.application")
    id("org.jetbrains.kotlin.android") // ✅ standard Kotlin plugin
    id("com.google.gms.google-services") // ✅ required for Firebase
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.example.mynotesapp"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_11
        targetCompatibility = JavaVersion.VERSION_11
        isCoreLibraryDesugaringEnabled = true // ✅ Enable Java 8 desugaring for notifications
    }

    kotlinOptions {
        jvmTarget = "11"
    }

    defaultConfig {
        // ✅ FIXED: must match Firebase package name
        applicationId = "com.example.mynotesapp"
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    buildTypes {
        debug {
            isMinifyEnabled = false
            isShrinkResources = false
        }
        release {
            isMinifyEnabled = true
            isShrinkResources = true
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro"
            )
            signingConfig = signingConfigs.getByName("debug")
        }
    }
}

flutter {
    source = "../.."
}

dependencies {
    // ✅ Required for core library desugaring (Java 8+ APIs support)
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.3")

    // ✅ Firebase Messaging for notifications
    implementation("com.google.firebase:firebase-messaging:24.0.1")
}

// ✅ Firebase initialization plugin
apply(plugin = "com.google.gms.google-services")
