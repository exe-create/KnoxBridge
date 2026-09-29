plugins { base }

allprojects {
    group = "com.knoxbridge"
    version = "0.1.0-alpha5"
    repositories { mavenCentral() }
}

subprojects {
    plugins.withId("java") {
        extensions.configure<org.gradle.api.plugins.JavaPluginExtension> {
            toolchain.languageVersion.set(org.gradle.jvm.toolchain.JavaLanguageVersion.of(17))
        }
        tasks.withType<JavaCompile>().configureEach {
            options.encoding = "UTF-8"
            options.release.set(17)
        }
    }
}

tasks.register("verify") {
    dependsOn(":runtime-core:verifyRuntime", ":runtime-core:jar", ":bootstrap-smoke:jar", "stageExampleMod", "writeChecksums")
    if (System.getProperty("os.name").lowercase().contains("windows")) dependsOn("buildWindowsBootstrap")
}

tasks.register<Exec>("buildWindowsBootstrap") {
    group = "build"
    inputs.file(layout.projectDirectory.file("bootstrap-windows/src/knoxbridge_bootstrap.cpp"))
    inputs.file(layout.projectDirectory.file("scripts/build-windows-bootstrap.ps1"))
    outputs.file(layout.projectDirectory.file("bootstrap-windows/build/knoxbridge-bootstrap.dll"))
    doFirst {
        if (!System.getProperty("os.name").lowercase().contains("windows")) {
            throw GradleException("The Windows package requires the Visual Studio x64 native build toolchain.")
        }
    }
    commandLine("powershell", "-ExecutionPolicy", "Bypass", "-File", file("scripts/build-windows-bootstrap.ps1").absolutePath)
}
val stageExampleMod by tasks.registering {
    dependsOn(":test-module:jar")
    val output = layout.buildDirectory.dir("staged-example/KnoxBridgeIndependentTest")
    outputs.dir(output)
    doLast {
        val root = output.get().asFile
        root.mkdirs()
        root.resolve("mod.info").writeText("name=KnoxBridge Independent Test Module\nid=KnoxBridgeIndependentTest\ndescription=Harmless standalone KnoxBridge module fixture.\n")
        val build42 = root.resolve("42")
        build42.resolve("media/java").mkdirs()
        build42.resolve("mod.info").writeText("name=KnoxBridge Independent Test Module\nid=KnoxBridgeIndependentTest\ndescription=Harmless standalone KnoxBridge module fixture.\n")
        build42.resolve("knoxbridge.properties").writeText("id=org.example.knoxbridge.greeting\nversion=1.0.0\napiVersion=1\nentrypoint=org.example.knoxbridge.ExampleModule\njar=media/java/knoxbridge-example-module.jar\n")
        project(":test-module").layout.buildDirectory.file("libs/knoxbridge-example-module-${project.version}.jar").get().asFile.copyTo(
            build42.resolve("media/java/knoxbridge-example-module.jar"), overwrite = true)
    }
}

val writeChecksums by tasks.registering {
    dependsOn(":runtime-core:jar", ":test-module:jar")
    if (System.getProperty("os.name").lowercase().contains("windows")) dependsOn("buildWindowsBootstrap")
    doLast {
        val artifacts = mutableListOf(
            project(":runtime-core").layout.buildDirectory.file("libs/knoxbridge-agent-${project.version}.jar").get().asFile,
            project(":runtime-api").layout.buildDirectory.file("libs/runtime-api-${project.version}.jar").get().asFile,
            project(":test-module").layout.buildDirectory.file("libs/knoxbridge-example-module-${project.version}.jar").get().asFile
        )
        if (System.getProperty("os.name").lowercase().contains("windows")) {
            artifacts.add(layout.projectDirectory.file("bootstrap-windows/build/knoxbridge-bootstrap.dll").asFile)
        }
        artifacts.forEach { jar ->
            val digest = java.security.MessageDigest.getInstance("SHA-256").digest(jar.readBytes())
                .joinToString("") { "%02x".format(it) }
            jar.resolveSibling(jar.name + ".sha256").writeText("$digest  ${jar.name}\n")
        }
    }
}

tasks.register<Zip>("packageRuntime") {
    dependsOn("verify", "stageExampleMod", "writeChecksums")
    if (System.getProperty("os.name").lowercase().contains("windows")) dependsOn("buildWindowsBootstrap")
    archiveBaseName.set("knoxbridge-runtime")
    archiveVersion.set(project.version.toString())
    destinationDirectory.set(layout.buildDirectory.dir("distributions"))
    from(project(":runtime-core").layout.buildDirectory.dir("libs")) { include("knoxbridge-agent-${project.version}.jar*") }
    from(project(":runtime-api").layout.buildDirectory.dir("libs")) { include("runtime-api-${project.version}.jar*") }
    from(project(":test-module").layout.buildDirectory.dir("libs")) { include("knoxbridge-example-module-${project.version}.jar*") }
    from(layout.buildDirectory.dir("staged-example")) { into("example-mod") }
    from("scripts") { into("scripts") }
    from("KnoxBridge Setup.cmd")
    from(layout.projectDirectory.file("bootstrap-windows/build/knoxbridge-bootstrap.dll")) { into("bootstrap-windows") }
    from(layout.projectDirectory.file("bootstrap-windows/build/knoxbridge-bootstrap.dll.sha256")) { into("bootstrap-windows") }
    from("bootstrap-windows/src/knoxbridge_bootstrap.cpp") { into("bootstrap-windows/src") }
    from("bootstrap-windows/README.md") { into("bootstrap-windows") }
    from("docs") { into("docs") }
    from("THIRD_PARTY_NOTICES.md")
    from("LICENSE")
    from("README.md")
}

tasks.register<Zip>("packageManualInstaller") {
    group = "distribution"
    description = "Builds the player setup package for Windows, Linux, and macOS."
    dependsOn(":runtime-core:jar", "writeChecksums")
    if (System.getProperty("os.name").lowercase().contains("windows")) dependsOn("buildWindowsBootstrap")
    archiveBaseName.set("KnoxBridgeRuntime")
    archiveVersion.set(project.version.toString())
    destinationDirectory.set(layout.buildDirectory.dir("distributions"))
    from(project(":runtime-core").layout.buildDirectory.dir("libs")) {
        include("knoxbridge-agent-${project.version}.jar", "knoxbridge-agent-${project.version}.jar.sha256")
    }
    from(layout.projectDirectory.file("bootstrap-windows/build/knoxbridge-bootstrap.dll")) {
        into("bootstrap-windows")
    }
    from(layout.projectDirectory.file("bootstrap-windows/build/knoxbridge-bootstrap.dll.sha256")) {
        into("bootstrap-windows")
    }
    from("scripts") {
        include("setup-unix.sh", "setup-unix.py")
        into("scripts")
    }
    from(files("docs/INSTALLATION.md", "docs/RELEASE_NOTES.md")) { into("docs") }
    from("THIRD_PARTY_NOTICES.md")
    from("LICENSE")
    from("README.md")
}

tasks.register<Exec>("buildWindowsInstaller") {
    group = "distribution"
    description = "Builds the self-contained .NET KnoxBridge Windows setup application with the player package embedded."
    dependsOn("packageManualInstaller")
    inputs.file(layout.projectDirectory.file("windows-installer/Program.cs"))
    inputs.file(layout.projectDirectory.file("windows-installer/KnoxBridge.Installer.csproj"))
    inputs.file(layout.buildDirectory.file("distributions/KnoxBridgeRuntime-${project.version}.zip"))
    outputs.file(layout.projectDirectory.file("bootstrap-windows/build/KnoxBridgeSetup.exe"))
    doFirst {
        if (!System.getProperty("os.name").lowercase().contains("windows")) {
            throw GradleException("The standalone Windows installer must be built with the Windows x64 toolchain.")
        }
    }
    commandLine(
        "dotnet", "publish", file("windows-installer/KnoxBridge.Installer.csproj").absolutePath,
        "--configuration", "Release", "--runtime", "win-x64", "--self-contained", "true",
        "-p:PublishSingleFile=true", "-p:IncludeNativeLibrariesForSelfExtract=true",
        "-p:DebugType=None", "-p:DebugSymbols=false",
        "-p:PayloadPath=${layout.buildDirectory.file("distributions/KnoxBridgeRuntime-${project.version}.zip").get().asFile.absolutePath}",
        "--output", layout.projectDirectory.dir("bootstrap-windows/build").asFile.absolutePath
    )
}
