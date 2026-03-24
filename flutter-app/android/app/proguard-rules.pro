-keep class io.flutter.**              { *; }
-keep class de.blinkt.openvpn.**       { *; }
-keep class net.openvpn.**             { *; }
-keep class com.mohitw.marianavpn.**   { *; }
-keep class kotlin.**                  { *; }
-dontwarn kotlin.**
-dontwarn de.blinkt.openvpn.**

# Strip debug logs from release build (safe — no functionality change)
-assumenosideeffects class android.util.Log {
    public static int d(...);
    public static int v(...);
}
