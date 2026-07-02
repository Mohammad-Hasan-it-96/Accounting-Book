package com.mohamad.daftarhesabat

import android.os.Bundle
import android.view.WindowManager
import io.flutter.embedding.android.FlutterFragmentActivity

// FlutterFragmentActivity is required for local_auth biometric support
class MainActivity : FlutterFragmentActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        // FLAG_SECURE: يمنع ظهور محتوى التطبيق (الأرصدة وبيانات العملاء) في لقطة
        // مبدّل التطبيقات (recents) ويمنع التقاط الشاشة/تسجيلها — بيانات مالية حسّاسة.
        window.setFlags(
            WindowManager.LayoutParams.FLAG_SECURE,
            WindowManager.LayoutParams.FLAG_SECURE,
        )
        super.onCreate(savedInstanceState)
    }
}
