plugins { java }

dependencies {
    implementation(project(":runtime-api"))
    implementation("org.ow2.asm:asm:9.10.1")
    implementation("org.ow2.asm:asm-tree:9.10.1")
}

tasks.jar {
    archiveBaseName.set("knoxbridge-agent")
    // The shaded runtimeClasspath is resolved inside from{}, which otherwise
    // hides the API JAR's build dependency from Gradle during clean builds.
    dependsOn(":runtime-api:jar")
    duplicatesStrategy = DuplicatesStrategy.EXCLUDE
    from({ configurations.runtimeClasspath.get().map { if (it.isDirectory) it else zipTree(it) } })
    manifest {
        attributes(
            "Premain-Class" to "com.knoxbridge.runtime.KnoxBridgeAgent",
            "Agent-Class" to "com.knoxbridge.runtime.KnoxBridgeAgent",
            "Can-Redefine-Classes" to "true",
            "Can-Retransform-Classes" to "true",
            "Implementation-Title" to "KnoxBridge Runtime",
            "Implementation-Version" to project.version
        )
    }
}

tasks.register<JavaExec>("verifyRuntime") {
    group = "verification"
    dependsOn(tasks.testClasses, ":test-module:jar", ":examples:minimal-module:jar")
    classpath = sourceSets.test.get().runtimeClasspath
    mainClass.set("com.knoxbridge.runtime.RuntimeVerifier")
    systemProperty("knoxbridge.testModuleJar", project(":test-module").layout.buildDirectory.file("libs/knoxbridge-example-module-${project.version}.jar").get().asFile.absolutePath)
    systemProperty("knoxbridge.authorExampleJar", project(":examples:minimal-module").layout.buildDirectory.file("libs/minimal-module.jar").get().asFile.absolutePath)
}

tasks.register<JavaExec>("verifyPzApi") {
    group = "verification"
    dependsOn(tasks.classes)
    classpath = sourceSets.main.get().runtimeClasspath
    mainClass.set("com.knoxbridge.runtime.PzApiVerifier")
    doFirst {
        val pzJar = project.findProperty("pzJar")?.toString().orEmpty()
        require(pzJar.isNotBlank()) { "Pass -PpzJar=<path to projectzomboid.jar>" }
        args(pzJar)
    }
}
