plugins { java }
dependencies {
    compileOnly(project(":runtime-api"))
    compileOnly("org.ow2.asm:asm-tree:9.10.1")
}
tasks.jar { archiveBaseName.set("knoxbridge-example-module") }
