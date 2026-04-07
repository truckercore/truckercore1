# ProGuard/R8 rules for Flutter + common SDKs
# Keep Flutter and Kotlin metadata
-keep class io.flutter.** { *; }
-keep class kotlin.** { *; }
-dontwarn kotlin.**

# Keep classes with @Keep
-keep @androidx.annotation.Keep class * { *; }
-keep class ** implements android.os.Parcelable { *; }

# Retrofit/OkHttp (if used)
-dontwarn okhttp3.**
-dontwarn okio.**
-dontwarn retrofit2.**
-keep class retrofit2.** { *; }
-keepattributes Signature

# Gson/Moshi (if used)
-keep class com.google.gson.** { *; }
-dontwarn com.google.gson.**
-keep class com.squareup.moshi.** { *; }
-dontwarn com.squareup.moshi.**

# ProGuard/R8 rules for Flutter + common SDKs
# Keep Flutter and Kotlin metadata
-keep class io.flutter.** { *; }
-keep class kotlin.** { *; }
-dontwarn kotlin.**

# Keep classes with @Keep
-keep @androidx.annotation.Keep class * { *; }
-keep class ** implements android.os.Parcelable { *; }

# Retrofit/OkHttp (if used)
-dontwarn okhttp3.**
-dontwarn okio.**
-dontwarn retrofit2.**
-keep class retrofit2.** { *; }
-keepattributes Signature

# Gson/Moshi (if used)
-keep class com.google.gson.** { *; }
-dontwarn com.google.gson.**
-keep class com.squareup.moshi.** { *; }
-dontwarn com.squareup.moshi.**

# Google Play Core (used indirectly by Flutter for deferred components)
-keep class com.google.android.play.** { *; }
-dontwarn com.google.android.play.**
