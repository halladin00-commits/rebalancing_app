# Flutter
-keep class io.flutter.** { *; }
-keep class io.flutter.plugins.** { *; }

# Google Mobile Ads
-keep class com.google.android.gms.ads.** { *; }
-keep class com.google.ads.** { *; }

# Google Play Services
-keep class com.google.android.gms.** { *; }

# Play Core (deferred components - R8 missing class 오류 방지)
-dontwarn com.google.android.play.core.**
-keep class com.google.android.play.core.** { *; }
