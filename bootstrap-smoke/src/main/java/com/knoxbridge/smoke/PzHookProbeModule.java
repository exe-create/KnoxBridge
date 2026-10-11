package com.knoxbridge.smoke;

import com.knoxbridge.api.KnoxModule;
import com.knoxbridge.api.ModuleContext;
import com.knoxbridge.api.PatchRegistrar;

/** Disposable probe only: observes a real, deterministic PZ utility method. */
public final class PzHookProbeModule implements KnoxModule {
    @Override public void initialize(ModuleContext context) {
        context.patches().registerHook(new PatchRegistrar.Hook("probe.pz-update-limit",
            new PatchRegistrar.Target("zombie.core.utils.UpdateLimit", "Check", "()Z"), false,
            new PatchRegistrar.Callback(PzHookCallbacks.class.getName(), "onEnter"),
            new PatchRegistrar.Callback(PzHookCallbacks.class.getName(), "onReturn")));
    }
}
