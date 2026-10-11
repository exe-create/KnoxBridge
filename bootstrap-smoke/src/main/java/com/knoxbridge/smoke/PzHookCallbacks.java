package com.knoxbridge.smoke;

public final class PzHookCallbacks {
    public static int entered, returned;
    public static void onEnter() { entered++; }
    public static void onReturn() { returned++; }
}
