package com.tntlikely.beecount

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent

/**
 * 开机自启接收器。
 *
 * ### 五层保活 — L5 进程守护层
 * 设备启动后自动启动保活前台服务，确保摇一摇自动记账功能在重启后仍能正常运行。
 * 仅在用户开启了摇一摇自动记账时启动保活，避免不必要的后台进程。
 */
class BootReceiver : BroadcastReceiver() {

    companion object {
        private const val TAG = "BootReceiver"
    }

    override fun onReceive(context: Context, intent: Intent) {
        if (intent.action == Intent.ACTION_BOOT_COMPLETED) {
            // 检查摇一摇自动记账是否已开启，未开启则不启动保活
            val prefs = context.getSharedPreferences("flutter.shared_preferences", Context.MODE_PRIVATE)
            val shakeEnabled = prefs.getBoolean("shake_billing_enabled", false)

            if (!shakeEnabled) {
                android.util.Log.d(TAG, "⏭️ 摇一摇未启用，跳过 BOOT_COMPLETED 保活")
                return
            }

            android.util.Log.d(TAG, "🚀 BOOT_COMPLETED — 启动保活服务（摇一摇已启用）")
            val serviceIntent = Intent(context, KeepAliveService::class.java).apply {
                action = KeepAliveService.ACTION_START
            }
            context.startForegroundService(serviceIntent)
        }
    }
}
