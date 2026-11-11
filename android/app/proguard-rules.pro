# Flutter / Firestore ProGuard Rules
-keepattributes *Annotation*,Signature,InnerClasses,EnclosingMethod

# Keep Firebase Firestore and Guava / Gson TypeToken
-keep class com.google.firebase.firestore.** { *; }
-keep class com.google.common.reflect.** { *; }
-keep class com.google.gson.reflect.** { *; }
-keep class * extends com.google.gson.reflect.TypeToken
-keep class * extends com.google.common.reflect.TypeToken

# Keep model fields and serializable classes
-keepclassmembers class * {
    @com.google.firebase.firestore.PropertyName <fields>;
    @com.google.firebase.firestore.PropertyName <methods>;
}
