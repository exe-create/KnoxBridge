# Module API

Modules compile against the separately versioned `runtime-api` JAR and implement `com.knoxbridge.api.KnoxModule`. They are initialized once after metadata, API version, JAR digest and user trust have passed. Initialization receives a `ModuleContext` with runtime/module versions, a diagnostic logger and `PatchRegistrar`. `shutdown()` is called during orderly JVM shutdown.

The adjacent `knoxbridge.properties` descriptor currently accepts:

```properties
id=org.example.module
version=1.0.0
apiVersion=1
entrypoint=org.example.module.Entry
jar=media/java/example.jar
```

The JAR path must resolve inside the mod root, including after symlinks are resolved. A missing descriptor means the mod is not a Java module. A malformed descriptor is incompatible and reported. The descriptor does not yet contain PZ build ranges or signatures; those require explicit API design and tests before use.

`test-module` demonstrates module initialization and registration of one optional patch probe without importing Knox Survivors.
