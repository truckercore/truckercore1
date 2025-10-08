plugins {
    id("com.github.ben-manes.versions")
}

// repositories are managed in settings.gradle.kts via dependencyResolutionManagement
// keep only the clean task here

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
