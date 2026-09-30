import java.util.zip.ZipFile
import java.util.Properties

plugins {
    java
}

group = "org.example"
version = "1.0.0"

repositories { mavenCentral() }

java {
    toolchain.languageVersion.set(JavaLanguageVersion.of(17))
}

tasks.withType<JavaCompile>().configureEach {
    options.release.set(17)
    options.encoding = "UTF-8"
}

val knoxbridgeApiJar = providers.gradleProperty("knoxbridgeApiJar").orElse("lib/runtime-api.jar")
val apiProject = rootProject.findProject(":runtime-api")

dependencies {
    if (apiProject != null) compileOnly(apiProject) else compileOnly(files(knoxbridgeApiJar))
    compileOnly("org.ow2.asm:asm-tree:9.10.1")
}

tasks.jar {
    archiveFileName.set("minimal-module.jar")
}

tasks.register("verifyModulePackage") {
    group = "verification"
    description = "Checks the example module archive and its descriptor contract."
    dependsOn(tasks.jar)
    doLast {
        val jarFile = tasks.jar.get().archiveFile.get().asFile
        val expected = listOf(
            "org/example/mymod/MyModule.class",
            "org/example/mymod/GreetingPatch.class",
            "org/example/mymod/ExampleGreeting.class",
            "org/example/mymod/PzMethodInspector.class"
        )
        val moduleDescriptor = Properties().apply {
            project.file("knoxbridge.properties").inputStream().use(::load)
        }
        listOf("id", "version", "apiVersion", "entrypoint", "jar").forEach { key ->
            require(!moduleDescriptor.getProperty(key).isNullOrBlank()) { "Example descriptor is missing $key" }
        }
        require(moduleDescriptor.getProperty("apiVersion") == "1") { "Example API version is not supported" }
        require(moduleDescriptor.getProperty("jar") == "media/java/minimal-module.jar") {
            "Descriptor JAR path does not match the packaged module layout"
        }
        require(moduleDescriptor.getProperty("classLoader", "isolated") in setOf("isolated", "system")) {
            "Example descriptor classLoader is invalid"
        }
        ZipFile(jarFile).use { archive ->
            expected.forEach { entry -> require(archive.getEntry(entry) != null) { "Module package missing $entry" } }
            val entrypointClass = moduleDescriptor.getProperty("entrypoint").replace('.', '/') + ".class"
            require(archive.getEntry(entrypointClass) != null) { "Descriptor entrypoint is absent from the module JAR" }
            require(archive.entries().asSequence().none {
                it.name.startsWith("com/knoxbridge/api/") || it.name.startsWith("org/objectweb/asm/")
            }) { "Module JAR must not bundle KnoxBridge API or runtime-provided ASM classes" }
        }
        println("KnoxBridge author module package PASS path=${jarFile.absolutePath}")
    }
}

tasks.register<Sync>("stagePzMod") {
    group = "distribution"
    description = "Assembles the example as a ready-to-copy Project Zomboid mod directory."
    dependsOn("verifyModulePackage")
    into(layout.buildDirectory.dir("staged-mod/KnoxBridgeMinimalExample"))
    from("mod.info")
    from("mod.info") { into("42") }
    from("knoxbridge.properties") { into("42") }
    from(tasks.jar) { into("42/media/java") }
}

tasks.register<JavaExec>("inspectPzMethods") {
    group = "verification"
    description = "Lists exact method descriptors from a class in a local PZ JAR."
    dependsOn(tasks.classes)
    classpath = sourceSets.main.get().compileClasspath + sourceSets.main.get().runtimeClasspath + sourceSets.main.get().output
    mainClass.set("org.example.mymod.PzMethodInspector")
    doFirst {
        val pzJar = providers.gradleProperty("pzJar").orNull?.takeIf(String::isNotBlank)
            ?: throw GradleException("Pass -PpzJar=<path to projectzomboid.jar>")
        val targetClass = providers.gradleProperty("targetClass").orNull?.takeIf(String::isNotBlank)
            ?: throw GradleException("Pass -PtargetClass=<fully.qualified.ClassName>")
        val targetMethod = providers.gradleProperty("targetMethod").orNull?.takeIf(String::isNotBlank)
            ?: throw GradleException("Pass -PtargetMethod=<methodName>")
        args(pzJar, targetClass, targetMethod)
    }
}
