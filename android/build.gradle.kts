// android/build.gradle.kts (TOP-LEVEL PROJECT BUILD.GRADLE)

// REMOVE THIS LINE: val kotlin_version: String by extra("2.0.21")

buildscript {
    // Define Kotlin version directly within buildscript for its dependencies
    val kotlin_version = "2.0.21" // Correct way to define a local variable in Kotlin DSL

    repositories {
        google()
        mavenCentral()
    }
    dependencies {
        // Essential Android Gradle Plugin
        classpath("com.android.tools.build:gradle:8.12.0") // Or the version you decided on
        // Kotlin Gradle Plugin - now uses the local kotlin_version
        classpath("org.jetbrains.kotlin:kotlin-gradle-plugin:$kotlin_version")
        // Firebase Google Services plugin classpath
        classpath("com.google.gms:google-services:4.4.3")
    }
}

// Your existing allprojects, rootProject.layout.buildDirectory, etc. go here.

allprojects {
    repositories {
        google()
        mavenCentral()
    }
}

val newBuildDir: org.gradle.api.file.Directory = rootProject.layout.buildDirectory.dir("../../build").get()
rootProject.layout.buildDirectory.value(newBuildDir)

subprojects {
    val newSubprojectBuildDir: org.gradle.api.file.Directory = newBuildDir.dir(project.name)
    project.layout.buildDirectory.value(newSubprojectBuildDir)

    afterEvaluate {
        if (project.plugins.hasPlugin("android") || project.plugins.hasPlugin("android.library")) {
            val androidExtension = project.extensions.findByType(com.android.build.gradle.BaseExtension::class.java)
            androidExtension?.let {
                if (it is com.android.build.gradle.AppExtension) {
                    it.compileSdkVersion(35) // Or whatever your target SDK is
                } else if (it is com.android.build.gradle.LibraryExtension) {
                    it.compileSdkVersion(35) // Or whatever your target SDK is
                }
            }
        }
    }
}
subprojects {
    project.evaluationDependsOn(":app")
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}