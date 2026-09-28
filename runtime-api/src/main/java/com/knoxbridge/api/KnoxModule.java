package com.knoxbridge.api;

/** Entry point implemented by an approved KnoxBridge module. */
public interface KnoxModule {
    void initialize(ModuleContext context) throws Exception;

    default void shutdown() throws Exception { }
}
