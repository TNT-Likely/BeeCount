package com.tntlikely.beecount

import android.app.AlarmManager
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.content.pm.PackageInstaller
import android.net.Uri
import android.os.Build
import android.os.PowerManager
import android.provider.Settings
import androidx.core.content.FileProvider
import java.io.File
import java.io.FileInputStream
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity: FlutterActivity() {
    private val CHANNEL = "notification_channel"
    private val RECORD_CHANNEL = "com.beecount.api/broadcast" 
    private val INSTALL_CHANNEL = "com.tntlikely.beecount/install"
    private val SCREENSHOT_CHANNEL = "com.tntlikely.beecount/screenshot"
    private val LOGGER_CHANNEL = "com.beecount.logger"
    private val SHARE_CHANNEL = "com.tntlikely.beecount/share"
    private val AUTO_BILL_ACTION = "com.tntlikely.beecount.AUTO_BILLING"

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

        android.util.Log.e("MainActivity", "==========================================")
        android.util.Log.e("MainActivity", "configureFlutterEngine 被调用！！！")
        android.util.Log.e("MainActivity", "==========================================")
        
        // 分别建立连接
        val recordChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, RECORD_CHANNEL)
        // 1. 定义广播接收器 (监听来自 Xposed 或 ADB 的广播)
        val receiver = object : android.content.BroadcastReceiver() {
            override fun onReceive(context: android.content.Context?, intent: android.content.Intent?) {
                val action = intent?.action
                println("📡 [Native] 收到广播: $action")

                if (action == AUTO_BILL_ACTION) {
                    
                    // 【兼容取值】优先取 amount (BeeCount)，没有则取 money (钱迹格式)
                    val rawAmount = intent.extras?.get("amount") ?: intent.extras?.get("money")
                    val amount = rawAmount.toString().replace(",", "").toDoubleOrNull() ?: 0.0

                    // 【兼容备注】优先取备注，备注为空则取分类名
                    val rawRemark = intent.getStringExtra("remark") ?: ""
                    val rawCateName = intent.getStringExtra("cateName") ?: ""
                    val finalRemark = if (rawRemark.isNotEmpty()) rawRemark else rawCateName

                    val type = intent.getIntExtra("type", 0) 
                    val rawAccount = intent.getStringExtra("account") ?: ""
                    
                    val args = mapOf(
                        "amount" to amount,
                        "remark" to finalRemark,
                        "category" to rawCateName,
                        "account" to rawAccount,
                        "type" to if (type == 1) "income" else "expense",
                        "timestamp" to System.currentTimeMillis()
                    )

                    // 通过之前定义的 recordChannel 发送
                    recordChannel.invokeMethod("addTransaction", args)
                }
            }
        }

        // 2. 注册过滤器
        val filter = android.content.IntentFilter()
        filter.addAction(AUTO_BILL_ACTION)
        
        
        // 3. 注册接收器（适配 Android 14+ 安全要求）
        if (android.os.Build.VERSION.SDK_INT >= android.os.Build.VERSION_CODES.TIRAMISU) {
            context.registerReceiver(receiver, filter, android.content.Context.RECEIVER_EXPORTED)
        } else {
            context.registerReceiver(receiver, filter)
        }

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
                    openNotificationChannelSettings()
                    result.success(true)
                }
                "getNotificationChannelInfo" -> {
                    result.success(getNotificationChannelInfo())
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

    private fun openNotificationChannelSettings() {
        try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                val intent = Intent(Settings.ACTION_CHANNEL_NOTIFICATION_SETTINGS).apply {
                    putExtra(Settings.EXTRA_APP_PACKAGE, packageName)
                    putExtra(Settings.EXTRA_CHANNEL_ID, "accounting_reminder")
                }
                startActivity(intent)
                android.util.Log.d("MainActivity", "打开通知渠道设置页面")
            } else {
                // Android 8.0以下版本打开应用通知设置
                openAppSettings()
            }
        } catch (e: Exception) {
            android.util.Log.e("MainActivity", "打开通知渠道设置失败: $e")
            // fallback到应用设置
            openAppSettings()
        }
    }

    private fun getNotificationChannelInfo(): Map<String, Any> {
        try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                val notificationManager = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
                val channel = notificationManager.getNotificationChannel("accounting_reminder")

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
