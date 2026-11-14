# Flutter ProGuard / R8 Rules
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.**  { *; }
-keep class io.flutter.util.**  { *; }
-keep class io.flutter.view.**  { *; }
-keep class io.flutter.** { *; }
-keep class io.flutter.plugins.** { *; }

# Preserve Riverpod & Core annotations
-keepattributes *Annotation*
-dontwarn javax.annotation.**

# Preserve Flutter Secure Storage
-keep class androidx.security.crypto.** { *; }
-dontwarn androidx.security.crypto.**

# Preserve WebView
-keep class android.webkit.** { *; }
-dontwarn android.webkit.**

# Google Play Core deferred components suppression
-dontwarn com.google.android.play.core.**
-dontwarn com.google.android.play.core.splitcompat.**
-dontwarn com.google.android.play.core.splitinstall.**
-dontwarn com.google.android.play.core.tasks.**
