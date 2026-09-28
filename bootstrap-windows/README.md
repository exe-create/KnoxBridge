# Windows bootstrap

`knoxbridge-bootstrap.dll` is a small independent JVM native agent. Its only startup task is to add the installed PZ JRE's `jre64\bin` directory to Windows DLL dependency lookup before the Java instrumentation agent loads. This addresses the Windows wrapper smoke failure where `ProjectZomboid64.exe` could not initialize `instrument.dll`, even though the bundled `java.exe -javaagent` path worked.

Build it with `powershell -ExecutionPolicy Bypass -File scripts/build-windows-bootstrap.ps1`. The build requires Visual Studio's x64 C++ tools. The installer places the DLL at `<PZ>\.knoxbridge\knoxbridge-bootstrap.dll` and adds its `-agentpath` argument before the Java agent argument. The native code resolves the game root from its own installed path and does not modify global environment variables or registry state.

This helper has not yet been built and exercised through the PZ launcher fixture. Its source and installer integration remain offline implementation until that test passes.
