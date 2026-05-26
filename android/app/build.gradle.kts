plugins {
    id("com.android.application")
    id("kotlin-android")
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.urutau.app"
    compileSdk = flutter.compileSdkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_17.toString()
    }

    signingConfigs {
    create("release") {
      val keystoreFile = file(System.getenv("KEYSTORE_FILE") ?: "release.keystore")
      storeFile = keystoreFile
      storePassword = System.getenv("KEYSTORE_PASSWORD") ?: ""
      keyAlias = System.getenv("KEY_ALIAS") ?: "release"
      keyPassword = System.getenv("KEY_PASSWORD") ?: ""
    }
  }

  defaultConfig {
        applicationId = "com.urutau.app"
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    buildTypes {
        release {
            signingConfig = signingConfigs.getByName("release")
        }
    }
}

flutter {
    source = "../.."
}
