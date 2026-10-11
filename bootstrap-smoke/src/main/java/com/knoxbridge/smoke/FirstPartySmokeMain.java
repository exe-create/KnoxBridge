package com.knoxbridge.smoke;

/** A real JVM/agent/module test, without initializing a world or calling it live gameplay. */
public final class FirstPartySmokeMain {
    public static void main(String[] args) throws Exception {
        boolean expectLoaded = Boolean.parseBoolean(args[0]);
        boolean loaded;
        try {
            Class<?> agent = Class.forName("com.knoxsurvivors.agent.KnoxAgent", false, ClassLoader.getSystemClassLoader());
            loaded = "knoxbridge".equals(agent.getMethod("getRuntimeSource").invoke(null));
        } catch (ClassNotFoundException absent) { loaded = false; }
        if (loaded != expectLoaded) throw new AssertionError("KnoxSurvivors loaded=" + loaded + " expected=" + expectLoaded);
        Class<?> utility = Class.forName("zombie.core.utils.UpdateLimit");
        Object ready = utility.getConstructor(long.class, long.class).newInstance(1000L, 10000L);
        Object waiting = utility.getConstructor(long.class).newInstance(Long.MAX_VALUE);
        int enters = PzHookCallbacks.entered, returns = PzHookCallbacks.returned;
        if (!Boolean.TRUE.equals(utility.getMethod("Check").invoke(ready))
                || !Boolean.FALSE.equals(utility.getMethod("Check").invoke(waiting)))
            throw new AssertionError("real PZ utility results changed");
        if (PzHookCallbacks.entered - enters != 2 || PzHookCallbacks.returned - returns != 2)
            throw new AssertionError("real PZ method entry/return callbacks missing");
        System.out.println("KnoxBridge first-party JVM integration PASS knoxLoaded=" + loaded
            + " realPzEntryReturn=true java=" + System.getProperty("java.version"));
    }
}
