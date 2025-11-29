# Flutter Wrapper
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.**  { *; }
-keep class io.flutter.util.**  { *; }
-keep class io.flutter.view.**  { *; }
-keep class io.flutter.**  { *; }
-keep class io.flutter.plugins.**  { *; }
-keep class io.flutter.embedding.** { *; }

# Firebase
-keep class com.google.firebase.** { *; }
-keep class com.google.android.gms.** { *; }
-dontwarn com.google.firebase.**
-dontwarn com.google.android.gms.**

# Google Play Core (for deferred components - keep even if not used)
-keep class com.google.android.play.core.** { *; }
-dontwarn com.google.android.play.core.**

# Preserve line number information for debugging stack traces
-keepattributes SourceFile,LineNumberTable

# Hide the original source file name
-renamesourcefileattribute SourceFile
