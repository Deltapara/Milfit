plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "fr.defense.milfit.milfit"

    // 1. On utilise le SDK 36 pour la compilation (exigé par les plugins)
    compileSdk = 36
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_17.toString()
    }

    defaultConfig {
        applicationId = "fr.defense.milfit.milfit"

        minSdk = flutter.minSdkVersion

        // 2. IMPORTANT : On garde le Target à 34 pour ton téléphone.
        // C'est ce paramètre qui évite le blocage des 16 KB au lancement.
        targetSdk = 34

        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    // 3. On garde l'extraction forcée pour Sodium et SQLCipher
    packaging {
        jniLibs {
            useLegacyPackaging = true
        }
    }

    buildTypes {
        release {
            signingConfig = signingConfigs.getByName("debug")
            // On laisse false pour le moment pour stabiliser
            isMinifyEnabled = false
            isShrinkResources = false
        }
    }
}

flutter {
    source = "../.."
}
