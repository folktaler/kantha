import java.util.Properties

plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

// The upload key's details, from android/key.properties (never committed). Flutter's steps: docs.flutter.dev/deployment/android.
val keystoreProperties = Properties()
val keystorePropertiesFile = rootProject.file("key.properties")
if (keystorePropertiesFile.exists()) {
    keystorePropertiesFile.inputStream().use { keystoreProperties.load(it) }
}
// Without the file, Gradle's own failure is a bare NullPointerException; say what is missing instead.
// The tasks that sign with the release config, for every release variant (a flavour's too): the
// bundle, the APK, the universal APK and the APK set made from the bundle.
// Not validateSigningRelease: AGP leaves it out of the graph when the config has no storeFile,
// which is exactly the case without key.properties.
val releaseSigningTasks = mutableListOf<String>()
androidComponents {
    onVariants(selector().withBuildType("release")) { variant ->
        val v = variant.name.replaceFirstChar { it.uppercase() }
        releaseSigningTasks += listOf("sign${v}Bundle", "package$v", "package${v}UniversalApk", "makeApkFromBundleFor$v")
    }
}
gradle.taskGraph.whenReady {
    val signsRelease = releaseSigningTasks.any { hasTask("${project.path}:$it") }
    if (signsRelease && !keystorePropertiesFile.exists()) {
        throw GradleException(
            "No ${keystorePropertiesFile.path}: a release build is signed with the upload key only. " +
                "See docs.flutter.dev/deployment/android.",
        )
    }
}

android {
    namespace = "app.kantha.studio"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        applicationId = "app.kantha.studio"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        // Uses the version code from pubspec.yaml. When using split APKs, 1000 * ABI_VERSION
        // is added automatically by Flutter. (https://developer.android.com/studio/build/configure-apk-splits#configure-APK-versions)
        // You can force using the value of versionCode by specifying the `-P force-version-code-ignoring-abi=true`
        // flag during build.
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        create("release") {
            keyAlias = keystoreProperties.getProperty("keyAlias")
            keyPassword = keystoreProperties.getProperty("keyPassword")
            storeFile = keystoreProperties.getProperty("storeFile")?.let { file(it) }
            storePassword = keystoreProperties.getProperty("storePassword")
        }
    }
    buildTypes {
        release {
            // Signed with the upload key only. Without key.properties the release build stops,
            // rather than signing with the debug key, which Play refuses.
            signingConfig = signingConfigs.getByName("release")
        }
    }
}

kotlin {
    compilerOptions {
        jvmTarget = org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17
    }
}

flutter {
    source = "../.."
}
