# Patch API

Modules register a patch ID, target class, method name, optional JVM descriptor, required/optional flag and byte transformer. Patches are attached to their registering module for diagnostics. Duplicate patch IDs or identical targets are rejected. Register patches synchronously during `initialize` through `context.patches()`. The registration scope closes when initialization returns: later/asynchronous registrations fail, and if initialization throws, its pending patches are discarded.

At class definition, a small class-file reader enumerates methods; already-loaded registered targets may also be retransformed after module startup if the JVM supports it. `className` uses dotted Java names (for example, `zombie.SomeClass`), not a slash-separated class-file path. A JVM descriptor identifies the exact method signature, for example `()Ljava/lang/String;`; use the target game's actual method descriptor. A named target is accepted only when exactly one method matches; when a descriptor is present, it must match exactly. Missing or overloaded descriptor-less targets log an incompatibility and are skipped. The runtime never falls back to a guessed overload.

The transformer receives the dotted class name and original class-file bytes. It must return valid class-file bytes (return the input unchanged for a deliberate no-op). A thrown exception or invalid output is logged against the owning module, patch ID, and exact target; that transformation is not applied and does not by itself abort PZ. Missing/ambiguous method diagnostics include the target and reason. Duplicate targets and mismatches do not roll back other successful patches. Patches run as trusted Java code with the game's permissions.

For simple entry and normal-return callbacks, use `context.patches().registerHook`:

```java
context.patches().registerHook(new PatchRegistrar.Hook(
    "mymod.greeting", new PatchRegistrar.Target("game.SomeClass", "greeting", "()Ljava/lang/String;"),
    false, new PatchRegistrar.Callback("mymod.Hooks", "onEnter"),
    new PatchRegistrar.Callback("mymod.Hooks", "onReturn")));
```

Each callback must be a `public static void` method with no parameters in a public ordinary class. Either callback may be null. The runtime inserts the calls, preserves the original arguments, locals, frames and return value, and applies the existing target checks and registration ownership. Entry runs before the method body; return runs before each normal return. An exception leaving the method does **not** trigger `onReturn`. Constructors, class initializers, abstract and native methods are rejected. Callback exceptions propagate to the caller; authors must handle their own expected callback failures. Callbacks must be visible from the transformed class's loader: for PZ targets calling module helpers, use the existing `classLoader=system` policy. Do not assume an isolated module's helpers are visible to PZ. A callback in an interface is not supported by this convenience API.

The raw `register(Patch)` API remains available for argument/result access, exceptional exits, or other advanced transformations. With ASM, insert instructions at method entry using `method.instructions.insert(...)`, or before return opcodes for normal exit. Keep helpers public and resolvable from the target loader, preserve stack state, and recompute frames when control flow changes. The example now uses `registerHook` and retains its manual ASM transform for reference. Its printed messages demonstrate fixture bytecode only; they are not a PZ compatibility guarantee.

The convenience API is smaller than Byte Buddy Advice: it has no annotations, argument/result binding, exceptional-exit callback, or result replacement. The core also does not provide parameter-supertype matching, alternative descriptors, patch dependency negotiation, retransformation reconciliation, or required-patch module blocking. Authors of raw transforms remain responsible for valid bytecode. `required` is diagnostic metadata only: a missing/failed required patch does not block the module or game startup.

Callback visibility and shape are checked using the target class loader before applying the hook. An invisible or invalid helper produces a patch failure and retains the original target bytes. Keep callback helpers in a separate class from the target to avoid recursive class loading during transformation.

`registerHook` is a binary-compatible API-1 addition for existing modules. New modules using it need this updated runtime. An older registrar paired with the new API throws an unsupported operation; a runtime supplying the older API can raise a linkage error during initialization. Neither silently supplies the new hook.

`examples/minimal-module` contains a complete ASM-based transformation of a harmless fixture method and a local PZ method-descriptor inspector. It compiles against the documented ASM 9.10.1 toolkit as `compileOnly`; the matching runtime agent supplies that version, so module packages should not embed duplicate ASM classes. Start with this fixture, inspect exact target signatures in the target PZ build, and live-test real transformations in a disposable game profile. The independent `test-module` also exercises the engine's module attribution and transformed-byte verification; neither fixture establishes compatibility with a PZ method.
