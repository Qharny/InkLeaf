allprojects {
    repositories {
        google()
        mavenCentral()
    }
}

val newBuildDir: Directory =
    rootProject.layout.buildDirectory
        .dir("../../build")
        .get()
rootProject.layout.buildDirectory.value(newBuildDir)

subprojects {
    val newSubprojectBuildDir: Directory = newBuildDir.dir(project.name)
    project.layout.buildDirectory.value(newSubprojectBuildDir)
}
subprojects {
    project.evaluationDependsOn(":app")
}

// receive_sharing_intent asks for compileSdk 37, but SDK platforms now ship
// as "37.0", "37.1", ..., so a plain 37 can't be found. The plugin only uses
// APIs up to 33, so it is built against 36 instead.
subprojects {
    if (name == "receive_sharing_intent") {
        plugins.withId("com.android.library") {
            extensions
                .getByType<com.android.build.api.variant.LibraryAndroidComponentsExtension>()
                .finalizeDsl { it.compileSdk = 36 }
        }
    }
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
