package com.tntlikely.beecount

import android.content.Context
import android.hardware.Sensor
import android.hardware.SensorEvent
import android.hardware.SensorEventListener
import android.hardware.SensorManager
import android.os.Build
import android.os.Handler
import android.os.Looper
import kotlin.math.sqrt

/**
 * 摇一摇检测器 — 抗误触算法。
 *
 * 核心思路：除了峰值计数，还检查**峰值节奏**，拒绝走路、放包等非有意动作。
 *
 * 误触场景分析：
 * - 走路：幅度 6-10g，步频 ~120步/分 → 峰值间隔 ~500ms，间隔过大
 * - 放包/拿手机：幅度 15-20g，但只有 1-2 个脉冲，没有持续振荡
 * - 有意摇动：幅度 10-18g，5-8 个峰值，间隔 100-250ms，持续 0.8-1.5s
 *
 * 算法要点：
 * 1. 阈值 12.0：排除走路等低幅动作
 * 2. 最少 5 个峰值：排除单次脉冲（放包/磕碰）
 * 3. 峰值间隔 ≤ 350ms：排除慢节奏运动（走路）
 * 4. 紧凑窗口 1.2s：只统计密集的摇晃能量
 * 5. 防抖 3s：避免连续触发
 */
class ShakeDetector(
    private val context: Context,
    private val onShake: () -> Unit
) : SensorEventListener {

    private val sensorManager: SensorManager =
        context.getSystemService(Context.SENSOR_SERVICE) as SensorManager

    companion object {
        private const val TAG = "ShakeDetector"

        /** Jerk 幅度阈值，超过此值视为峰值候选 */
        private const val SHAKE_THRESHOLD = 12.0f

        /** 防抖间隔（毫秒），两次摇一摇之间至少间隔 3 秒 */
        private const val COOLDOWN_MS = 3000L

        /** 峰值统计窗口（毫秒），在此时间内统计峰值数量 */
        private const val PEAK_WINDOW_MS = 1200L

        /** 触发所需的最小峰值数量 */
        private const val MIN_PEAKS = 5

        /** 连续峰值最大间隔（毫秒），超过此值认为节奏中断、清空窗口 */
        private const val MAX_PEAK_INTERVAL_MS = 350L

        /** 高通滤波器系数，越大重力过滤越彻底 */
        private const val ALPHA = 0.8f
    }

    // 高通滤波状态
    private var hpX = 0f
    private var hpY = 0f
    private var hpZ = 0f
    private var lastRawX = 0f
    private var lastRawY = 0f
    private var lastRawZ = 0f
    private var hasInitialValues = false

    // 峰值检测状态
    private var isAboveThreshold = false
    private val peakTimes = mutableListOf<Long>()
    private var lastShakeTime = 0L
    private var lastLogTime = 0L
    private var sensorEventCount = 0
    /** 用于间隔检查的上一个峰值时间 */
    private var lastPeakTime = 0L

    /** 开始监听加速度传感器 */
    fun start() {
        val sensor = sensorManager.getDefaultSensor(Sensor.TYPE_ACCELEROMETER)
        if (sensor == null) {
            LoggerPlugin.error(TAG, "设备不支持加速度传感器")
            return
        }
        val registered = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.KITKAT) {
            sensorManager.registerListener(
                this, sensor,
                SensorManager.SENSOR_DELAY_UI,
                Handler(Looper.getMainLooper())
            )
        } else {
            sensorManager.registerListener(
                this, sensor,
                SensorManager.SENSOR_DELAY_UI
            )
        }
        if (registered) {
            LoggerPlugin.info(TAG, "加速度传感器监听已注册")
        } else {
            LoggerPlugin.error(TAG, "加速度传感器注册失败！")
        }
        sensorEventCount = 0
        lastLogTime = System.currentTimeMillis()
    }

    fun isRegistered(): Boolean {
        return sensorEventCount > 0
    }

    /** 停止监听 */
    fun stop() {
        sensorManager.unregisterListener(this)
        LoggerPlugin.info(TAG, "加速度传感器监听已注销")
        resetState()
    }

    private fun resetState() {
        hasInitialValues = false
        hpX = 0f
        hpY = 0f
        hpZ = 0f
        lastRawX = 0f
        lastRawY = 0f
        lastRawZ = 0f
        isAboveThreshold = false
        lastPeakTime = 0L
        peakTimes.clear()
    }

    override fun onSensorChanged(event: SensorEvent) {
        val now = System.currentTimeMillis()
        sensorEventCount++

        // 节流日志：每 5 秒输出一次传感器事件接收状态
        if (now - lastLogTime > 5000) {
            android.util.Log.d(TAG, "📡 传感器事件: count=$sensorEventCount peaks=${peakTimes.size} 距上次日志=${now - lastLogTime}ms")
            lastLogTime = now
        }

        // 防抖（冷却期内丢弃所有事件）
        if (now - lastShakeTime < COOLDOWN_MS) return

        val rawX = event.values[0]
        val rawY = event.values[1]
        val rawZ = event.values[2]

        if (!hasInitialValues) {
            lastRawX = rawX
            lastRawY = rawY
            lastRawZ = rawZ
            hpX = 0f
            hpY = 0f
            hpZ = 0f
            hasInitialValues = true
            android.util.Log.d(TAG, "📡 传感器初始化完成，开始接收事件")
            return
        }

        // 高通滤波器：hp = alpha * (hp + raw - lastRaw)
        // 去除重力等低频分量，保留摇晃产生的高频分量
        hpX = ALPHA * (hpX + rawX - lastRawX)
        hpY = ALPHA * (hpY + rawY - lastRawY)
        hpZ = ALPHA * (hpZ + rawZ - lastRawZ)

        lastRawX = rawX
        lastRawY = rawY
        lastRawZ = rawZ

        // 计算 jerk 幅度（经过高通滤波后的加速度变化量）
        val magnitude = sqrt(hpX * hpX + hpY * hpY + hpZ * hpZ)

        // 幅度较大时输出调试日志（节流 2 秒）
        if (magnitude > 5.0f && now - lastLogTime > 2000) {
            android.util.Log.d(TAG, "📊 magnitude=%.1f  threshold=%.0f  peaks=%d/%d  count=%d".format(
                magnitude, SHAKE_THRESHOLD, peakTimes.size, MIN_PEAKS, sensorEventCount))
        }

        // ---- 节奏检查：清空过期峰值 ----
        // 先清理超出统计窗口的旧峰值
        val cutoff = now - PEAK_WINDOW_MS
        peakTimes.removeAll { it < cutoff }
        // 如果窗口内还有峰值但最后一个太老，说明节奏中断 → 清空重新计数
        if (peakTimes.isNotEmpty() && now - peakTimes.last() > MAX_PEAK_INTERVAL_MS) {
            android.util.Log.d(TAG, "🔄 节奏中断（距上峰值 ${now - peakTimes.last()}ms > ${MAX_PEAK_INTERVAL_MS}ms），清空窗口")
            peakTimes.clear()
            isAboveThreshold = false
            lastPeakTime = 0L
        }

        // ---- 峰值检测 ----
        if (magnitude > SHAKE_THRESHOLD && !isAboveThreshold) {
            // 进入阈值 - 记录新峰值
            isAboveThreshold = true

            // 检查峰值间隔：如果上一次峰值太近（<50ms）则忽略（防止双峰噪声）
            val intervalOk = if (lastPeakTime == 0L) true else (now - lastPeakTime >= 50L)
            if (intervalOk) {
                peakTimes.add(now)
                lastPeakTime = now
                android.util.Log.d(TAG, "⚡ 峰值 #${peakTimes.size}: magnitude=%.1f  peaks=%d/%d".format(
                    magnitude, peakTimes.size, MIN_PEAKS))
            } else {
                android.util.Log.v(TAG, "↺ 忽略过近峰值（距上 ${now - lastPeakTime}ms）")
            }
        } else if (magnitude <= SHAKE_THRESHOLD && isAboveThreshold) {
            // 离开阈值 - 峰值结束
            isAboveThreshold = false
        }

        // ---- 触发判定 ----
        if (peakTimes.size >= MIN_PEAKS) {
            val firstPeak = peakTimes.first()
            val duration = now - firstPeak
            LoggerPlugin.info(TAG, "摇一摇触发！峰值=${peakTimes.size} 历时=${duration}ms")
            lastShakeTime = now
            peakTimes.clear()
            isAboveThreshold = false
            lastPeakTime = 0L
            onShake()
        }
    }

    override fun onAccuracyChanged(sensor: Sensor?, accuracy: Int) {
        // 不需要处理
    }
}
