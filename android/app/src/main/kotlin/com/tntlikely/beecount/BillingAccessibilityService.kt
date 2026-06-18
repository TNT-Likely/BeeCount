package com.tntlikely.beecount

import android.accessibilityservice.AccessibilityService
import android.app.KeyguardManager
import android.app.NotificationChannel
import android.app.NotificationManager
import android.content.Context
import android.content.Intent
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.os.PowerManager
import android.os.VibrationEffect
import android.os.Vibrator
import android.os.VibratorManager
import android.view.accessibility.AccessibilityEvent
import androidx.core.app.NotificationCompat
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

/**
 * Bridge to share FlutterEngine between MainActivity and BillingAccessibilityService.
 *
 * ### 架构
 * 不再创建独立的后台 Engine。改为由 [MainActivity.provideFlutterEngine] 缓存
 * 一个全局唯一的 FlutterEngine，该 Engine 在 Activity 销毁后**仍存活**，
 * 保证 App 切后台后 Dart 代码仍能实时接收摇一摇截图结果。
 *
 * ### 初始化流程
 * 1. [MainActivity.provideFlutterEngine] 首次调用时创建 Engine 并缓存
 * 2. [AccessibilityBridge.setEngine] 被 [MainActivity.configureFlutterEngine] 调用
 * 3. Engine 存活于整个进程生命周期，Activity 销毁不释放
 * 4. [BillingAccessibilityService] 摇一摇触发时通过 [sendCaptureResult] 发送
 */
object AccessibilityBridge {
    const val CHANNEL = "com.tntlikely.beecount/accessibility_billing"
    private const val TAG = "AccessibilityBridge"

    /** 全局唯一的 FlutterEngine（Activity 销毁后仍存活） */
    private var flutterEngine: FlutterEngine? = null

    /** Engine 是否已就绪（Dart isolate 必须存活） */
    fun hasEngine(): Boolean {
        val engine = flutterEngine
        return engine != null && engine.dartExecutor.isExecutingDart
    }

    /** 降级队列：Engine 尚未就绪时暂存结果 */
    private val pendingResults = mutableListOf<String>()

    // ─── 初始化 ───

    /**
     * 设置全局 FlutterEngine 引用，并在首次接入时注册 [SHAKE_CONTROL_CHANNEL] handler。
     *
     * 由 [MainActivity.configureFlutterEngine] 每次 Activity 创建时调用，
     * 但 Engine 本身是同一个（由 [MainActivity.provideFlutterEngine] 缓存），
     * 所以 Dart 隔离区始终存活。
     *
     * handler 在首次注册后永久有效（Engine 不销毁就不丢），
     * 解决 Activity 销毁后 [MainActivity.configureFlutterEngine] 无法重新注册
     * 导致的 MissingPluginException。
     */
    fun setEngine(engine: FlutterEngine) {
        // 检查引用是否不同（首次注册 or Engine 重建后），确保 handler 绑定到当前 Engine
        val isNewEngine = (flutterEngine !== engine)
        if (isNewEngine) {
            android.util.Log.d(TAG, "🚀 ===== 全局 FlutterEngine 就绪 =====")
            registerShakeControlHandler(engine)
        }
        flutterEngine = engine
        LoggerPlugin.info(TAG, "FlutterEngine 已注册")
        // 有 Engine 了，刷新排队结果
        flushPending()
    }

    /** 摇一摇自动记账控制通道 */
    private const val SHAKE_CONTROL_CHANNEL = "com.tntlikely.beecount/shake_billing_control"

    /**
     * 注册 [SHAKE_CONTROL_CHANNEL] 的 MethodCallHandler。
     * 所有方法仅调用 [BillingAccessibilityService] 的静态方法，
     * 不依赖 Activity，故可绑定到 Engine 生命周期。
     */
    private fun registerShakeControlHandler(engine: FlutterEngine) {
        MethodChannel(engine.dartExecutor.binaryMessenger, SHAKE_CONTROL_CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "enableShake" -> {
                        BillingAccessibilityService.setShakeDetectionEnabled(true)
                        result.success(true)
                    }
                    "disableShake" -> {
                        BillingAccessibilityService.setShakeDetectionEnabled(false)
                        result.success(true)
                    }
                    "showResultNotification" -> {
                        val title = call.argument<String>("title") ?: ""
                        val body = call.argument<String>("body") ?: ""
                        BillingAccessibilityService.showResultNotification(title, body)
                        result.success(true)
                    }
                    // Dart 处理完成（成功/超时/失败），取消原生超时并显示结果通知
                    "captureResult" -> {
                        val path = call.argument<String>("path") ?: ""
                        val title = call.argument<String>("title") ?: ""
                        val body = call.argument<String>("body") ?: ""
                        BillingAccessibilityService.onCaptureResult(path, title, body)
                        result.success(true)
                    }
                    // Dart 侧关键阶段日志，直达原生 Logcat，闪退后仍可查看
                    "logStage" -> {
                        val stage = call.argument<String>("stage") ?: "?"
                        android.util.Log.d(TAG, "🐛 [DartStage] $stage")
                        result.success(true)
                    }
                    else -> result.notImplemented()
                }
            }
    }

    // ─── 发送截图结果 ───

    /**
     * 发送无障碍截屏结果到 Flutter。
     *
     * [result] 为 PNG 文件路径（API 31+）或 "text:..." 前缀文本（API 30-）。
     * 如果 Engine 尚未就绪（极少情况），结果排队等待下一轮 flush。
     */
    fun sendCaptureResult(result: String) {
        val engine = flutterEngine
        if (engine != null) {
            LoggerPlugin.info(TAG, "截屏结果发送到 Flutter: ${result.take(60)}")
            sendNow(engine, result)
        } else {
            LoggerPlugin.warning(TAG, "Engine 未就绪，截屏结果入队等待")
            synchronized(pendingResults) {
                pendingResults.add(result)
            }
        }
    }

    /**
     * 发送无障碍服务被中断的通知到 Flutter。
     *
     * 被 [BillingAccessibilityService.onInterrupt] 调用，
     * Flutter 侧收到后可在 UI 上提示用户检查无障碍状态。
     */
    fun sendServiceInterrupted() {
        val engine = flutterEngine
        if (engine != null) {
            try {
                MethodChannel(engine.dartExecutor.binaryMessenger, CHANNEL)
                    .invokeMethod("onAccessibilityServiceInterrupted", null)
                LoggerPlugin.warning(TAG, "无障碍服务中断已通知 Flutter")
            } catch (e: Exception) {
                LoggerPlugin.error(TAG, "发送中断通知失败: ${e.message}")
            }
        }
    }

    /** 立即通过 MethodChannel 发送一条结果 */
    private fun sendNow(engine: FlutterEngine, data: String) {
        val ok = java.util.concurrent.atomic.AtomicBoolean(true)
        try {
            MethodChannel(engine.dartExecutor.binaryMessenger, CHANNEL)
                .invokeMethod("onAccessibilityCapture", data, object : MethodChannel.Result {
                    override fun success(result: Any?) {
                        LoggerPlugin.info(TAG, "MethodChannel 发送成功: ${data.take(60)}")
                    }
                    override fun error(errorCode: String, errorMessage: String?, errorDetails: Any?) {
                        LoggerPlugin.error(TAG, "MethodChannel 返回错误: $errorCode $errorMessage")
                        ok.set(false)
                    }
                    override fun notImplemented() {
                        // JNI detached 时 FlutterJNI.dispatchPlatformMessage 会 reply(null)，
                        // IncomingResultHandler 将其转为 notImplemented() 回调
                        LoggerPlugin.warning(TAG, "MethodChannel 未实现（JNI 可能已断开），重新入队")
                        ok.set(false)
                    }
                })
            if (!ok.get()) {
                synchronized(pendingResults) {
                    pendingResults.add(data)
                }
            }
        } catch (e: Exception) {
            LoggerPlugin.error(TAG, "MethodChannel 异常: ${e.message}")
            synchronized(pendingResults) {
                pendingResults.add(data)
            }
        }
    }

    /** Engine 就绪后刷新排队的结果 */
    private fun flushPending() {
        val engine = flutterEngine ?: return
        synchronized(pendingResults) {
            if (pendingResults.isEmpty()) return
            val batch = pendingResults.toList()
            pendingResults.clear()
            LoggerPlugin.info(TAG, "刷新排队结果: ${batch.size} 条")
            batch.forEach { sendNow(engine, it) }
        }
    }
}

/**
 * 摇一摇自动记账无障碍服务。
 *
 * 通过 [ShakeDetector] 监听加速度传感器，摇动手机时利用
 * [ScreenshotController] 截取当前屏幕（API 31+ takeScreenshot）
 * 或提取节点文本（API 30-），通过 [AccessibilityBridge] 将结果
 * 发送到 Flutter 端调用 [AutoBillingService] 进行 AI 记账。
 *
 * ### 生命周期
 * 1. `onServiceConnected()` — 注册传感器监听
 * 2. 摇动手机 → `ShakeDetector` 触发 → `ScreenshotController.captureForAI`
 * 3. `onDestroy()` — 注销传感器，释放资源
 */
class BillingAccessibilityService : AccessibilityService() {

    companion object {
        private const val TAG = "BillingAccessibility"

        /** 进度通知 ID */
        private const val PROGRESS_NOTIFICATION_ID = 9101
        /** 结果通知 ID */
        private const val RESULT_NOTIFICATION_ID = 9102
        /** 复用结果通知的 channel，该 channel 已在设备上配置好横幅权限 */
        private const val PROGRESS_CHANNEL_ID = "shake_result"
        private const val RESULT_RETRACTED_CHANNEL_ID = "shake_result_retracted"

        /** 无障碍服务是否正在运行（供 MainActivity 状态查询 + KeepAliveJobService 心跳） */
        @Volatile
        var isRunning = false
            private set

        /** 当前运行的无障碍服务实例，供静态方法控制 ShakeDetector */
        @Volatile
        var instance: BillingAccessibilityService? = null
            private set

        /**
         * 缓存 Application Context，用于 AccessibilityService 被销毁后
         * 仍能发送通知（用户从最近任务清除 App 后服务可能被系统销毁）。
         * [onServiceConnected] 时写入，避免裸 Activity/Service context。
         */
        @Volatile
        private var appContext: Context? = null

        /**
         * 当前正在处理中的截图路径（用于原生超时兜底）。
         * Dart 端处理完成后通过 [onCaptureResult] 清空此值，
         * 如果 15s 内未清空，原生直接弹出超时通知。
         */
        @Volatile
        private var pendingCapturePath: String? = null

        /**
         * 启用/禁用摇一摇检测。
         * 由 MainActivity 的 MethodChannel 调用，无需持有服务实例。
         */
        fun setShakeDetectionEnabled(enabled: Boolean) {
            val service = instance ?: return
            if (enabled) {
                service.shakeDetector?.start()
                LoggerPlugin.info(TAG, "ShakeDetector 已启用")
            } else {
                service.shakeDetector?.stop()
                LoggerPlugin.info(TAG, "ShakeDetector 已禁用")
            }
        }

        /**
         * 打开系统最近任务列表（无障碍全局动作）。
         * 用户在最近任务中手动锁定应用，防止被一键清理。
         */
        fun openRecentTasks(): Boolean {
            return instance?.performGlobalAction(
                android.accessibilityservice.AccessibilityService.GLOBAL_ACTION_RECENTS
            ) ?: false
        }

        /**
         * 截屏处理完成时由 Flutter 侧回调（通过 MethodChannel [captureResult]）。
         *
         * 1. 取消原生 15s 超时定时器（防止超时通知覆盖结果通知）
         * 2. 调用 [showResultNotification] 显示结果通知
         */
        fun onCaptureResult(path: String, title: String, body: String) {
            android.util.Log.d(TAG, "📩 onCaptureResult: path=$path title=$title | instance=$instance appContext=$appContext")
            if (path == pendingCapturePath) {
                android.util.Log.d(TAG, "✓ 匹配 pendingCapturePath，取消原生超时")
                LoggerPlugin.info(TAG, "Dart 处理完成，取消原生超时")
                pendingCapturePath = null
            } else {
                android.util.Log.w(TAG, "⚠️ path 不匹配 pendingCapturePath（path=$path pending=$pendingCapturePath）")
            }
            showResultNotification(title, body)
        }

        /**
         * 截屏发送到 Dart 后启动原生 15s 超时兜底。
         *
         * 如果 15s 内 [onCaptureResult] 未被调用（Dart Isolate 挂起/崩溃），
         * 直接弹出超时通知，确保用户不会一直看到「正在识别」进度通知。
         * Dart 后续处理完成时仍可通过 [onCaptureResult] 替换为结果通知。
         *
         * ⚡ 使用 [android.util.Log] 直出 logcat，App 被划掉后仍可
         * 通过 `adb logcat -s BillingAccessibility` 抓取。
         */
        @JvmStatic
        fun startCaptureTimeout(path: String) {
            pendingCapturePath = path
            android.util.Log.d(TAG, "⭐ 原生 15s 超时已启动: $path")
            LoggerPlugin.info(TAG, "原生 15s 超时已启动: $path")
            android.os.Handler(android.os.Looper.getMainLooper()).postDelayed({
                if (pendingCapturePath == path) {
                    android.util.Log.w(TAG, "⚠️ 原生超时触发：Dart 15s 内未返回 | instance=$instance appContext=$appContext")
                    LoggerPlugin.warning(TAG, "原生超时触发：Dart 15s 内未返回")
                    showTimeoutNotification()
                } else {
                    android.util.Log.d(TAG, "✓ 超时取消（pendingCapturePath 已被 onCaptureResult 清空）")
                }
            }, 15_000)
        }

        /** 显示超时通知（原生侧直接弹出，不依赖 Flutter Engine） */
        private fun showTimeoutNotification() {
            val ctx = (instance ?: appContext) ?: run {
                android.util.Log.e(TAG, "❌ showTimeoutNotification: 无可用 Context（instance=null && appContext=null）")
                return
            }
            try {
                instance?.ensureProgressChannelHigh()
                val notification = NotificationCompat.Builder(ctx, PROGRESS_CHANNEL_ID)
                    .setContentTitle("蜜蜂记账")
                    .setContentText("⏳ 识别耗时较长，请稍等！")
                    .setSmallIcon(android.R.drawable.ic_popup_reminder)
                    .setPriority(NotificationCompat.PRIORITY_HIGH)
                    .setCategory(NotificationCompat.CATEGORY_ALARM)
                    .setAutoCancel(true)
                    .build()
                val manager = ctx.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
                manager.cancel(PROGRESS_NOTIFICATION_ID)
                manager.notify(RESULT_NOTIFICATION_ID, notification)
                android.util.Log.d(TAG, "✅ 超时通知已发送 (ctx=${if (instance != null) "instance" else "appContext"})")
                LoggerPlugin.info(TAG, "超时通知已发送")
            } catch (e: Exception) {
                android.util.Log.e(TAG, "❌ 超时通知发送失败: ${e.message}")
                LoggerPlugin.error(TAG, "超时通知发送失败: ${e.message}")
            }
        }

        /**
         * 显示摇一摇结果通知（原生侧投递，绕过 Flutter Engine）。
         * 由 Flutter 侧 AI 处理完成后通过 MethodChannel 调用。
         * 使用与进度通知相同的 [PROGRESS_CHANNEL_ID]（shake_result），
         * 该 channel 已在设备上配置好横幅权限以支持 heads-up 弹出。
         *
         * **兼容 App 被从最近任务清除后的场景**：此时服务实例可能已被销毁
         * （[instance] == null），用缓存的 [appContext] 兜底发通知。
         *
         * ⚡ 使用 [android.util.Log] 直出 logcat，App 被划掉后仍可
         * 通过 `adb logcat -s BillingAccessibility` 抓取。
         */
        fun showResultNotification(title: String, body: String) {
            val ctx = (instance ?: appContext) ?: run {
                android.util.Log.e(TAG, "❌ showResultNotification: 无可用 Context（instance=null && appContext=null）")
                LoggerPlugin.error(TAG, "showResultNotification: 无可用 Context")
                return
            }
            android.util.Log.d(TAG, "📢 showResultNotification: title=$title ctx=${if (instance != null) "instance" else "appContext"}")
            try {
                // instance 存在时才保证 channel，否则 channel 已由 MainActivity 创建
                instance?.ensureProgressChannelHigh()

                val launchIntent = Intent(ctx, com.tntlikely.beecount.MainActivity::class.java).apply {
                    flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP
                }
                val fullScreenIntent = android.app.PendingIntent.getActivity(
                    ctx, 0, launchIntent,
                    android.app.PendingIntent.FLAG_IMMUTABLE or android.app.PendingIntent.FLAG_UPDATE_CURRENT
                )
                val contentIntent = android.app.PendingIntent.getActivity(
                    ctx, 1, launchIntent,
                    android.app.PendingIntent.FLAG_IMMUTABLE or android.app.PendingIntent.FLAG_UPDATE_CURRENT
                )

                val headsUpNotification = NotificationCompat.Builder(ctx, PROGRESS_CHANNEL_ID)
                    .setContentTitle(title)
                    .setContentText(body)
                    .setSmallIcon(android.R.drawable.ic_popup_reminder)
                    .setPriority(NotificationCompat.PRIORITY_HIGH)
                    .setCategory(NotificationCompat.CATEGORY_ALARM)
                    .setContentIntent(contentIntent)
                    .setFullScreenIntent(fullScreenIntent, true)
                    .setAutoCancel(true)
                    .build()

                val manager = ctx.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
                // 先取消旧的进度通知（ID 9101），避免同一 channel 两个通知竞争 heads-up 配额
                manager.cancel(PROGRESS_NOTIFICATION_ID)
                // 显示 heads-up 横幅
                manager.notify(RESULT_NOTIFICATION_ID, headsUpNotification)
                android.util.Log.d(TAG, "✅ 结果通知已发送: title=$title")
                LoggerPlugin.info(TAG, "结果通知已发送: title=$title")

                // 3s 后收回通知栏：取消 heads-up 通知，用低优先级渠道重新显示（不再弹横幅）
                android.os.Handler(android.os.Looper.getMainLooper()).postDelayed({
                    try {
                        manager.cancel(RESULT_NOTIFICATION_ID)

                        // 确保收回收渠道已创建（DEFAULT 重要性，不弹 Heads-up）
                        ensureResultRetractedChannel(ctx)

                        val retractedNotification = NotificationCompat.Builder(ctx, RESULT_RETRACTED_CHANNEL_ID)
                            .setContentTitle(title)
                            .setContentText(body)
                            .setSmallIcon(android.R.drawable.ic_popup_reminder)
                            .setPriority(NotificationCompat.PRIORITY_DEFAULT)
                            .setCategory(NotificationCompat.CATEGORY_STATUS)
                            .setContentIntent(contentIntent)
                            .setAutoCancel(true)
                            .build()
                        manager.notify(RESULT_NOTIFICATION_ID, retractedNotification)
                        android.util.Log.d(TAG, "↘️ 结果通知已收回通知栏")
                    } catch (e: Exception) {
                        android.util.Log.e(TAG, "❌ 结果通知收回失败: ${e.message}")
                    }
                }, 3000)
            } catch (e: Exception) {
                android.util.Log.e(TAG, "❌ 结果通知发送失败: ${e.message}")
                LoggerPlugin.error(TAG, "结果通知发送失败: ${e.message}")
            }
        }

        /** 确保收回收渠道 [RESULT_RETRACTED_CHANNEL_ID] 已创建（DEFAULT 重要性，不弹 heads-up） */
        private fun ensureResultRetractedChannel(ctx: Context) {
            if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return
            try {
                val manager = ctx.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
                if (manager.getNotificationChannel(RESULT_RETRACTED_CHANNEL_ID) == null) {
                    val channel = android.app.NotificationChannel(
                        RESULT_RETRACTED_CHANNEL_ID,
                        "摇一摇记账结果（已收回）",
                        NotificationManager.IMPORTANCE_DEFAULT
                    ).apply {
                        description = "摇一摇自动记账结果（已从横幅收回）"
                        enableVibration(false)
                        setBypassDnd(true)
                        lockscreenVisibility = android.app.Notification.VISIBILITY_PUBLIC
                    }
                    manager.createNotificationChannel(channel)
                    android.util.Log.d(TAG, "📢 已创建收回收知渠道: $RESULT_RETRACTED_CHANNEL_ID")
                }
            } catch (_: Exception) {}
        }
    }

    private var shakeDetector: ShakeDetector? = null
    private var screenshotController: ScreenshotController? = null

    /** 截屏进行中标志，防止连续摇动触发多次并发截屏 */
    @Volatile
    private var isCapturing = false

    private val _captureHandler = Handler(Looper.getMainLooper())

    override fun onCreate() {
        super.onCreate()
        createProgressChannel()
    }

    override fun onServiceConnected() {
        super.onServiceConnected()
        isRunning = true
        instance = this
        // 缓存 Application Context，用于服务销毁后仍能发通知
        appContext = applicationContext

        // 不创建独立前台通知。KeepAliveService 的前台服务已为整个进程
        // 提供前台优先级，BillingAccessibilityService 在同一进程中可直接
        // 访问加速度传感器（Android 9+ 前台进程限制放宽）。

        LoggerPlugin.info(TAG, "onServiceConnected — 启动 ShakeDetector + ScreenshotController")

        screenshotController = ScreenshotController(this)

        shakeDetector = ShakeDetector(this) {
            // 锁屏时不响应摇一摇（屏幕熄灭 / 锁屏界面）
            if (shouldIgnoreShake()) {
                LoggerPlugin.info(TAG, "锁屏状态，忽略摇一摇触发")
                return@ShakeDetector
            }

            // 防止并发截图：前一次截图尚未完成时忽略新触发
            if (isCapturing) {
                return@ShakeDetector
            }
            isCapturing = true
            // 截屏看门狗：15 秒后自动复位，防止截屏回调失联导致永久卡死
            val watchdog = Runnable {
                if (isCapturing) {
                    isCapturing = false
                }
            }
            _captureHandler.postDelayed(watchdog, 15000)

            // 进度通知提示用户摇一摇已触发
            showProgressBanner()
            // 震动反馈
            vibratePhone()

            val watchdogRef = watchdog
            LoggerPlugin.info(TAG, "摇一摇触发，开始截屏...")
            screenshotController?.captureForAI { result ->
                _captureHandler.removeCallbacks(watchdogRef)
                isCapturing = false
                if (result != null) {
                    LoggerPlugin.info(TAG, "截屏成功: ${result.take(60)}")
                    // 🔴 确保 Dart Isolate 活着再发截屏结果
                    KeepAliveService.ensureFlutterEngine(this@BillingAccessibilityService)
                    // 发送截图到 Dart 处理
                    AccessibilityBridge.sendCaptureResult(result)
                    // 🔴 原生 15s 超时兜底（Dart 挂了/卡住时仍能弹超时通知）
                    startCaptureTimeout(result)
                } else {
                    LoggerPlugin.error(TAG, "截屏失败（takeScreenshot + 文本提取均无结果）")
                }
            }
        }
        shakeDetector?.start()
    }

    override fun onAccessibilityEvent(event: AccessibilityEvent?) {
        // 不需要处理 UI 事件，仅使用加速度传感器触发
    }

    override fun onInterrupt() {
        isRunning = false
        LoggerPlugin.warning(TAG, "无障碍服务被系统中断")
        // 通知 Flutter 侧，UI 可提示用户检查无障碍状态
        try {
            AccessibilityBridge.sendServiceInterrupted()
        } catch (e: Exception) {
            LoggerPlugin.error(TAG, "发送中断通知失败: ${e.message}")
        }
    }

    override fun onDestroy() {
        isRunning = false
        instance = null
        LoggerPlugin.info(TAG, "服务销毁 — 停止 ShakeDetector")
        _captureHandler.removeCallbacksAndMessages(null)
        shakeDetector?.stop()
        shakeDetector = null
        screenshotController = null
        super.onDestroy()
    }

    /** 弹出摇一摇进度 heads-up 通知（直到结果通知替换才消失） */
    private fun showProgressBanner() {
        try {
            // 每次发送前确保 channel 为 HIGH（国产 ROM 更新后可能重置渠道重要性）
            ensureProgressChannelHigh()

            // fullScreenIntent 强制国产 ROM 弹出 heads-up 横幅
            val launchIntent = Intent(this, com.tntlikely.beecount.MainActivity::class.java).apply {
                flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP
            }
            val fullScreenIntent = android.app.PendingIntent.getActivity(
                this, 0, launchIntent,
                android.app.PendingIntent.FLAG_IMMUTABLE or android.app.PendingIntent.FLAG_UPDATE_CURRENT
            )

            val notification = NotificationCompat.Builder(this, PROGRESS_CHANNEL_ID)
                .setContentTitle("蜜蜂记账")
                .setContentText("正在识别账单，请稍候…")
                .setSmallIcon(android.R.drawable.ic_popup_reminder)
                .setPriority(NotificationCompat.PRIORITY_HIGH)
                .setCategory(NotificationCompat.CATEGORY_ALARM)
                .setFullScreenIntent(fullScreenIntent, true)
                .setAutoCancel(true)
                .build()

            val manager = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
            manager.notify(PROGRESS_NOTIFICATION_ID, notification)
            LoggerPlugin.info(TAG, "进度通知已发送")
        } catch (e: Exception) {
            LoggerPlugin.error(TAG, "进度通知发送失败: ${e.message}")
        }
    }

    /**
     * 确保 [PROGRESS_CHANNEL_ID] 的 importance 为 HIGH。
     * 国产 ROM 更新 APK 后可能重置渠道，导致 heads-up 失效。
     */
    private fun ensureProgressChannelHigh() {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return
        try {
            val manager = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
            val existing = manager.getNotificationChannel(PROGRESS_CHANNEL_ID)
            if (existing == null || existing.importance < NotificationManager.IMPORTANCE_HIGH) {
                if (existing != null) {
                    manager.deleteNotificationChannel(PROGRESS_CHANNEL_ID)
                }
                val channel = android.app.NotificationChannel(
                    PROGRESS_CHANNEL_ID,
                    "摇一摇记账结果",
                    NotificationManager.IMPORTANCE_HIGH
                ).apply {
                    description = "摇一摇自动记账通知"
                    enableVibration(false)
                    setBypassDnd(true)
                    lockscreenVisibility = android.app.Notification.VISIBILITY_PUBLIC
                }
                manager.createNotificationChannel(channel)
            }
        } catch (_: Exception) {}
    }

    /**
     * 确保进度通知使用的 channel 已就绪。
     * 复用 [PROGRESS_CHANNEL_ID]（即 shake_result channel），
     * 该 channel 已在 [MainActivity.initBillingNotificationChannels] 中以
     * IMPORTANCE_HIGH + bypassDnd + VISIBILITY_PUBLIC 创建，
     * 用户若已为其开启横幅权限则可正常弹出 heads-up。
     */
    private fun createProgressChannel() {
        // channel 由 MainActivity 统一创建，此处仅确保其存在
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val manager = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
            if (manager.getNotificationChannel(PROGRESS_CHANNEL_ID) == null) {
                val channel = NotificationChannel(
                    PROGRESS_CHANNEL_ID,
                    "摇一摇记账结果",
                    NotificationManager.IMPORTANCE_HIGH
                ).apply {
                    description = "摇一摇自动记账通知"
                    // 不用渠道震动：由 vibratePhone() 统一控制震动反馈，避免重复
                    enableVibration(false)
                    setBypassDnd(true)
                    lockscreenVisibility = android.app.Notification.VISIBILITY_PUBLIC
                }
                manager.createNotificationChannel(channel)
            }
        }
    }

    /** 震动反馈，提示用户摇一摇已触发 */
    private fun vibratePhone(durationMs: Long = 200L) {
        try {
            val vibrator = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                val manager = getSystemService(Context.VIBRATOR_MANAGER_SERVICE) as VibratorManager
                manager.defaultVibrator
            } else {
                @Suppress("DEPRECATION")
                getSystemService(Context.VIBRATOR_SERVICE) as Vibrator
            }
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                vibrator.vibrate(
                    VibrationEffect.createOneShot(durationMs, VibrationEffect.DEFAULT_AMPLITUDE)
                )
            } else {
                @Suppress("DEPRECATION")
                vibrator.vibrate(durationMs)
            }
            android.util.Log.d(TAG, "📳 震动反馈 ${durationMs}ms")
        } catch (e: Exception) {
            android.util.Log.e(TAG, "❌ 震动失败: ${e.message}")
        }
    }

    /** 检测是否应忽略摇一摇触发（锁屏 / 屏幕熄灭） */
    private fun shouldIgnoreShake(): Boolean {
        // 屏幕熄灭（口袋/包里）
        val pm = getSystemService(Context.POWER_SERVICE) as PowerManager
        if (!pm.isInteractive) return true

        // 屏幕亮但处于锁屏界面
        val km = getSystemService(Context.KEYGUARD_SERVICE) as KeyguardManager
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            return km.isDeviceLocked
        }
        return km.isKeyguardLocked
    }

}
