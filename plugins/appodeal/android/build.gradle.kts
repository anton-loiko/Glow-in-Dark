// Тонкая обёртка Appodeal SDK для Godot 4 (D17). Собирает AAR; адаптеры медиации подключаются
// при экспорте игры (addons/glow_appodeal/export_plugin.gd → android_dependencies.txt), не здесь.
plugins {
    id("com.android.library") version "8.13.2"
    id("org.jetbrains.kotlin.android") version "2.4.0"
}

val appodealVersion = "4.3.0"

android {
    namespace = "com.glowinthedark.appodeal"
    compileSdk = 36

    defaultConfig {
        minSdk = 26
        consumerProguardFiles("consumer-rules.pro")
    }

    buildTypes {
        getByName("release") {
            isMinifyEnabled = false
        }
    }

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    kotlin {
        compilerOptions {
            jvmTarget = org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17
        }
    }
}

dependencies {
    compileOnly("org.godotengine:godot:4.7.2.stable")
    compileOnly("com.appodeal.ads.sdk:core:$appodealVersion")
}

// Копирует собранный AAR в аддон проекта.
tasks.register<Copy>("installToAddon") {
    dependsOn("assembleRelease", "assembleDebug")
    from(layout.buildDirectory.dir("outputs/aar"))
    include("*-release.aar", "*-debug.aar")
    rename("(.*)-(release|debug).aar", "GlowAppodeal.$2.aar")
    into(rootProject.file("../../../addons/glow_appodeal/bin"))
}
