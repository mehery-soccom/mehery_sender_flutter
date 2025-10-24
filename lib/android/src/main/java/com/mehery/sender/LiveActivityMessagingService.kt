package com.mehery.admin.mehery_admin

import android.app.NotificationManager
import android.content.Context
import com.google.firebase.messaging.FirebaseMessagingService
import com.google.firebase.messaging.RemoteMessage
import androidx.core.app.NotificationCompat
import android.os.Build
import android.app.NotificationChannel
import android.app.PendingIntent
import android.content.Intent
import android.util.Log
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.launch
import org.json.JSONObject
import java.io.OutputStreamWriter
import java.net.HttpURLConnection
import java.net.URL
import android.graphics.BitmapFactory

class LiveActivityMessagingService : FirebaseMessagingService() {
    private val TAG = "LiveActivityMessaging"

    override fun onMessageReceived(remoteMessage: RemoteMessage) {
        Log.d(TAG, "From: ${remoteMessage.from}")

        if (remoteMessage.data.isNotEmpty()) {
            Log.d(TAG, "Message data payload: ${remoteMessage.data}")

            try {
                val clickToken = remoteMessage.data["click_token"]

                if (remoteMessage.data.containsKey("message1") &&
                    remoteMessage.data.containsKey("message2") &&
                    remoteMessage.data.containsKey("message3")
                ) {
                    handleLiveActivityNotification(remoteMessage.data)
                } else {
                    // Normal notification
                    val title = remoteMessage.data["title"] ?: "Notification"
                    val message = remoteMessage.data["body"] ?: "You have a new message"
                    val title1 = remoteMessage.data["title1"]
                    val url1 = remoteMessage.data["url1"]
                    val title2 = remoteMessage.data["title2"]
                    val url2 = remoteMessage.data["url2"]

                    val notificationManager =
                        getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
                    val channelId = "default_channel_id"
                    val channelName = "Default Channel"

                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                        val channel = NotificationChannel(
                            channelId,
                            channelName,
                            NotificationManager.IMPORTANCE_HIGH
                        )
                        notificationManager.createNotificationChannel(channel)
                    }

                    val builder = NotificationCompat.Builder(this, channelId)
                        .setSmallIcon(R.mipmap.ic_launcher)
                        .setContentTitle(title)
                        .setContentText(message)
                        .setAutoCancel(true)
                        .setPriority(NotificationCompat.PRIORITY_HIGH)

                    // Add optional image
                    remoteMessage.data["image"]?.let { imageUrl ->
                        try {
                            val url = URL(imageUrl)
                            val connection = url.openConnection() as HttpURLConnection
                            connection.doInput = true
                            connection.connect()
                            val inputStream = connection.inputStream
                            val bitmap = BitmapFactory.decodeStream(inputStream)
                            builder.setStyle(NotificationCompat.BigPictureStyle().bigPicture(bitmap))
                            inputStream.close()
                        } catch (e: Exception) {
                            Log.e(TAG, "Image load failed: ${e.message}")
                        }
                    }

                    // Notification click tracking intent
                    val openIntent = Intent(this, CTATrackingActivity::class.java).apply {
                        putExtra("click_token", clickToken)
                        putExtra("notification_id", System.currentTimeMillis().toInt())
                    }
                    val openPendingIntent = PendingIntent.getActivity(
                        this,
                        0,
                        openIntent,
                        PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
                    )
                    builder.setContentIntent(openPendingIntent)

                    // CTA 1
                    if (!title1.isNullOrBlank() && !url1.isNullOrBlank()) {
                        val intent1 = Intent(this, CTATrackingActivity::class.java).apply {
                            putExtra("click_token", clickToken)
                            putExtra("cta_id", "action1")
                            putExtra("cta_url", url1)
                            putExtra("notification_id", System.currentTimeMillis().toInt())
                        }
                        val pending1 = PendingIntent.getActivity(
                            this,
                            1,
                            intent1,
                            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
                        )
                        builder.addAction(0, title1, pending1)
                    }

                    // CTA 2
                    if (!title2.isNullOrBlank() && !url2.isNullOrBlank()) {
                        val intent2 = Intent(this, CTATrackingActivity::class.java).apply {
                            putExtra("click_token", clickToken)
                            putExtra("cta_id", "action2")
                            putExtra("cta_url", url2)
                            putExtra("notification_id", System.currentTimeMillis().toInt())
                        }
                        val pending2 = PendingIntent.getActivity(
                            this,
                            2,
                            intent2,
                            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
                        )
                        builder.addAction(0, title2, pending2)
                    }

                    notificationManager.notify(System.currentTimeMillis().toInt(), builder.build())
                }


            } catch (e: Exception) {
                Log.e(TAG, "Error handling FCM message", e)
            }
        }
    }

    private fun handleLiveActivityNotification(data: Map<String, String>) {
        try {
            val notificationManager =
                getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
            val customNotificationService = CustomNotificationService(this)

            val title = data["message1"] ?: ""
            val message = data["message2"] ?: ""
            val tapText = data["message3"] ?: ""
            val progress = (data["progressPercent"]?.toDoubleOrNull() ?: 0.0) * 100

            val titleColor = data["message1FontColorHex"] ?: "#FF0000"
            val messageColor = data["message2FontColorHex"] ?: "#000000"
            val tapTextColor = data["message3FontColorHex"] ?: "#CCCCCC"
            val progressColor = data["progressColorHex"] ?: "#00FF00"
            val backgroundColor = data["backgroundColorHex"] ?: "#FFFFFF"
            val imageUrl = data["imageUrl"] ?: ""
            val bg_color_gradient = data["bg_color_gradient"] ?: ""
            val bg_color_gradient_dir = data["bg_color_gradient_dir"] ?: ""
            val align = data["align"] ?: ""

            // ✅ NEW ATTRIBUTES FOR FONT STYLING
            val message1FontSize = data["message1FontSize"]?.toDoubleOrNull() ?: 14.0
            val line1FontTextStyles = data["line1_text_styles"]?.split(",") ?: emptyList()

            val message2FontSize = data["message2FontSize"]?.toDoubleOrNull() ?: 14.0
            val line2FontTextStyles = data["line2_text_styles"]?.split(",") ?: emptyList()

            val message3FontSize = data["message3FontSize"]?.toDoubleOrNull() ?: 14.0
            val line3FontTextStyles = data["line3_text_styles"]?.split(",") ?: emptyList()

            val activityId = data["activity_id"] ?: "fcm_activity_${System.currentTimeMillis()}"
            val notificationId = activityId.hashCode()

            val notification = customNotificationService.createCustomNotification(
                channelId = "live_activity_channel",
                title = title,
                message = message,
                tapText = tapText,
                progress = progress.toInt(),
                titleColor = titleColor,
                messageColor = messageColor,
                tapTextColor = tapTextColor,
                progressColor = progressColor,
                backgroundColor = backgroundColor,
                imageUrl = imageUrl,
                bg_color_gradient = bg_color_gradient,
                bg_color_gradient_dir = bg_color_gradient_dir,
                align = align,
                notificationId = notificationId,
                // ✅ PASS NEW ATTRIBUTES
                message1FontSize = message1FontSize,
                line1FontTextStyles = line1FontTextStyles,
                message2FontSize = message2FontSize,
                line2FontTextStyles = line2FontTextStyles,
                message3FontSize = message3FontSize,
                line3FontTextStyles = line3FontTextStyles
            )

            Log.d(TAG, "Showing FCM notification with ID: $notificationId")

            notificationManager.notify(notificationId, notification.build())
            Log.d(TAG, "FCM notification posted successfully")

        } catch (e: Exception) {
            Log.e(TAG, "Error showing notification from FCM", e)
        }
    }

    override fun onNewToken(token: String) {
        Log.d(TAG, "Refreshed FCM token: $token")
    }

    fun trackNotificationEvent(token: String, event: String, ctaId: String? = null) {
        CoroutineScope(Dispatchers.IO).launch {
            try {
                val url = URL("https://demo.pushapp.co.in/pushapp/api/v1/notification/push/track")
                val conn = url.openConnection() as HttpURLConnection
                conn.requestMethod = "POST"
                conn.setRequestProperty("Content-Type", "application/json")
                conn.doOutput = true

                val body = JSONObject().apply {
                    put("t", token)
                    put("event", event)
                    if (ctaId != null) put("data", JSONObject().put("ctaId", ctaId))
                    else put("data", JSONObject())
                }

                OutputStreamWriter(conn.outputStream).use { it.write(body.toString()) }
                val code = conn.responseCode
                Log.d(TAG, "Track API [$event] responded: $code")
                conn.disconnect()
            } catch (e: Exception) {
                Log.e(TAG, "Failed to send track event", e)
            }
        }
    }
}
