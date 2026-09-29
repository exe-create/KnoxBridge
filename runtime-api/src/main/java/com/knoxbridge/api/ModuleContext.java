package com.knoxbridge.api;

import java.lang.instrument.Instrumentation;
import java.util.function.Consumer;

public interface ModuleContext {
    String runtimeVersion();
    String moduleId();
    String moduleVersion();
    Consumer<String> logger();
    PatchRegistrar patches();
    /** JVM instrumentation for trusted modules that need runtime-specific adapters. */
    Instrumentation instrumentation();
}
