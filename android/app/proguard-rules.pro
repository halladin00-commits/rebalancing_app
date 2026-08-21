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

# flutter_local_notifications — Gson으로 예약 알림을 직렬화한다.
# R8이 Signature 속성을 지우면 TypeToken이 제네릭 정보를 잃고
# "Missing type parameter."로 죽는다. 앱 업데이트·재부팅 직후에 터진다.
-keep class com.dexterous.** { *; }
-keepattributes Signature
-keepattributes *Annotation*
-keepattributes InnerClasses,EnclosingMethod

# Gson
-dontwarn com.google.gson.**
-keep class com.google.gson.** { *; }
-keep,allowobfuscation,allowshrinking class com.google.gson.reflect.TypeToken
-keep,allowobfuscation,allowshrinking class * extends com.google.gson.reflect.TypeToken
