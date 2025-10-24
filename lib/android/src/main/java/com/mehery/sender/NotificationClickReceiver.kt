package com.mehery.admin.mehery_admin

import android.app.NotificationManager
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.util.Log

class NotificationClickReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        val action = intent.action
        val clickToken = intent.getStringExtra("click_token")

        if (clickToken.isNullOrBlank()) {
            Log.e("NotificationClickReceiver", "Missing click_token")
            return
        }

        val service = LiveActivityMessagingService()

        when (action) {
            "NOTIFICATION_OPENED" -> {
                Log.d("NotificationClickReceiver", "Notification opened")
                service.trackNotificationEvent(clickToken, "opened")
            }
        }

        // Always dismiss notification
        val notificationManager =
            context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        notificationManager.cancelAll()
    }
}
