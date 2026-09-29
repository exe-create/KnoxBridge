package org.example.mymod;

import com.knoxbridge.api.KnoxModule;
import com.knoxbridge.api.ModuleContext;

public final class MyModule implements KnoxModule {
    @Override
    public void initialize(ModuleContext context) {
        context.logger().accept("ready module=" + context.moduleId());
    }
}
