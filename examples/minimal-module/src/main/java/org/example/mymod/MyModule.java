package org.example.mymod;

import com.knoxbridge.api.KnoxModule;
import com.knoxbridge.api.ModuleContext;
import com.knoxbridge.api.PatchRegistrar;

public final class MyModule implements KnoxModule {
    @Override
    public void initialize(ModuleContext context) {
        context.logger().accept("ready module=" + context.moduleId());
        context.patches().registerHook(new PatchRegistrar.Hook(
            "example.greeting-advice",
            new PatchRegistrar.Target("org.example.mymod.ExampleGreeting", "greeting", "()Ljava/lang/String;"),
            false,
            new PatchRegistrar.Callback("org.example.mymod.GreetingPatch", "onEnter"),
            new PatchRegistrar.Callback("org.example.mymod.GreetingPatch", "onReturn")
        ));
    }
}
