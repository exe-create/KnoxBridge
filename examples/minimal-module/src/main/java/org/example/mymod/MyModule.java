package org.example.mymod;

import com.knoxbridge.api.KnoxModule;
import com.knoxbridge.api.ModuleContext;
import com.knoxbridge.api.PatchRegistrar;

public final class MyModule implements KnoxModule {
    @Override
    public void initialize(ModuleContext context) {
        context.logger().accept("ready module=" + context.moduleId());
        context.patches().register(new PatchRegistrar.Patch(
            "example.replace-greeting",
            new PatchRegistrar.Target("org.example.mymod.ExampleGreeting", "greeting", "()Ljava/lang/String;"),
            false,
            GreetingPatch::replaceGreeting
        ));
    }
}
