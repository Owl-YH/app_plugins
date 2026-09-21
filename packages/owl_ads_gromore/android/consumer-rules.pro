# The GroMore AAR already contributes its own official consumer rules. Keep the
# Flutter entry point and typed bridge names stable for registrants and Pigeon.
-keep class com.owlllwo.plugins.gromore.OwlAdsGromorePlugin { public <init>(); }
-keep class com.owlllwo.plugins.gromore.GroMoreHostApi { *; }
-keep class com.owlllwo.plugins.gromore.GroMoreFlutterApi { *; }

# The verified mediation AAR references these compile-time annotations and
# optional ByteDance components but does not distribute them. Current official
# integration requires OkHttp separately; these remaining warnings are narrowed
# to the exact classes reported by R8 for mediation-sdk 7.7.1.6.
-dontwarn com.bytedance.JProtect
-dontwarn com.bytedance.component.sdk.annotation.AnyThread
-dontwarn com.bytedance.component.sdk.annotation.CallSuper
-dontwarn com.bytedance.component.sdk.annotation.ColorInt
-dontwarn com.bytedance.component.sdk.annotation.DungeonFlag
-dontwarn com.bytedance.component.sdk.annotation.HungeonFlag
-dontwarn com.bytedance.component.sdk.annotation.IntRange
-dontwarn com.bytedance.component.sdk.annotation.Keep
-dontwarn com.bytedance.component.sdk.annotation.MainThread
-dontwarn com.bytedance.component.sdk.annotation.RawRes
-dontwarn com.bytedance.component.sdk.annotation.RequiresApi
-dontwarn com.bytedance.component.sdk.annotation.UiThread
-dontwarn com.bytedance.component.sdk.annotation.WorkerThread
-dontwarn com.bytedance.framwork.core.sdkmonitor.SDKMonitor$IGetExtendParams
-dontwarn com.bytedance.framwork.core.sdkmonitor.SDKMonitor
-dontwarn com.bytedance.framwork.core.sdkmonitor.SDKMonitorUtils
-dontwarn com.bytedance.keva.Keva
-dontwarn com.bytedance.keva.KevaBuilder
-dontwarn com.bytedance.keva.KevaMonitor
