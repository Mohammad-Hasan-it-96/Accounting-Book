import java.util.Properties
import java.io.FileInputStream

plugins {
    id("com.android.application")
    id("kotlin-android")
    id("dev.flutter.flutter-gradle-plugin")
}

val keyPropertiesFile = rootProject.file("key.properties")
val keyProperties = Properties()
if (keyPropertiesFile.exists()) {
    keyProperties.load(FileInputStream(keyPropertiesFile))
}

android {
    namespace = "com.mohamad.daftarhesabat"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_17.toString()
    }

    signingConfigs {
        if (keyPropertiesFile.exists()) {
            create("release") {
                keyAlias = keyProperties["keyAlias"] as String
                keyPassword = keyProperties["keyPassword"] as String
                storeFile = file(keyProperties["storeFile"] as String)
                storePassword = keyProperties["storePassword"] as String
            }
        }
    }

    defaultConfig {
        applicationId = "com.mohamad.daftarhesabat"
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    buildTypes {
        release {
            // نستخدم مفتاح الإصدار فقط. لا نوقّع الإصدار بمفتاح التصحيح إطلاقاً.
            signingConfig = if (keyPropertiesFile.exists()) {
                signingConfigs.getByName("release")
            } else {
                null
            }
            // التصغير/التعتيم مُعطَّل حالياً. عند تفعيله لاحقاً، قواعد الإبقاء
            // في proguard-rules.pro جاهزة كي لا تنكسر الحزم المعتمدة على reflection.
            isMinifyEnabled = false
            isShrinkResources = false
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro",
            )
        }
    }
}

// أوقِف بناء الإصدار بوضوح إذا لم يكن مفتاح التوقيع مُهيّأً، بدل توقيعه صامتاً
// بمفتاح التصحيح (وهو ما يرفضه Google Play). بناء التصحيح لا يتأثر.
if (!keyPropertiesFile.exists()) {
    val buildingRelease = gradle.startParameter.taskNames.any { requested ->
        val name = requested.substringAfterLast(':')
        name.contains("Release", ignoreCase = true) &&
            (name.startsWith("assemble") ||
                name.startsWith("bundle") ||
                name.startsWith("package"))
    }
    if (buildingRelease) {
        throw GradleException(
            "التوقيع للإصدار غير مُهيّأ. أنشئ ملف android/key.properties " +
                "(keyAlias/keyPassword/storeFile/storePassword) قبل بناء نسخة الإصدار. " +
                "تم رفض توقيع الإصدار بمفتاح التصحيح."
        )
    }
}

flutter {
    source = "../.."
}
