package com.tntlikely.beecount

import android.app.AlarmManager
import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.app.job.JobInfo
import android.app.job.JobScheduler
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.os.Build
import android.os.IBinder
import android.os.PowerManager
import android.os.SystemClock
import androidx.core.app.NotificationCompat
import io.flutter.FlutterInjector
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.embedding.engine.dart.DartExecutor

/**
 * 保活前台服务。
 *
 * 通过前台服务保持应用进程在后台存活，确保截图监听和摇一摇自动记账
 * 功能在后台也能正常运行。显示一个低优先级通知，不发出声音或震动。
 *
 * ### 五层保活 — L3 前台服务层 + L5 进程守护层
 * - L3: startForeground + onTaskRemoved 自拉活 + WakeLock
 * - L5: JobScheduler 3min + AlarmManager 1min 双心跳检测
 *
 * ### 防清除策略
 * - onTaskRemoved: 用户从最近任务滑掉时立即自拉活
 * - AlarmManager 心跳: 国产 ROM 上比 JobScheduler 更可靠
 * - START_STICKY: 系统杀死后尝试重建
 */
class KeepAliveService : Service() {

    companion object {
        private const val TAG = "KeepAliveService"

        const val CHANNEL_ID = "keep_alive"
        const val NOTIFICATION_ID = 9001
        const val JOB_ID = 9001
        const val ALARM_REQUEST_CODE = 9002

        const val ACTION_START = "com.tntlikely.beecount.action.START_KEEP_ALIVE"
        const val ACTION_STOP = "com.tntlikely.beecount.action.STOP_KEEP_ALIVE"
        const val ACTION_HEARTBEAT = "com.tntlikely.beecount.action.HEARTBEAT"

        /**
         * JobScheduler 心跳间隔（毫秒）。
         * 注意: Android 7+ (API 24+) 上 setPeriodic 最小强制 15 分钟，设更小也会被抬升到 15min。
         * JobScheduler 作为 AlarmManager 心跳的补充（Doze 模式下 AlarmManager 受限时仍可触发）。
         */
        private const val HEARTBEAT_INTERVAL_MS = 15 * 60 * 1000L  // 15 分钟（API 24+ 最小值）

        /** AlarmManager 心跳间隔（毫秒），国产 ROM 上比 JobScheduler 更可靠 */
        private const val ALARM_HEARTBEAT_INTERVAL_MS = 1 * 60 * 1000L  // 1 分钟

        /** 服务是否正在运行（供 MainActivity 状态查询） */
        @Volatile
        var isRunning = false
            private set

        /**
         * 后台专用的 FlutterEngine。
         *
         * 与 [MainActivity.cachedEngine] 完全独立，互不干扰。
         * 此 Engine 用 applicationContext 创建，不绑定 Activity 生命周期，
         * 专门用于后台截屏的 AI 处理。Activity 打开时 [MainActivity] 会
         * 创建自己的 Engine 渲染 UI，两者 Dart Isolate 完全隔离。
         */
        @Volatile
        private var backgroundEngine: FlutterEngine? = null

        /**
         * 确保后台 FlutterEngine 可用。
         *
         * 截屏触发后、发送结果到 Dart 前调用此方法，确保 Engine 的 Dart isolate
         * 正在运行。如果 Engine 已死或未创建，重新创建并注册到 [AccessibilityBridge]。
         *
         * **重要：始终使用 applicationContext 而非 Service/JobService context。**
         * Flutter 插件注册时如果拿到 Service context，后续 Activity attach 时
         * 会因为 context 类型不匹配而崩溃。applicationContext 是安全的基上下文。
         */
        @JvmStatic
        fun ensureFlutterEngine(context: Context) {
            // 不检查 AccessibilityBridge.hasEngine()：Activity 引擎可能在划掉后台后
            // FlutterJNI 已断开（detachFromNative），但 hasEngine() 仍返回 true，
            // 导致 backgroundEngine 永远不会被创建，MethodChannel 调用静默失败。
            // 始终走 backgroundEngine 路径，它是用 applicationContext 创建的独立引擎，
            // 不绑定 Activity 生命周期，JNI 始终存活。

            // 检查自有背景 Engine 是否存活
            if (backgroundEngine?.dartExecutor?.isExecutingDart == true) {
                LoggerPlugin.info(TAG, "使用后台缓存的 Engine")
                AccessibilityBridge.setEngine(backgroundEngine!!)
                return
            }

            // 自有 Engine 已死亡，销毁它
            backgroundEngine?.let {
                LoggerPlugin.warning(TAG, "后台 Engine 已死亡，销毁重建")
                try { it.destroy() } catch (_: Exception) {}
                backgroundEngine = null
            }

            try {
                // ⚠️ 关键：必须使用 applicationContext，而非原始 context（可能是 Service）！
                // Service context 会导致 Flutter 插件注册时拿到 Service 的引用，
                // 下次 Activity attach 时插件强转为 Activity 会崩溃。applicationContext 是安全的基上下文。
                val appContext = context.applicationContext
                LoggerPlugin.info(TAG, "创建 FlutterEngine（applicationContext）")
                val engine = FlutterEngine(appContext)

                engine.dartExecutor.executeDartEntrypoint(
                    DartExecutor.DartEntrypoint(
                        FlutterInjector.instance().flutterLoader().findAppBundlePath(),
                        "main"
                    )
                )

                backgroundEngine = engine
                AccessibilityBridge.setEngine(engine)
                LoggerPlugin.info(TAG, "后台 FlutterEngine 已创建并注册（applicationContext）")
            } catch (e: Exception) {
                LoggerPlugin.error(TAG, "FlutterEngine 初始化失败: ${e.message}")
            }
        }
    }

    private var wakeLock: PowerManager.WakeLock? = null

    override fun onCreate() {
        super.onCreate()
        LoggerPlugin.info(TAG, "保活服务创建")
        createNotificationChannel()
        scheduleHeartbeat()
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        when (intent?.action) {
            ACTION_STOP -> {
                LoggerPlugin.info(TAG, "收到停止指令")
                isRunning = false
                cancelHeartbeat()
                cancelAlarmHeartbeat()
                stopForeground(STOP_FOREGROUND_REMOVE)
                releaseWakeLock()
                stopSelf()
                return START_NOT_STICKY
            }
            ACTION_HEARTBEAT -> {
                LoggerPlugin.info(TAG, "AlarmManager 心跳 — 保活服务运行中")
                // Engine 由摇一摇回调按需创建，心跳只负责保活 Service 本身
                if (Build.VERSION.SDK_INT < Build.VERSION_CODES.TIRAMISU) {
                    reacquireForeground()
                }
                return START_STICKY
            }
            else -> {
                if (!isRunning) {
                    LoggerPlugin.info(TAG, "保活服务启动")
                }
                isRunning = true
                startForegroundWithNotification()
                acquireWakeLock()
                scheduleHeartbeat()
                scheduleAlarmHeartbeat()
                // Engine 由摇一摇回调按需创建，不在此提前创建。
                // 避免与 MainActivity 的 Engine 同时存在导致 OOM。
            }
        }
        return START_STICKY
    }

    override fun onTaskRemoved(rootIntent: Intent?) {
        LoggerPlugin.warning(TAG, "App 被从最近任务移除，尝试自拉活...")
        isRunning = false

        // 方式 1: 通过 AlarmManager 延迟 2 秒重启（绕过大多数 ROM 的清理限制）
        val restartIntent = Intent(this, KeepAliveService::class.java).apply {
            action = ACTION_START
        }
        val pendingIntent = PendingIntent.getService(
            this,
            ALARM_REQUEST_CODE + 1,
            restartIntent,
            PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT
        )
        val alarmManager = getSystemService(Context.ALARM_SERVICE) as AlarmManager
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            alarmManager.setExactAndAllowWhileIdle(
                AlarmManager.ELAPSED_REALTIME_WAKEUP,
                SystemClock.elapsedRealtime() + 2000,
                pendingIntent
            )
        } else {
            alarmManager.setExact(
                AlarmManager.ELAPSED_REALTIME_WAKEUP,
                SystemClock.elapsedRealtime() + 2000,
                pendingIntent
            )
        }

        // 方式 2: 直接尝试重启
        try {
            val restartDirect = Intent(this, KeepAliveService::class.java).apply {
                action = ACTION_START
            }
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                startForegroundService(restartDirect)
            } else {
                startService(restartDirect)
            }
            LoggerPlugin.info(TAG, "自拉活指令已发出")
        } catch (e: Exception) {
            LoggerPlugin.error(TAG, "直接自拉活失败，等待 AlarmManager 兜底: ${e.message}")
        }

        super.onTaskRemoved(rootIntent)
    }

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onDestroy() {
        LoggerPlugin.info(TAG, "保活服务销毁")
        isRunning = false
        cancelHeartbeat()
        cancelAlarmHeartbeat()
        releaseWakeLock()
        super.onDestroy()
    }

    // ────────────────── 前台通知 ──────────────────

    private fun createNotificationChannel() {
        val channel = NotificationChannel(
            CHANNEL_ID,
            "保活服务",
            NotificationManager.IMPORTANCE_MIN
        ).apply {
            description = "保持 BeeCount 在后台运行，确保摇一摇自动记账稳定工作"
            setShowBadge(false)
            lockscreenVisibility = NotificationCompat.VISIBILITY_SECRET
        }
        val manager = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        manager.createNotificationChannel(channel)
    }

    private fun createNotification(): Notification {
        return NotificationCompat.Builder(this, CHANNEL_ID)
            .setContentTitle("BeeCount 正在后台运行")
            .setContentText("保活服务 · 摇一摇自动记账 · 截图识别")
            .setSmallIcon(android.R.drawable.ic_menu_compass)
            .setPriority(NotificationCompat.PRIORITY_MIN)
            .setOngoing(true)
            .setSilent(true)
            .build()
    }

    private fun startForegroundWithNotification() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.UPSIDE_DOWN_CAKE) { // API 34+
            startForeground(
                NOTIFICATION_ID,
                createNotification(),
                android.content.pm.ServiceInfo.FOREGROUND_SERVICE_TYPE_SPECIAL_USE
            )
        } else {
            startForeground(NOTIFICATION_ID, createNotification())
        }
    }

    /**
     * 如果前台通知被系统移除（部分 ROM 清理行为），重新进入前台。
     */
    private fun reacquireForeground() {
        try {
            stopForeground(STOP_FOREGROUND_REMOVE)
            startForegroundWithNotification()
        } catch (_: Exception) {
            // 忽略，下次心跳再试
        }
    }

    // ────────────────── WakeLock ──────────────────

    private fun acquireWakeLock() {
        try {
            val powerManager = getSystemService(Context.POWER_SERVICE) as PowerManager
            wakeLock = powerManager.newWakeLock(
                PowerManager.PARTIAL_WAKE_LOCK,
                "BeeCount:KeepAliveWakeLock"
            ).apply {
                acquire(10 * 60 * 1000L) // 最多持有 10 分钟，防止耗电
            }
        } catch (_: Exception) {
            // 部分 ROM 限制 WakeLock
        }
    }

    private fun releaseWakeLock() {
        wakeLock?.let {
            if (it.isHeld) {
                try {
                    it.release()
                } catch (_: Exception) {}
            }
        }
        wakeLock = null
    }

    // ────────────────── JobScheduler 心跳（L5） ──────────────────

    private fun scheduleHeartbeat() {
        try {
            val scheduler = getSystemService(Context.JOB_SCHEDULER_SERVICE) as JobScheduler
            val jobInfo = JobInfo.Builder(JOB_ID, ComponentName(this, KeepAliveJobService::class.java))
                .setPeriodic(HEARTBEAT_INTERVAL_MS)
                .setPersisted(true)  // 设备重启后保留
                .setRequiredNetworkType(JobInfo.NETWORK_TYPE_NONE)
                .setRequiresCharging(false)
                .setRequiresDeviceIdle(false)
                .build()
            val result = scheduler.schedule(jobInfo)
            LoggerPlugin.info(TAG, "JobScheduler 心跳已调度（${HEARTBEAT_INTERVAL_MS / 60000}min），结果=$result")
        } catch (e: Exception) {
            LoggerPlugin.error(TAG, "JobScheduler 调度失败: ${e.message}")
        }
    }

    private fun cancelHeartbeat() {
        try {
            val scheduler = getSystemService(Context.JOB_SCHEDULER_SERVICE) as JobScheduler
            scheduler.cancel(JOB_ID)
            LoggerPlugin.info(TAG, "JobScheduler 心跳已取消")
        } catch (_: Exception) {}
    }

    // ────────────────── AlarmManager 心跳（L5 补充，国产 ROM 更可靠） ──────────────────

    /**
     * 使用 AlarmManager 作为额外心跳。
     * JobScheduler 在部分国产 ROM 上延迟严重（甚至数小时不触发），
     * AlarmManager（setExactAndAllowWhileIdle）更可靠。
     */
    private fun scheduleAlarmHeartbeat() {
        try {
            val intent = Intent(this, KeepAliveService::class.java).apply {
                action = ACTION_HEARTBEAT
            }
            val pendingIntent = PendingIntent.getService(
                this,
                ALARM_REQUEST_CODE,
                intent,
                PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT
            )
            val alarmManager = getSystemService(Context.ALARM_SERVICE) as AlarmManager
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                alarmManager.setExactAndAllowWhileIdle(
                    AlarmManager.ELAPSED_REALTIME_WAKEUP,
                    SystemClock.elapsedRealtime() + ALARM_HEARTBEAT_INTERVAL_MS,
                    pendingIntent
                )
            } else {
                alarmManager.setExact(
                    AlarmManager.ELAPSED_REALTIME_WAKEUP,
                    SystemClock.elapsedRealtime() + ALARM_HEARTBEAT_INTERVAL_MS,
                    pendingIntent
                )
            }
            LoggerPlugin.info(TAG, "AlarmManager 心跳已调度（${ALARM_HEARTBEAT_INTERVAL_MS / 60000}min）")
        } catch (e: Exception) {
            LoggerPlugin.error(TAG, "AlarmManager 调度失败: ${e.message}")
        }
    }

    private fun cancelAlarmHeartbeat() {
        try {
            val intent = Intent(this, KeepAliveService::class.java).apply {
                action = ACTION_HEARTBEAT
            }
            val pendingIntent = PendingIntent.getService(
                this,
                ALARM_REQUEST_CODE,
                intent,
                PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_NO_CREATE
            )
            pendingIntent?.let {
                val alarmManager = getSystemService(Context.ALARM_SERVICE) as AlarmManager
                alarmManager.cancel(it)
            }
            LoggerPlugin.info(TAG, "AlarmManager 心跳已取消")
        } catch (_: Exception) {}
    }
}
