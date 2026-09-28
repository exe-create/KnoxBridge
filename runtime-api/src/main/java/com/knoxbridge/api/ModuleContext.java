package com.knoxbridge.api;

import java.util.function.Consumer;

public interface ModuleContext {
    String runtimeVersion();
    String moduleId();
    String moduleVersion();
    Consumer<String> logger();
    PatchRegistrar patches();
}
