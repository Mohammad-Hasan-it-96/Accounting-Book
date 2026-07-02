# قواعد إبقاء ProGuard/R8 لنسخة الإصدار.
#
# ملاحظة: التصغير/التعتيم (isMinifyEnabled) مُعطَّل حالياً في build.gradle.kts،
# لذا هذه القواعد خامدة إلى أن يُفعَّل R8. تركناها مُهيّأة مسبقاً حتى لا ينكسر
# الإصدار (أعطال reflection) لحظة تفعيل التصغير.

# ─── Flutter engine ──────────────────────────────────────────────────────────
-keep class io.flutter.** { *; }
-keep class io.flutter.plugins.** { *; }
-keep class io.flutter.embedding.** { *; }
-dontwarn io.flutter.**

# ─── WorkManager (نُفّذ عبر عزلة الخلفية callbackDispatcher) ──────────────────
-keep class androidx.work.** { *; }
-keep class * extends androidx.work.Worker { *; }
-keep class * extends androidx.work.ListenableWorker { *; }
-dontwarn androidx.work.**

# ─── local_auth (المصادقة البيومترية عبر FragmentActivity) ───────────────────
-keep class androidx.biometric.** { *; }
-keep class androidx.fragment.app.** { *; }
-dontwarn androidx.biometric.**

# ─── sqflite ─────────────────────────────────────────────────────────────────
-keep class com.tekartik.sqflite.** { *; }
-dontwarn com.tekartik.sqflite.**

# ─── flutter_secure_storage (يعتمد على AndroidX Security/Keystore) ───────────
-keep class androidx.security.crypto.** { *; }
-dontwarn androidx.security.crypto.**

# ─── pdf / printing ──────────────────────────────────────────────────────────
-keep class net.nfet.** { *; }
-dontwarn net.nfet.**

# ─── share_plus / file_picker (عبر channels + reflection على بعض الأجهزة) ────
-keep class dev.fluttercommunity.plus.share.** { *; }
-keep class com.mr.flutter.plugin.filepicker.** { *; }
-dontwarn com.mr.flutter.plugin.filepicker.**

# ─── إبقاء أسماء الأنواع/التواقيع العامّة المطلوبة للـ reflection ─────────────
-keepattributes *Annotation*
-keepattributes Signature
-keepattributes InnerClasses
-keepattributes EnclosingMethod

# النماذج (models) تُبنى عبر fromMap/toMap يدوياً لا عبر reflection، فلا حاجة
# لإبقائها؛ نُبقي فقط ما تتطلبه الحزم أعلاه.
