# ---------------------------------------------------------------------------
# R8 rules for the customer app.
#
# R8 only ever sees the Java/Kotlin bytecode. The Dart code lives in libapp.so
# and is obfuscated separately, via `flutter build --obfuscate`.
#
# Plugin entry points need no rules of their own: GeneratedPluginRegistrant is
# annotated @Keep and constructs every plugin directly, so R8 reaches them from
# there. Nearly every plugin also ships its own consumer rules inside its AAR,
# so this file deliberately stays small: it covers only the libraries that
# reach for their own classes reflectively and therefore cannot be renamed.
# ---------------------------------------------------------------------------

# Keep line numbers so Crashlytics and Play Console can still symbolicate
# release crashes, while letting R8 rename the source file itself.
-keepattributes SourceFile,LineNumberTable
-renamesourcefileattribute SourceFile

# Generic signatures and annotations must survive for reflective
# (de)serialisation to resolve types at runtime.
-keepattributes Signature,InnerClasses,EnclosingMethod
-keepattributes RuntimeVisibleAnnotations,RuntimeVisibleParameterAnnotations

# flutter_local_notifications rehydrates its own model classes through Gson
# when rescheduling notifications after a reboot. Renaming them breaks reboot
# rescheduling silently, at runtime, only on release builds.
-keep class com.dexterous.** { *; }

# Gson resolves generic types through TypeToken subclasses.
-keep class com.google.gson.reflect.TypeToken { *; }
-keep class * extends com.google.gson.reflect.TypeToken

# Firestore/RTDB map custom objects by reflecting over annotated members.
-keepclassmembers class * {
  @com.google.firebase.firestore.PropertyName <methods>;
  @com.google.firebase.database.PropertyName <methods>;
}

# image_cropper's UCropActivity is named from AndroidManifest.xml, which AGP
# already turns into a keep rule; its styles/options are resolved reflectively
# from the intent extras, so keep the library whole.
-keep class com.yalantis.ucrop.** { *; }
-dontwarn com.yalantis.ucrop.**

# Flutter references Play Core for deferred components, which this app does not
# use; without this R8 fails the build on the missing classes.
-dontwarn com.google.android.play.core.**

# Parcelize's compiler-only annotations are not on the runtime classpath.
-dontwarn kotlinx.android.parcel.**
-dontwarn kotlinx.parcelize.**
