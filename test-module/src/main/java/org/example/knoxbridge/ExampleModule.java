package org.example.knoxbridge;

import com.knoxbridge.api.KnoxModule;
import com.knoxbridge.api.ModuleContext;
import com.knoxbridge.api.PatchRegistrar;

public final class ExampleModule implements KnoxModule {
    @Override public void initialize(ModuleContext context) {
        context.logger().accept("independent example module ready id=" + context.moduleId());
        context.patches().register(new PatchRegistrar.Patch(
            "example.no-op-probe",
            new PatchRegistrar.Target("org.example.knoxbridge.GreetingFixture", "greeting", "()Ljava/lang/String;"),
            false,
            (name, bytes) -> bytes
        ));
    }
}
