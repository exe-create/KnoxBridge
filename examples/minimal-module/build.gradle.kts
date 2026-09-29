plugins {
    java
}

group = "org.example"
version = "1.0.0"

java {
    toolchain.languageVersion.set(JavaLanguageVersion.of(17))
}

tasks.withType<JavaCompile>().configureEach {
    options.release.set(17)
    options.encoding = "UTF-8"
}

val knoxbridgeApiJar = providers.gradleProperty("knoxbridgeApiJar")
    .orElse("lib/runtime-api.jar")

dependencies {
    compileOnly(files(knoxbridgeApiJar))
}

tasks.jar {
    archiveFileName.set("minimal-module.jar")
}
