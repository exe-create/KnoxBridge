# Patch API

Modules register a patch ID, exact class, method name, optional JVM descriptor, required/optional flag and byte transformer. Patches are attached to their registering module for diagnostics. Duplicate patch IDs or identical targets are rejected.

At class definition, a small class-file reader enumerates methods. A named target is accepted only when exactly one method matches; when a descriptor is present, it must match exactly. Missing or overloaded descriptor-less targets log an incompatibility and are skipped. The runtime never falls back to a guessed overload. A transformer exception is attributed to the owning module and does not crash PZ by itself.

The current core does not yet implement a bytecode advice library, parameter-supertype matching, alternative descriptors, patch dependency negotiation, retransformation reconciliation, or required-patch module blocking. Module authors provide the actual byte transform and are responsible for returning valid class bytes. Required/optional is currently diagnostic metadata; stronger load-time guarantees require lifecycle/status work and live PZ validation.
