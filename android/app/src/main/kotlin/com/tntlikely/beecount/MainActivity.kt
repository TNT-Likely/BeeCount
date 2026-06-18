package com.tntlikely.beecount

import android.app.AlarmManager
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.net.Uri
import android.os.Build
import android.os.PowerManager
import android.provider.Settings
import androidx.core.content.FileProvider
import java.io.File
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity: FlutterFragmentActivity() {

    companion object {
        private const val TAG = "MainActivity"

        /** 缓存的 FlutterEngine，在 Activity 销毁后仍存活。
         * 通过 [provideFlutterEngine] 返回给 Fragment 宿主，
         * [shouldDestroyEngineWithHost]=false 禁止宿主销毁它。
         *
         * internal 可见性，允许 [KeepAliveService] 在进程重启后初始化。
         */
        @JvmField
        internal var cachedEngine: FlutterEngine? = null

        /**
         * Engine 是否已被 Fragment 配置并使用过。
         * Fragment 重建时 [configureFlutterEngine] 会被第二次调用，
         * 此时老 Fragment detach 可能已断开 FlutterJNI，但 Dart isolate 还活着。
         * 此标志让 [provideFlutterEngine] 检测到复用场景并重建 Engine。
         */
        private var engineHasBeenUsed = false
    }

    private val CHANNEL = "notification_channel"
    private val INSTALL_CHANNEL = "com.tntlikely.beecount/install"
    private val SCREENSHOT_CHANNEL = "com.tntlikely.beecount/screenshot"
    private val LOGGER_CHANNEL = "com.beecount.logger"
    private val SHARE_CHANNEL = "com.tntlikely.beecount/share"
    private val KEEP_ALIVE_CHANNEL = "com.tntlikely.beecount/keep_alive"

    private var screenshotObserver: ScreenshotObserver? = null

    override fun onCreate(savedInstanceState: android.os.Bundle?) {
        super.onCreate(savedInstanceState)
        handleNotificationIntent(intent)
        handleSharedImage(intent)
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent) // 重要：更新当前intent
        handleNotificationIntent(intent)
        handleSharedImage(intent)
    }

    /**
     * 提供缓存的 FlutterEngine，避免 Activity 销毁后 Dart 隔离区随之消亡。
     *
     * 首次调用时创建 Engine，后续一直返回同一个实例。
     * [FlutterActivityAndFragmentDelegate] 在 Activity 重建时仍会
     * 调用此方法获取同一个 Engine，并重新 [configureFlutterEngine]。
     *
     * 配合 [shouldDestroyEngineWithHost]=false 让 Engine 存活于整个进程。
     */
    override fun provideFlutterEngine(context: Context): FlutterEngine? {
        val existing = cachedEngine
        if (existing != null) {
            if (existing.dartExecutor.isExecutingDart) {
                // 检查 Engine 是否已被之前的 Fragment 配置并使用过。
                // Activity/Fragment 重建（如主题切换或第二次启动 Intent）会二次调用
                // provideFlutterEngine，老 Fragment detach 可能断开了 FlutterJNI，
                // 但 Dart isolate 还活着。此时复用老 Engine 会在渲染时崩溃。
                if (!engineHasBeenUsed) {
                    return existing
                }
                android.util.Log.w(TAG, "⚠️ Engine 已被使用过，销毁并重建避免 JNI 断开")
                LoggerPlugin.warning(TAG, "Engine 已被使用过，销毁并重建避免 JNI 断开")
            } else {
                android.util.Log.w(TAG, "⚠️ Dart isolate 已死亡，销毁并重建 FlutterEngine")
                LoggerPlugin.warning(TAG, "Dart isolate 已死亡，销毁并重建 FlutterEngine")
            }
            try {
                existing.destroy()
            } catch (_: Exception) {}
        }
        engineHasBeenUsed = false
        // 在创建 Engine 前检查 SharedPreferences 文件健康，防止 OOM
        checkFlutterSharedPreferencesHealth()

        android.util.Log.e(TAG, "🚀 创建全局缓存的 FlutterEngine")
        cachedEngine = FlutterEngine(context)
        return cachedEngine
    }

    /** 禁止 Fragment 宿主在 Activity 销毁时一并销毁 Engine */
    override fun shouldDestroyEngineWithHost(): Boolean = false

    /**
     * 检查并修复 SharedPreferences 文件大小异常。
     *
     * 在 Flutter Engine 初始化前检查 [FlutterSharedPreferences.xml] 和
     * [flutter.shared_preferences.xml] 文件大小。如果超过 1MB，
     * 说明存储了异常数据（如早期崩溃导致大量路径/损坏累积），
     * 直接删除文件。Flutter 插件/BootReceiver 读取时会自动创建新的空文件。
     *
     * 此操作仅丢失应用设置（主题、摇晃开关等），不涉及 SQLite 中的交易、账户等财务数据。
     */
    private fun checkFlutterSharedPreferencesHealth() {
        try {
            val sharedPrefsDir = File(filesDir.parentFile, "shared_prefs")
            if (!sharedPrefsDir.exists()) return

            val targets = listOf(
                "FlutterSharedPreferences" to "LegacySharedPreferencesPlugin",
                "flutter.shared_preferences" to "BootReceiver"
            )

            for ((name, description) in targets) {
                val file = File(sharedPrefsDir, "$name.xml")
                if (!file.exists()) continue

                val size = file.length()
                if (size > 1024 * 1024) { // > 1MB, 正常 SharedPreferences 不应这么大
                    android.util.Log.w(TAG,
                        "⚠️ $name.xml 异常过大 (${size / 1024 / 1024}MB) — " +
                        "由 $description 读取，已删除")
                    LoggerPlugin.warning(TAG,
                        "SharedPreferences $name.xml 过大 (${size / 1024 / 1024}MB)，已删除修复")

                    file.delete()

                    // 同时清理备份文件
                    val bakFile = File(sharedPrefsDir, "$name.xml.bak")
                    if (bakFile.exists()) bakFile.delete()
                }
            }
        } catch (e: Exception) {
            android.util.Log.e(TAG, "SharedPreferences 健康检查失败: ${e.message}")
        }
    }

    private fun handleSharedImage(intent: Intent?) {
        if (intent?.action == Intent.ACTION_SEND && intent.type?.startsWith("image/") == true) {
            android.util.Log.d("MainActivity", "✅ 收到图片分享")
            LoggerPlugin.info("MainActivity", "收到图片分享")

            val imageUri = intent.getParcelableExtra<Uri>(Intent.EXTRA_STREAM)
            if (imageUri != null) {
                android.util.Log.d("MainActivity", "图片URI: $imageUri")
                LoggerPlugin.info("MainActivity", "分享图片URI: $imageUri")

                try {
                    // 复制图片到临时文件
                    val imagePath = copySharedImageToTemp(imageUri)
                    if (imagePath != null) {
                        android.util.Log.d("MainActivity", "图片已保存到: $imagePath")
                        LoggerPlugin.info("MainActivity", "分享图片已保存: $imagePath")

                        // 通知Flutter端（延迟一下确保Flutter已初始化）
                        android.os.Handler(android.os.Looper.getMainLooper()).postDelayed({
                            notifyFlutterSharedImage(imagePath)
                        }, 500)
                    }
                } catch (e: Exception) {
                    android.util.Log.e("MainActivity", "处理分享图片失败: $e")
                    LoggerPlugin.error("MainActivity", "处理分享图片失败: ${e.message}")
                }
            }
        }
    }

    private fun copySharedImageToTemp(uri: Uri): String? {
        return try {
            val inputStream = contentResolver.openInputStream(uri) ?: return null

            // 创建临时文件
            val tempDir = File(cacheDir, "shared_images")
            tempDir.mkdirs()

            val timestamp = System.currentTimeMillis()
            val tempFile = File(tempDir, "shared_$timestamp.jpg")

            // 复制图片数据
            tempFile.outputStream().use { output ->
                inputStream.copyTo(output)
            }
            inputStream.close()

            tempFile.absolutePath
        } catch (e: Exception) {
            android.util.Log.e("MainActivity", "复制图片失败: $e")
            LoggerPlugin.error("MainActivity", "复制分享图片失败: ${e.message}")
            null
        }
    }

    private fun notifyFlutterSharedImage(imagePath: String) {
        try {
            flutterEngine?.dartExecutor?.binaryMessenger?.let { messenger ->
                MethodChannel(messenger, SHARE_CHANNEL).invokeMethod("onImageShared", imagePath)
                android.util.Log.d("MainActivity", "✅ 已通知Flutter端: $imagePath")
                LoggerPlugin.info("MainActivity", "已通知Flutter端收到分享图片")
            }
        } catch (e: Exception) {
            android.util.Log.e("MainActivity", "通知Flutter失败: $e")
            LoggerPlugin.error("MainActivity", "通知Flutter失败: ${e.message}")
        }
    }

    private fun handleNotificationIntent(intent: Intent?) {
        // 检查是否是从通知点击启动的
        val fromNotification = intent?.getBooleanExtra("from_notification", false) ?: false
        val fromNotificationClick = intent?.getBooleanExtra("from_notification_click", false) ?: false
        val notificationId = intent?.getIntExtra("notification_id", -1) ?: -1
        val timestamp = intent?.getLongExtra("timestamp", 0L) ?: 0L
        val clickTimestamp = intent?.getLongExtra("click_timestamp", 0L) ?: 0L

        if (fromNotification || fromNotificationClick) {
            android.util.Log.d("MainActivity", "✅ 应用从通知点击启动!")
            android.util.Log.d("MainActivity", "通知ID: $notificationId")
            android.util.Log.d("MainActivity", "时间戳: $timestamp")
            android.util.Log.d("MainActivity", "点击时间戳: $clickTimestamp")
            android.util.Log.d("MainActivity", "启动方式: ${if (fromNotificationClick) "BroadcastReceiver" else "Direct"}")
            android.util.Log.d("MainActivity", "Intent: $intent")

            // 这里可以添加其他处理逻辑，比如跳转到特定页面
        } else {
            android.util.Log.d("MainActivity", "应用正常启动（非通知点击）")
        }
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        // 标记 Engine 已被 Fragment 配置和使用过。
        // 如果 Activity/Fragment 重建导致二次调用，provideFlutterEngine 会据此重建 Engine。
        engineHasBeenUsed = true

        // 预创建摇一摇相关的通知渠道，确保首次显示通知时 importance 正确
        initBillingNotificationChannels()

        android.util.Log.e("MainActivity", "==========================================")
        android.util.Log.e("MainActivity", "configureFlutterEngine 被调用！！！")
        android.util.Log.e("MainActivity", "==========================================")

        // 日志桥接的MethodChannel
        val loggerChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, LOGGER_CHANNEL)
        android.util.Log.e("MainActivity", "即将调用 LoggerPlugin.setup")
        LoggerPlugin.setup(loggerChannel)
        android.util.Log.e("MainActivity", "LoggerPlugin.setup 调用完成")

        // 测试日志
        LoggerPlugin.info("MainActivity", "日志系统已初始化")

        // 延迟发送测试日志，确保 Flutter 端已就绪
        android.os.Handler(android.os.Looper.getMainLooper()).postDelayed({
            LoggerPlugin.info("MainActivity", "延迟测试日志 - Flutter 端应该已就绪")
            LoggerPlugin.debug("MainActivity", "这是一条 DEBUG 日志")
            LoggerPlugin.warning("MainActivity", "这是一条 WARNING 日志")
            LoggerPlugin.error("MainActivity", "这是一条 ERROR 日志")
        }, 2000)

        // 截图监听的MethodChannel
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, SCREENSHOT_CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "startScreenshotObserver" -> {
                    startScreenshotObserver(flutterEngine)
                    result.success(true)
                }
                "stopScreenshotObserver" -> {
                    stopScreenshotObserver()
                    result.success(true)
                }
                "openAccessibilitySettings" -> {
                    openAccessibilitySettings()
                    result.success(true)
                }
                "isAccessibilityServiceEnabled" -> {
                    result.success(isAccessibilityServiceEnabled())
                }
                else -> result.notImplemented()
            }
        }

        // 安装APK的MethodChannel
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, INSTALL_CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "installApk" -> {
                    val filePath = call.argument<String>("filePath")
                    if (filePath != null) {
                        val success = installApkWithIntent(filePath)
                        result.success(success)
                    } else {
                        result.error("INVALID_ARGUMENT", "文件路径不能为空", null)
                    }
                }
                else -> result.notImplemented()
            }
        }

        // 将全局 FlutterEngine 注册到 AccessibilityBridge
        // Engine 由 provideFlutterEngine 缓存，Activity 销毁后仍存活
        AccessibilityBridge.setEngine(flutterEngine)

        // 通知相关的MethodChannel
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "scheduleNotification" -> {
                    val title = call.argument<String>("title") ?: "记账提醒"
                    val body = call.argument<String>("body") ?: "别忘了记录今天的收支哦 💰"
                    val scheduledTimeMillis = call.argument<Long>("scheduledTimeMillis") ?: 0
                    val notificationId = call.argument<Int>("notificationId") ?: 1001
                    
                    scheduleNotification(title, body, scheduledTimeMillis, notificationId)
                    result.success(true)
                }
                "cancelNotification" -> {
                    val notificationId = call.argument<Int>("notificationId") ?: 1001
                    cancelNotification(notificationId)
                    result.success(true)
                }
                "isIgnoringBatteryOptimizations" -> {
                    result.success(isIgnoringBatteryOptimizations())
                }
                "requestIgnoreBatteryOptimizations" -> {
                    requestIgnoreBatteryOptimizations()
                    result.success(true)
                }
                "openAppSettings" -> {
                    openAppSettings()
                    result.success(true)
                }
                "getBatteryOptimizationInfo" -> {
                    result.success(getBatteryOptimizationInfo())
                }
                "openNotificationChannelSettings" -> {
                    val channelId = call.argument<String>("channelId") ?: "accounting_reminder"
                    openNotificationChannelSettings(channelId)
                    result.success(true)
                }
                "getNotificationChannelInfo" -> {
                    val channelId = call.argument<String>("channelId") ?: "accounting_reminder"
                    result.success(getNotificationChannelInfo(channelId))
                }
                "testDirectNotification" -> {
                    val title = call.argument<String>("title") ?: "直接测试通知"
                    val body = call.argument<String>("body") ?: "这是直接调用NotificationReceiver的测试"
                    val notificationId = call.argument<Int>("notificationId") ?: 7777

                    testDirectNotification(title, body, notificationId)
                    result.success(true)
                }
                else -> result.notImplemented()
            }
        }

        // 保活前台服务的MethodChannel
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, KEEP_ALIVE_CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "startKeepAlive" -> {
                    try {
                        val intent = Intent(this, KeepAliveService::class.java).apply {
                            action = KeepAliveService.ACTION_START
                        }
                        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                            startForegroundService(intent)
                        } else {
                            startService(intent)
                        }
                        android.util.Log.d("MainActivity", "✅ 保活服务已启动")
                        LoggerPlugin.info("MainActivity", "保活服务已启动")
                        result.success(true)
                    } catch (e: Exception) {
                        android.util.Log.e("MainActivity", "启动保活服务失败: $e")
                        result.error("START_FAILED", e.message ?: "启动保活服务失败", null)
                    }
                }
                "stopKeepAlive" -> {
                    try {
                        val intent = Intent(this, KeepAliveService::class.java).apply {
                            action = KeepAliveService.ACTION_STOP
                        }
                        startService(intent)
                        android.util.Log.d("MainActivity", "✅ 保活服务已停止")
                        LoggerPlugin.info("MainActivity", "保活服务已停止")
                        result.success(true)
                    } catch (e: Exception) {
                        android.util.Log.e("MainActivity", "停止保活服务失败: $e")
                        result.error("STOP_FAILED", e.message ?: "停止保活服务失败", null)
                    }
                }
                "isKeepAliveRunning" -> {
                    val running = KeepAliveService.isRunning || BillingAccessibilityService.isRunning
                    result.success(running)
                }
                "isIgnoringBatteryOptimizations" -> {
                    result.success(isIgnoringBatteryOptimizations())
                }
                "openBatteryOptimizationSettings" -> {
                    try {
                        val intent = Intent(android.provider.Settings.ACTION_IGNORE_BATTERY_OPTIMIZATION_SETTINGS)
                        startActivity(intent)
                        result.success(true)
                    } catch (e: Exception) {
                        result.error("INTENT_FAILED", e.message, null)
                    }
                }
                "cancelProgressNotification" -> {
                    try {
                        val manager = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
                        manager.cancel(9101)
                        android.util.Log.d("MainActivity", "✅ 进度通知已取消 (ID=9101)")
                        result.success(true)
                    } catch (e: Exception) {
                        android.util.Log.e("MainActivity", "❌ 取消进度通知失败: ${e.message}")
                        result.error("CANCEL_FAILED", e.message, null)
                    }
                }
                "openAutoStartSettings" -> {
                    try {
                        val result2 = openAutoStartSettings()
                        result.success(result2)
                    } catch (e: Exception) {
                        result.error("INTENT_FAILED", e.message, null)
                    }
                }
                "requestIgnoreBatteryOptimizations" -> {
                    requestIgnoreBatteryOptimizations()
                    result.success(true)
                }
                "getKeepAliveStatus" -> {
                    val map = mapOf(
                        "keepAliveServiceRunning" to KeepAliveService.isRunning,
                        "accessibilityServiceRunning" to BillingAccessibilityService.isRunning,
                        "isIgnoringBatteryOptimizations" to isIgnoringBatteryOptimizations()
                    )
                    result.success(map)
                }
                "getNotificationChannelInfo" -> {
                    val channelId = call.argument<String>("channelId") ?: "shake_result"
                    result.success(getNotificationChannelInfo(channelId))
                }
                "openNotificationChannelSettings" -> {
                    val channelId = call.argument<String>("channelId") ?: "shake_result"
                    openNotificationChannelSettings(channelId)
                    result.success(true)
                }
                else -> result.notImplemented()
            }
        }

        // 摇一摇自动记账控制方法绑定到 Engine 生命周期，不因 Activity 销毁而丢失
    }

    /**
     * 预创建摇一摇记账相关的通知渠道，确保 importance 正确。
     * 如果渠道已存在但 importance 不是 HIGH，则删除重建（仅在 DEBUG 构建或渠道重要性不达标时触发）。
     */
    private fun initBillingNotificationChannels() {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return
        val manager = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager

        // 需要确保 importance >= HIGH 的渠道列表
        data class ChannelDef(val id: String, val name: String, val desc: String)
        val channels = listOf(
            ChannelDef("shake_result", "摇一摇记账结果", "摇一摇自动记账最终结果通知"),
            ChannelDef("screenshot_ocr", "截图识别", "截图自动识别通知"),
        )

        for (ch in channels) {
            val existing = manager.getNotificationChannel(ch.id)
            if (existing != null && existing.importance >= NotificationManager.IMPORTANCE_HIGH) {
                // 已有渠道且 importance 达标 — 跳过
                android.util.Log.d(TAG, "通知渠道 '${ch.id}' 已存在且 importance 达标 (${existing.importance})")
                continue
            }
            if (existing != null) {
                // 渠道 importance 太低 — 删除重建（会丢失用户对该渠道的个性化设置）
                android.util.Log.w(TAG, "通知渠道 '${ch.id}' importance 过低 (${existing.importance})，删除重建")
                manager.deleteNotificationChannel(ch.id)
            }
            val channel = android.app.NotificationChannel(
                ch.id,
                ch.name,
                NotificationManager.IMPORTANCE_HIGH
            ).apply {
                description = ch.desc
                enableVibration(true)
                enableLights(true)
                setShowBadge(true)
                lockscreenVisibility = android.app.Notification.VISIBILITY_PUBLIC
                // 允许绕过勿扰模式（提升国产 ROM 弹出横幅几率）
                setBypassDnd(true)
            }
            manager.createNotificationChannel(channel)
            android.util.Log.d(TAG, "✅ 已创建通知渠道 '${ch.id}' (IMPORTANCE_HIGH)")
        }
    }

    private fun scheduleNotification(title: String, body: String, scheduledTimeMillis: Long, notificationId: Int) {
        try {
            android.util.Log.d("MainActivity", "开始调度通知: ID=$notificationId, 时间=$scheduledTimeMillis")
            android.util.Log.d("MainActivity", "标题: $title")
            android.util.Log.d("MainActivity", "内容: $body")

            val intent = Intent(this, NotificationReceiver::class.java).apply {
                putExtra("title", title)
                putExtra("body", body)
                putExtra("notificationId", notificationId)
                // 使用动态包名构建action
                action = "${packageName}.NOTIFICATION_ALARM"
            }

            val pendingIntent = PendingIntent.getBroadcast(
                this,
                notificationId,
                intent,
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                    PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
                } else {
                    PendingIntent.FLAG_UPDATE_CURRENT
                }
            )

            val alarmManager = getSystemService(Context.ALARM_SERVICE) as AlarmManager

            // 检查是否有精确闹钟权限
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                if (!alarmManager.canScheduleExactAlarms()) {
                    android.util.Log.w("MainActivity", "⚠️ 没有精确闹钟权限，尝试请求权限")
                    try {
                        val intent = Intent(android.provider.Settings.ACTION_REQUEST_SCHEDULE_EXACT_ALARM)
                        startActivity(intent)
                    } catch (e: Exception) {
                        android.util.Log.e("MainActivity", "无法打开精确闹钟权限设置: $e")
                    }
                    return
                }
            }

            // 计算时间差用于调试
            val currentTime = System.currentTimeMillis()
            val timeDiff = scheduledTimeMillis - currentTime
            android.util.Log.d("MainActivity", "当前时间: $currentTime")
            android.util.Log.d("MainActivity", "调度时间: $scheduledTimeMillis")
            android.util.Log.d("MainActivity", "时间差: ${timeDiff / 1000}秒")

            if (timeDiff <= 0) {
                android.util.Log.w("MainActivity", "⚠️ 调度时间已过期，立即发送通知")
                // 如果时间已过，立即发送通知
                val receiver = NotificationReceiver()
                receiver.onReceive(this, intent)
                return
            }

            // 使用setExactAndAllowWhileIdle确保在休眠模式下也能触发
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                android.util.Log.d("MainActivity", "使用 setExactAndAllowWhileIdle 调度通知")
                alarmManager.setExactAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, scheduledTimeMillis, pendingIntent)
            } else {
                android.util.Log.d("MainActivity", "使用 setExact 调度通知")
                alarmManager.setExact(AlarmManager.RTC_WAKEUP, scheduledTimeMillis, pendingIntent)
            }

            android.util.Log.d("MainActivity", "✅ AlarmManager 通知调度成功")
        } catch (e: Exception) {
            android.util.Log.e("MainActivity", "❌ AlarmManager 通知调度失败: $e")
        }
    }

    private fun cancelNotification(notificationId: Int) {
        android.util.Log.d("MainActivity", "取消通知: ID=$notificationId")
        val intent = Intent(this, NotificationReceiver::class.java).apply {
            action = "${packageName}.NOTIFICATION_ALARM"
        }
        val pendingIntent = PendingIntent.getBroadcast(
            this,
            notificationId,
            intent,
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
            } else {
                PendingIntent.FLAG_UPDATE_CURRENT
            }
        )

        val alarmManager = getSystemService(Context.ALARM_SERVICE) as AlarmManager
        alarmManager.cancel(pendingIntent)
    }

    private fun isIgnoringBatteryOptimizations(): Boolean {
        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            val powerManager = getSystemService(Context.POWER_SERVICE) as PowerManager
            powerManager.isIgnoringBatteryOptimizations(packageName)
        } else {
            true
        }
    }

    private fun requestIgnoreBatteryOptimizations() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            val powerManager = getSystemService(Context.POWER_SERVICE) as PowerManager
            if (!powerManager.isIgnoringBatteryOptimizations(packageName)) {
                val intent = Intent(Settings.ACTION_REQUEST_IGNORE_BATTERY_OPTIMIZATIONS).apply {
                    data = Uri.parse("package:$packageName")
                }
                try {
                    startActivity(intent)
                } catch (e: Exception) {
                    // 如果无法打开请求页面，则打开应用设置
                    openAppSettings()
                }
            }
        }
    }

    private fun openAppSettings() {
        val intent = Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS).apply {
            data = Uri.parse("package:$packageName")
        }
        startActivity(intent)
    }


    /**
     * 打开各 ROM 自启动管理页面。
     * 根据设备制造商跳转到对应的自启动设置页，不支持的 ROM 返回 false。
     */
    private fun openAutoStartSettings(): Boolean {
        val manufacturer = Build.MANUFACTURER.lowercase()

        // 荣耀/华为：有多条路径，逐一尝试
        if (manufacturer.contains("huawei") || manufacturer.contains("honor")) {
            val honorPkg = "com.hihonor.systemmanager"
            val honorCls = "$honorPkg.optimize.process.ProtectActivity"
            val huaweiPkg = "com.huawei.systemmanager"
            val huaweiCls = "$huaweiPkg.optimize.process.ProtectActivity"
            // 按优先级尝试各路径
            val candidates = listOf(
                Intent().apply { component = android.content.ComponentName(honorPkg, honorCls) },
                Intent().apply { component = android.content.ComponentName(huaweiPkg, huaweiCls) },
                Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS).apply {
                    data = Uri.parse("package:$packageName")
                },
            )
            for (intent in candidates) {
                try {
                    startActivity(intent)
                    return true
                } catch (_: Exception) { }
            }
            return false
        }

        val intent = when {
            manufacturer.contains("xiaomi") || manufacturer.contains("redmi") -> {
                Intent().apply {
                    component = android.content.ComponentName(
                        "com.miui.securitycenter",
                        "com.miui.permcenter.autostart.AutoStartManagementActivity"
                    )
                }
            }
            manufacturer.contains("oppo") || manufacturer.contains("oneplus") -> {
                Intent().apply {
                    component = android.content.ComponentName(
                        "com.oppo.safe",
                        "com.oppo.safe.permission.startup.StartupAppListActivity"
                    )
                }
            }
            manufacturer.contains("meizu") -> {
                Intent().apply {
                    component = android.content.ComponentName(
                        "com.meizu.safe",
                        "com.meizu.safe.permission.SmartPermissionActivity"
                    )
                }
            }
            else -> null
        }
        if (intent != null) {
            try {
                startActivity(intent)
                return true
            } catch (e: Exception) {
                android.util.Log.e(TAG, "打开自启动设置失败: ${e.message}")
            }
        }
        return false
    }

    private fun getBatteryOptimizationInfo(): Map<String, Any> {
        val isIgnoring = isIgnoringBatteryOptimizations()
        val canRequest = Build.VERSION.SDK_INT >= Build.VERSION_CODES.M
        val manufacturer = Build.MANUFACTURER

        return mapOf(
            "isIgnoring" to isIgnoring,
            "canRequest" to canRequest,
            "manufacturer" to manufacturer,
            "model" to Build.MODEL,
            "androidVersion" to Build.VERSION.RELEASE
        )
    }

    private fun openNotificationChannelSettings(channelId: String = "accounting_reminder") {
        try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                val intent = Intent(Settings.ACTION_CHANNEL_NOTIFICATION_SETTINGS).apply {
                    putExtra(Settings.EXTRA_APP_PACKAGE, packageName)
                    putExtra(Settings.EXTRA_CHANNEL_ID, channelId)
                }
                startActivity(intent)
                android.util.Log.d(TAG, "打开通知渠道设置页面: $channelId")
            } else {
                // Android 8.0以下版本打开应用通知设置
                openAppSettings()
            }
        } catch (e: Exception) {
            android.util.Log.e(TAG, "打开通知渠道设置失败: $e")
            // fallback到应用设置
            openAppSettings()
        }
    }

    private fun getNotificationChannelInfo(channelId: String = "accounting_reminder"): Map<String, Any> {
        try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                val notificationManager = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
                val channel = notificationManager.getNotificationChannel(channelId)

                if (channel != null) {
                    val importanceLevel = when (channel.importance) {
                        NotificationManager.IMPORTANCE_NONE -> "none"
                        NotificationManager.IMPORTANCE_MIN -> "min"
                        NotificationManager.IMPORTANCE_LOW -> "low"
                        NotificationManager.IMPORTANCE_DEFAULT -> "default"
                        NotificationManager.IMPORTANCE_HIGH -> "high"
                        NotificationManager.IMPORTANCE_MAX -> "max"
                        else -> "unknown"
                    }

                    return mapOf(
                        "isEnabled" to (channel.importance != NotificationManager.IMPORTANCE_NONE),
                        "importance" to importanceLevel,
                        "sound" to (channel.sound != null),
                        "vibration" to channel.shouldVibrate(),
                        "bypassDnd" to channel.canBypassDnd(),
                        "showBadge" to channel.canShowBadge(),
                        "lightColor" to channel.lightColor,
                        "lockscreenVisibility" to channel.lockscreenVisibility
                    )
                } else {
                    android.util.Log.w("MainActivity", "通知渠道 'accounting_reminder' 不存在")
                    return mapOf(
                        "isEnabled" to false,
                        "importance" to "none",
                        "sound" to false,
                        "vibration" to false,
                        "channelExists" to false
                    )
                }
            } else {
                // Android 8.0以下版本的通知设置
                val notificationManager = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
                val notificationsEnabled = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N) {
                    notificationManager.areNotificationsEnabled()
                } else {
                    true // 假设旧版本通知是开启的
                }

                return mapOf(
                    "isEnabled" to notificationsEnabled,
                    "importance" to "default",
                    "sound" to true,
                    "vibration" to true,
                    "legacyVersion" to true
                )
            }
        } catch (e: Exception) {
            android.util.Log.e("MainActivity", "获取通知渠道信息失败: $e")
            return mapOf(
                "isEnabled" to false,
                "importance" to "unknown",
                "sound" to false,
                "vibration" to false,
                "error" to (e.message ?: "Unknown error")
            )
        }
    }

    private fun testDirectNotification(title: String, body: String, notificationId: Int) {
        android.util.Log.d("MainActivity", "🔨 开始直接测试NotificationReceiver")
        android.util.Log.d("MainActivity", "标题: $title")
        android.util.Log.d("MainActivity", "内容: $body")
        android.util.Log.d("MainActivity", "ID: $notificationId")

        try {
            val receiver = NotificationReceiver()
            val intent = Intent().apply {
                putExtra("title", title)
                putExtra("body", body)
                putExtra("notificationId", notificationId)
            }

            receiver.onReceive(this, intent)
            android.util.Log.d("MainActivity", "✅ NotificationReceiver调用完成")
        } catch (e: Exception) {
            android.util.Log.e("MainActivity", "❌ 直接测试NotificationReceiver失败: $e")
        }
    }

    private fun openAccessibilitySettings() {
        try {
            val intent = Intent(android.provider.Settings.ACTION_ACCESSIBILITY_SETTINGS)
            startActivity(intent)
        } catch (e: Exception) {
            android.util.Log.e("MainActivity", "无法打开无障碍设置: $e")
            openAppSettings()
        }
    }

    private fun isAccessibilityServiceEnabled(): Boolean {
        return try {
            val enabledServices = android.provider.Settings.Secure.getString(
                contentResolver,
                android.provider.Settings.Secure.ENABLED_ACCESSIBILITY_SERVICES
            )
            enabledServices?.contains(packageName + "/" + BillingAccessibilityService::class.java.name) == true
        } catch (e: Exception) {
            false
        }
    }

    private fun startScreenshotObserver(flutterEngine: FlutterEngine) {
        try {
            android.util.Log.d("MainActivity", "========== 开始启动截图监听服务 ==========")
            LoggerPlugin.info("MainActivity", "开始启动截图监听服务")

            // 先停止旧的监听(如果有)
            stopScreenshotObserver()

            // 使用 ContentObserver 监听媒体库变化
            android.util.Log.d("MainActivity", "启动 ContentObserver 模式")
            LoggerPlugin.info("MainActivity", "截图监听模式: ContentObserver (监听媒体库变化)")
            startContentObserverMonitor(flutterEngine)

            android.util.Log.d("MainActivity", "========== 截图监听服务启动完成 ==========")
        } catch (e: Exception) {
            android.util.Log.e("MainActivity", "❌ 启动截图监听失败", e)
            LoggerPlugin.error("MainActivity", "启动截图监听失败: ${e.message}")
        }
    }

    /**
     * 启动 ContentObserver 截图监听
     * 监听媒体库变化，检测新增的截图文件
     */
    private fun startContentObserverMonitor(flutterEngine: FlutterEngine) {
        android.util.Log.d("MainActivity", "📸 配置 ContentObserver 模式...")
        LoggerPlugin.info("MainActivity", "开始配置 ContentObserver 截图监听")

        // 创建ContentObserver
        screenshotObserver = ScreenshotObserver(this) { screenshotPath ->
            android.util.Log.d("MainActivity", "✅ ContentObserver 检测到截图: $screenshotPath")
            LoggerPlugin.info("MainActivity", "ContentObserver 检测到截图，路径: ${screenshotPath.substringAfterLast('/')}")

            // 通知 Flutter 端
            MethodChannel(flutterEngine.dartExecutor.binaryMessenger, SCREENSHOT_CHANNEL)
                .invokeMethod("onScreenshotDetected", screenshotPath)
        }

        // 注册ContentObserver
        val uri = if (android.os.Build.VERSION.SDK_INT >= android.os.Build.VERSION_CODES.Q) {
            android.provider.MediaStore.Images.Media.getContentUri(android.provider.MediaStore.VOLUME_EXTERNAL)
        } else {
            android.provider.MediaStore.Images.Media.EXTERNAL_CONTENT_URI
        }

        android.util.Log.d("MainActivity", "   监听URI: $uri")
        contentResolver.registerContentObserver(uri, true, screenshotObserver!!)
        android.util.Log.d("MainActivity", "✅ ContentObserver 已注册到 MediaStore")
        LoggerPlugin.info("MainActivity", "ContentObserver 已注册到 MediaStore")
    }

    private fun stopScreenshotObserver() {
        try {
            // 停止ContentObserver
            screenshotObserver?.let {
                contentResolver.unregisterContentObserver(it)
                screenshotObserver = null
                android.util.Log.d("MainActivity", "✅ ContentObserver已注销")
            }

            android.util.Log.d("MainActivity", "✅ 截图监听已停止")
        } catch (e: Exception) {
            android.util.Log.e("MainActivity", "❌ 停止截图监听失败", e)
        }
    }

    override fun onDestroy() {
        super.onDestroy()
        stopScreenshotObserver()
        // 不释放 Bridge 中的 Engine 引用——Engine 由 provideFlutterEngine 缓存，
        // 跨 Activity 生命周期存活，Dart 隔离区继续处理 MethodChannel 消息。
    }

    private fun installApkWithIntent(filePath: String): Boolean {
        return try {
            android.util.Log.d("MainActivity", "UPDATE_CRASH: 开始原生Intent安装APK: $filePath")

            val sourceFile = File(filePath)
            if (!sourceFile.exists()) {
                android.util.Log.e("MainActivity", "UPDATE_CRASH: APK文件不存在: $filePath")
                return false
            }

            android.util.Log.d("MainActivity", "UPDATE_CRASH: APK文件大小: ${sourceFile.length()} 字节")

            // 直接在缓存根目录创建APK，避免子目录配置问题
            android.util.Log.d("MainActivity", "UPDATE_CRASH: 复制APK到缓存根目录")
            val cachedApk = File(cacheDir, "install.apk")
            sourceFile.copyTo(cachedApk, overwrite = true)
            android.util.Log.d("MainActivity", "UPDATE_CRASH: APK已复制到: ${cachedApk.absolutePath}")

            val intent = Intent(Intent.ACTION_VIEW)

            android.util.Log.d("MainActivity", "UPDATE_CRASH: 使用FileProvider创建URI")
            try {
                android.util.Log.d("MainActivity", "UPDATE_CRASH: 包名: $packageName")
                android.util.Log.d("MainActivity", "UPDATE_CRASH: Authority: $packageName.fileprovider")
                android.util.Log.d("MainActivity", "UPDATE_CRASH: 缓存APK路径: ${cachedApk.absolutePath}")
                android.util.Log.d("MainActivity", "UPDATE_CRASH: 调试 - applicationId: $packageName")
                android.util.Log.d("MainActivity", "UPDATE_CRASH: 调试 - Authority完整: $packageName.fileprovider")

                val uri = FileProvider.getUriForFile(
                    this,
                    "$packageName.fileprovider",
                    cachedApk
                )
                android.util.Log.d("MainActivity", "UPDATE_CRASH: ✅ FileProvider URI创建成功: $uri")

                intent.setDataAndType(uri, "application/vnd.android.package-archive")
                intent.addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
                android.util.Log.d("MainActivity", "UPDATE_CRASH: URI权限已设置")

            } catch (e: IllegalArgumentException) {
                android.util.Log.e("MainActivity", "UPDATE_CRASH: ❌ FileProvider路径配置错误", e)
                return false
            } catch (e: Exception) {
                android.util.Log.e("MainActivity", "UPDATE_CRASH: ❌ FileProvider创建URI失败", e)
                return false
            }

            intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)

            android.util.Log.d("MainActivity", "UPDATE_CRASH: 启动APK安装Intent")

            // 检查是否有应用可以处理该Intent
            if (intent.resolveActivity(packageManager) != null) {
                android.util.Log.d("MainActivity", "UPDATE_CRASH: 找到可处理APK安装的应用")
                startActivity(intent)
                android.util.Log.d("MainActivity", "UPDATE_CRASH: ✅ APK安装Intent启动成功")
                return true
            } else {
                android.util.Log.e("MainActivity", "UPDATE_CRASH: ❌ 没有应用可以处理APK安装")
                return false
            }

        } catch (e: Exception) {
            android.util.Log.e("MainActivity", "UPDATE_CRASH: ❌ 原生Intent安装失败: $e")
            return false
        }
    }
}
