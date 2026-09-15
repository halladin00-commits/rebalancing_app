import java.util.Properties
import java.io.FileInputStream

plugins {
    id("com.android.application")
    id("kotlin-android")
    id("dev.flutter.flutter-gradle-plugin")
}

// ── 키스토어 설정 로드 ──
val keystorePropertiesFile = rootProject.file("key.properties")
val keystoreProperties = Properties()
if (keystorePropertiesFile.exists()) {
    keystoreProperties.load(FileInputStream(keystorePropertiesFile))
}

android {
    namespace = "com.xaxavoo.rebalancing"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
        isCoreLibraryDesugaringEnabled = true
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_17.toString()
    }

    defaultConfig {
        applicationId = "com.xaxavoo.rebalancing"
        minSdk = flutter.minSdkVersion                      // google_mobile_ads 7.x 요구사항
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
        resourceConfigurations += listOf("ko", "en")
    }

    // ── 서명 설정 ──
    signingConfigs {
        if (keystorePropertiesFile.exists()) {
            create("release") {
                keyAlias = keystoreProperties["keyAlias"] as String
                keyPassword = keystoreProperties["keyPassword"] as String
                storeFile = file(keystoreProperties["storeFile"] as String)
                storePassword = keystoreProperties["storePassword"] as String
            }
        }
    }

    buildTypes {
        release {
            // **서명 키가 없으면 여기서 멈춘다.**
            //
            // 예전에는 없으면 조용히 디버그 키로 떨어졌다. 빌드는 성공하고
            // 파일도 나오는데 **스토어에 올릴 수 없는 물건**이다. 다른 PC에서
            // 빌드하거나 key.properties를 잃으면 그대로 사고가 된다.
            //
            // 릴리즈 빌드가 조용히 다른 것을 내놓느니 터지는 게 낫다.
            if (!keystorePropertiesFile.exists()) {
                throw GradleException(
                    "android/key.properties 가 없습니다. 릴리즈는 서명 키 없이 만들 수 없습니다.\n" +
                    "  (디버그 키로 만든 것은 스토어에 올라가지 않습니다)"
                )
            }
            signingConfig = signingConfigs.getByName("release")
            isMinifyEnabled = true
            isShrinkResources = true
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro"
            )
        }
    }
}

dependencies {
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")
}

flutter {
    source = "../.."
}
