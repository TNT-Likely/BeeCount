package com.example.beecount

import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.media.AudioAttributes
import android.media.RingtoneManager
import android.os.Build
import android.util.Log
import androidx.core.app.NotificationCompat
import androidx.core.app.NotificationManagerCompat

class NotificationReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        Log.d("NotificationReceiver", "收到广播: ${intent.action}")

        when (intent.action) {
            Intent.ACTION_BOOT_COMPLETED,
            Intent.ACTION_MY_PACKAGE_REPLACED,
            Intent.ACTION_PACKAGE_REPLACED -> {
                Log.d("NotificationReceiver", "系统启动或应用更新，需要重新调度通知")
                // 这里可以发送一个广播给Flutter应用，让它重新调度通知
                // 但由于Flutter应用可能还没启动，我们先记录日志
                rescheduleNotifications(context)
            }
            else -> {
                // 处理定时通知
                val title = intent.getStringExtra("title") ?: "记账提醒"
                val body = intent.getStringExtra("body") ?: "别忘了记录今天的收支哦 💰"
                val notificationId = intent.getIntExtra("notificationId", 1001)
                showNotification(context, title, body, notificationId)
            }
        }
    }

    private fun rescheduleNotifications(context: Context) {
        // 发送一个隐式Intent来启动MainActivity并告知需要重新调度通知
        try {
            val launchIntent = context.packageManager.getLaunchIntentForPackage(context.packageName)
            launchIntent?.let {
                it.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                it.putExtra("reschedule_notifications", true)
                context.startActivity(it)
                Log.d("NotificationReceiver", "已启动应用来重新调度通知")
            }
        } catch (e: Exception) {
            Log.e("NotificationReceiver", "无法启动应用重新调度通知: $e")
        }
    }

    private fun showNotification(context: Context, title: String, body: String, notificationId: Int) {
        Log.d("NotificationReceiver", "开始显示通知: ID=$notificationId")
        Log.d("NotificationReceiver", "标题: $title")
        Log.d("NotificationReceiver", "内容: $body")

        try {
            val channelId = "accounting_reminder"
            val notificationManager = context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager

            // 创建通知渠道（Android 8.0+）
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                val soundUri = RingtoneManager.getDefaultUri(RingtoneManager.TYPE_NOTIFICATION)
                val audioAttributes = AudioAttributes.Builder()
                    .setContentType(AudioAttributes.CONTENT_TYPE_SONIFICATION)
                    .setUsage(AudioAttributes.USAGE_NOTIFICATION)
                    .build()

                val channel = NotificationChannel(
                    channelId,
                    "记账提醒",
                    NotificationManager.IMPORTANCE_MAX // 使用最高重要性来显示横幅
                ).apply {
                    description = "每日记账提醒"
                    enableVibration(true)
                    enableLights(true)
                    setBypassDnd(true) // 允许在勿扰模式下显示
                    setSound(soundUri, audioAttributes)
                    vibrationPattern = longArrayOf(0, 500, 250, 500, 250, 500)
                    lightColor = android.graphics.Color.BLUE
                    lockscreenVisibility = NotificationCompat.VISIBILITY_PUBLIC
                }
                notificationManager.createNotificationChannel(channel)
                Log.d("NotificationReceiver", "通知渠道已创建/更新 - 包含声音和震动")
            }

            // 检查通知权限
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N) {
                if (!notificationManager.areNotificationsEnabled()) {
                    Log.w("NotificationReceiver", "⚠️ 通知权限未开启")
                    return
                }
            }

            // 创建点击通知的PendingIntent - 尝试多种方法
            Log.d("NotificationReceiver", "开始创建PendingIntent")

            // 直接使用MainActivity处理通知点击
            val clickIntent = Intent(context, MainActivity::class.java).apply {
                flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP or Intent.FLAG_ACTIVITY_SINGLE_TOP
                putExtra("from_notification", true)
                putExtra("from_notification_click", true)
                putExtra("notification_id", notificationId)
                putExtra("title", title)
                putExtra("timestamp", System.currentTimeMillis())
                putExtra("click_timestamp", System.currentTimeMillis())
            }

            Log.d("NotificationReceiver", "Click Intent: $clickIntent")
            Log.d("NotificationReceiver", "Click Intent flags: ${clickIntent.flags}")

            val pendingIntent = PendingIntent.getActivity(
                context,
                notificationId, // 使用通知ID作为requestCode
                clickIntent,
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                    PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
                } else {
                    PendingIntent.FLAG_UPDATE_CURRENT
                }
            )

            Log.d("NotificationReceiver", "PendingIntent创建完成: $pendingIntent")

            // 创建通知 - 简化配置，重点确保点击功能
            val notificationBuilder = NotificationCompat.Builder(context, channelId)
                .setContentTitle(title)
                .setContentText(body)
                .setSmallIcon(android.R.drawable.ic_dialog_info)
                .setPriority(NotificationCompat.PRIORITY_MAX)
                .setCategory(NotificationCompat.CATEGORY_REMINDER)
                .setAutoCancel(true) // 点击后自动取消
                .setDefaults(NotificationCompat.DEFAULT_ALL)
                .setWhen(System.currentTimeMillis())
                .setShowWhen(true)
                .setVisibility(NotificationCompat.VISIBILITY_PUBLIC)
                .setContentIntent(pendingIntent) // 关键：设置点击Intent

            // 验证点击Intent是否正确设置
            if (pendingIntent != null) {
                Log.d("NotificationReceiver", "✅ 已设置通知点击Intent: $pendingIntent")
            } else {
                Log.e("NotificationReceiver", "❌ PendingIntent为null，通知无法点击")
            }

            val notification = notificationBuilder.build()

            // 显示通知
            notificationManager.notify(notificationId, notification)
            Log.d("NotificationReceiver", "✅ 通知已发送: ID=$notificationId")
        } catch (e: Exception) {
            Log.e("NotificationReceiver", "❌ 显示通知失败: $e")
        }
    }
}