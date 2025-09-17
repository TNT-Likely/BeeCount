package com.example.beecount

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.util.Log

class NotificationClickReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        Log.d("NotificationClickReceiver", "收到通知点击广播: ${intent.action}")

        val notificationId = intent.getIntExtra("notification_id", -1)
        val title = intent.getStringExtra("title") ?: ""

        Log.d("NotificationClickReceiver", "通知ID: $notificationId")
        Log.d("NotificationClickReceiver", "标题: $title")

        try {
            // 创建启动MainActivity的Intent
            val launchIntent = Intent(context, MainActivity::class.java).apply {
                flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP or Intent.FLAG_ACTIVITY_SINGLE_TOP
                putExtra("from_notification_click", true)
                putExtra("notification_id", notificationId)
                putExtra("notification_title", title)
                putExtra("click_timestamp", System.currentTimeMillis())
            }

            Log.d("NotificationClickReceiver", "启动MainActivity: $launchIntent")
            context.startActivity(launchIntent)
            Log.d("NotificationClickReceiver", "✅ MainActivity启动成功")

        } catch (e: Exception) {
            Log.e("NotificationClickReceiver", "❌ 启动MainActivity失败: $e")
        }
    }
}