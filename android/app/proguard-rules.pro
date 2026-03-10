# =============================================================================
# Flutter / Dart
# =============================================================================
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.** { *; }
-keep class io.flutter.util.** { *; }
-keep class io.flutter.view.** { *; }
-keep class io.flutter.** { *; }
-keep class io.flutter.plugins.** { *; }

# =============================================================================
# Google Mobile Ads (AdMob)
# =============================================================================
-keep class com.google.android.gms.ads.** { *; }
-dontwarn com.google.android.gms.ads.**

# =============================================================================
# RevenueCat (purchases-flutter)
# =============================================================================
-dontwarn com.amazon.**
-keep class com.amazon.** { *; }
-keepattributes *Annotation*
-keep class androidx.lifecycle.DefaultLifecycleObserver
-keep class org.xmlpull.v1.** { *; }

# =============================================================================
# Google Play Core (required for R8 compatibility with Flutter)
# =============================================================================
-dontwarn com.google.android.play.core.splitcompat.**
-dontwarn com.google.android.play.core.splitinstall.**
-dontwarn com.google.android.play.core.tasks.**

# =============================================================================
# General
# =============================================================================
-keepattributes Signature
-keepattributes *Annotation*
-keepattributes EnclosingMethod
-keepattributes InnerClasses
