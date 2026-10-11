plugins { java }
dependencies { compileOnly(project(":runtime-api")) }
tasks.jar { archiveFileName.set("bootstrap-smoke.jar") }
