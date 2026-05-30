package com.tntlikely.beecount

import android.app.job.JobParameters
import android.app.job.JobService
import android.content.Intent

/**
 * JobScheduler 心跳检测 JobService。
 *
 * ### 五层保活 — L5 进程守护层
 * 每 15 分钟由 [KeepAliveService] 调度执行一次，检测保活服务是否存活。
 * 如果服务异常死亡，尝试重新拉起；如果无障碍服务死亡（用户手动关闭），
 * 则不做恢复（需要用户主动重新开启）。
 */
class KeepAliveJobService : JobService() {

    companion object {
        private const val TAG = "KeepAliveJobService"
    }

    override fun onStartJob(params: JobParameters?): Boolean {
        android.util.Log.d(TAG, "❤️‍🔥 心跳检测执行中...")

        val keepAliveAlive = KeepAliveService.isRunning
        val accessibilityAlive = BillingAccessibilityService.isRunning

        android.util.Log.d(TAG, "   KeepAliveService: ${if (keepAliveAlive) "存活" else "已死"}")
        android.util.Log.d(TAG, "   BillingAccessibilityService: ${if (accessibilityAlive) "存活" else "已死"}")

        if (!keepAliveAlive) {
            // 尝试重新拉起保活服务
            android.util.Log.w(TAG, "⚠️ KeepAliveService 异常死亡，尝试重新拉起...")
            try {
                val intent = Intent(this, KeepAliveService::class.java).apply {
                    action = KeepAliveService.ACTION_START
                }
                if (android.os.Build.VERSION.SDK_INT >= android.os.Build.VERSION_CODES.O) {
                    startForegroundService(intent)
                } else {
                    startService(intent)
                }
                android.util.Log.d(TAG, "✅ 重新拉起成功")
            } catch (e: Exception) {
                android.util.Log.e(TAG, "❌ 重新拉起失败: ${e.message}")
            }
        }

        if (!accessibilityAlive) {
            android.util.Log.w(TAG, "⚠️ BillingAccessibilityService 未运行（等待系统自动重连）")
            // Engine 由摇一摇回调按需创建，不在此提前创建
        }

        // 通知 JobScheduler 工作完成
        jobFinished(params, false)
        return true
    }

    override fun onStopJob(params: JobParameters?): Boolean {
        android.util.Log.d(TAG, "⏹️ 心跳检测被系统取消")
        // 返回 true 表示需要重试
        return true
    }
}
