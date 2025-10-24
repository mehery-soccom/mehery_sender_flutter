package com.mehery.admin.mehery_admin

import android.app.Activity
import android.app.NotificationManager
import android.content.Intent
import android.net.Uri
import android.os.Bundle
import android.util.Log

class CTATrackingActivity : Activity() {

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)

        val clickToken = intent.getStringExtra("click_token")
        val ctaId = intent.getStringExtra("cta_id")
        val ctaUrl = intent.getStringExtra("cta_url")
        val notificationId = intent.getIntExtra("notification_id", -1)

        Log.d("CTATrackingActivity", "CTA Tracking Activity started: $ctaId, $ctaUrl")

        // 1️⃣ Track CTA
        clickToken?.let {
            LiveActivityMessagingService().trackNotificationEvent(it, "cta", ctaId)
        }

        // 2️⃣ Open browser safely
        if (!ctaUrl.isNullOrBlank()) {
            try {
                val browserIntent = Intent(Intent.ACTION_VIEW, Uri.parse(ctaUrl)).apply {
                    addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                }
                startActivity(browserIntent)
                Log.d("CTATrackingActivity", "Browser launched for URL: $ctaUrl")
            } catch (e: Exception) {
                Log.e("CTATrackingActivity", "Failed to open URL: $ctaUrl", e)
            }
        }

        // 3️⃣ Dismiss notification
        val notificationManager =
            getSystemService(NOTIFICATION_SERVICE) as NotificationManager
        if (notificationId != -1) notificationManager.cancel(notificationId)
        else notificationManager.cancelAll()

        // 4️⃣ Close this activity immediately
        finish()
    }
}
