# Flutter wrapper
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.**  { *; }
-keep class io.flutter.util.**  { *; }
-keep class io.flutter.view.**  { *; }
-keep class io.flutter.**  { *; }
-keep class io.flutter.plugins.**  { *; }

# Google Mobile Ads
-keep class com.google.android.gms.ads.** { *; }

# Play Billing
-keep class com.android.vending.billing.** { *; }

# Firebase / Firestore models use reflection.
-keepattributes Signature
-keepattributes *Annotation*
-keep class com.google.firebase.** { *; }
