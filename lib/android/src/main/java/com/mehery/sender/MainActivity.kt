package com.mehery.admin.mehery_admin

import android.app.NotificationChannel
import android.app.NotificationManager
import android.content.Context
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import android.app.Notification
import androidx.core.app.NotificationCompat
import android.graphics.BitmapFactory
import android.os.Handler
import android.os.Looper
import java.net.HttpURLConnection
import java.net.URL

class MainActivity : FlutterActivity() {
    private val CHANNEL = "com.mehery.admin/live_activity"
    private lateinit var customNotificationService: CustomNotificationService
    private lateinit var notificationManager: NotificationManager

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        
        customNotificationService = CustomNotificationService(this)
        notificationManager = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager

        // Create notification channel for Android O and above
        if (android.os.Build.VERSION.SDK_INT >= android.os.Build.VERSION_CODES.O) {
            // Delete existing channel first
            notificationManager.deleteNotificationChannel("live_activity_channel")
            
            val channel = NotificationChannel(
                "live_activity_channel",
                "Live Activities",
                NotificationManager.IMPORTANCE_HIGH
            ).apply {
                enableLights(true)
                enableVibration(true)
                setShowBadge(true)
                lockscreenVisibility = Notification.VISIBILITY_PUBLIC
                setAllowBubbles(true)
            }
            
            notificationManager.createNotificationChannel(channel)
            println("Created notification channel: ${channel.id}")
            
            // Verify channel was created
            val createdChannel = notificationManager.getNotificationChannel(channel.id)
            if (createdChannel != null) {
                println("Channel verified: ${createdChannel.id}")
            } else {
                println("Failed to create channel!")
            }
        }
        
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "showLiveActivity" -> {
                    try {
                        val args = call.arguments as Map<*, *>
                        println("Received args in MainActivity: $args")
                        
                        try {
                            val activityId = args["activity_id"] as String
                            val notificationId = activityId.hashCode()
                            println("Using notification ID: $notificationId")
                            
                            val notification = customNotificationService.createCustomNotification(
                                channelId = "live_activity_channel",
                                title = args["title"] as String,
                                message = args["message"] as String,
                                tapText = args["tap_text"] as String,
                                progress = (args["progress"] as Double).toInt(),
                                titleColor = args["title_color"] as String,
                                messageColor = args["message_color"] as String,
                                tapTextColor = args["tap_text_color"] as String,
                                progressColor = args["progress_color"] as String,
                                backgroundColor = args["background_color"] as String,
                                imageUrl = args["imageUrl"] as String,
                                bg_color_gradient = args["bg_color_gradient"] as String,
                                bg_color_gradient_dir = args["bg_color_gradient_dir"] as String,
                                align = args["align"] as String,
                                notificationId = notificationId as Int,
                            )
                            
                            // Store the notification ID in the builder's extras for later use
                            notification.extras.putInt("notification_id", notificationId)
                            
                            println("About to show notification with ID: $notificationId")
//                            notificationManager.notify(notificationId, notification.build())
                            println("Notification posted successfully")
                            
                            result.success(null)
                        } catch (e: Exception) {
                            println("Error creating or showing notification: ${e.message}")
                            e.printStackTrace()
                            result.error("NOTIFICATION_ERROR", e.message, null)
                        }
                    } catch (e: Exception) {
                        println("Error processing arguments: ${e.message}")
                        e.printStackTrace()
                        result.error("ARGS_ERROR", e.message, null)
                    }
                }
                "endLiveActivity" -> {
                    val activityId = call.arguments as String
                    notificationManager.cancel(activityId.hashCode())
                    result.success(null)
                }
                "testImageNotification" -> {
                    val activityId = call.arguments as String
                    testImageNotification(activityId)
                    result.success(null)
                }
                "testImageLoading" -> {
                    val imageUrl = call.arguments as String
                    customNotificationService.testImageLoading(imageUrl) { success ->
                        result.success(success)
                    }
                }
                "testDirectImageLoading" -> {
                    val imageUrl = call.arguments as String
                    Thread {
                        try {
                            println("Testing direct image loading from: $imageUrl")
                            val url = URL(imageUrl)
                            val connection = url.openConnection() as HttpURLConnection
                            connection.doInput = true
                            connection.connectTimeout = 15000
                            connection.readTimeout = 15000
                            connection.connect()
                            
                            val responseCode = connection.responseCode
                            println("Direct image download response code: $responseCode")
                            
                            if (responseCode == 200) {
                                val input = connection.inputStream
                                val bitmap = BitmapFactory.decodeStream(input)
                                
                                Handler(Looper.getMainLooper()).post {
                                    if (bitmap != null) {
                                        println("Direct image download successful, size: ${bitmap.width}x${bitmap.height}")
                                        result.success(true)
                                    } else {
                                        println("Direct image download failed - bitmap is null")
                                        result.success(false)
                                    }
                                }
                            } else {
                                println("Direct image download failed - response code: $responseCode")
                                Handler(Looper.getMainLooper()).post {
                                    result.success(false)
                                }
                            }
                        } catch (e: Exception) {
                            println("Exception in direct image download: ${e.message}")
                            e.printStackTrace()
                            Handler(Looper.getMainLooper()).post {
                                result.success(false)
                            }
                        }
                    }.start()
                }
                else -> result.notImplemented()
            }
        }
    }

    private fun testImageNotification(activityId : String) {
        val imageUrl = "https://samplelib.com/lib/preview/png/sample-boat-400x300.png"
        val notificationId = activityId.hashCode()
        
        val notification = customNotificationService.createCustomNotification(
            channelId = "live_activity_channel",
            title = "Test Image",
            message = "This is a test notification with image",
            tapText = "Tap to open",
            progress = 50,
            titleColor = "#FF0000",
            messageColor = "#000000",
            tapTextColor = "#CCCCCC",
            progressColor = "#00FF00",
            backgroundColor = "#FFFFFF",
            imageUrl = imageUrl,
            bg_color_gradient = "#F00000",
            bg_color_gradient_dir = "horizontal",
            align = "left",
            notificationId = notificationId
        )
        
        // Store the notification ID in the builder's extras for later use
        notification.extras.putInt("notification_id", notificationId)
        
//        notificationManager.notify(notificationId, notification.build())
        println("Test image notification sent with ID: $notificationId")
    }
}
