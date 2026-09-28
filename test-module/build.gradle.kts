plugins { java }
dependencies { compileOnly(project(":runtime-api")) }
tasks.jar { archiveBaseName.set("knoxbridge-example-module") }
