package com.tntlikely.beecount

import android.accessibilityservice.AccessibilityService
import android.graphics.Bitmap
import android.graphics.PixelFormat
import android.graphics.Picture
import android.os.Build
import android.view.Display
import android.view.accessibility.AccessibilityNodeInfo
import androidx.annotation.RequiresApi
import java.io.File

private const val TAG = "ScreenshotController"

/**
 * 截图控制器。
 *
 * 核心截图能力，封装 API 31+ 的 `takeScreenshot()`，并提供 API 30- 降级方案。
 *
 * - API 31+：takeScreenshot() → PNG 文件路径
 * - API 30-：提取节点文本 → "text:" + 文本内容（Flutter 侧据此分流）
 */
class ScreenshotController(private val service: AccessibilityService) {

    private val cacheDir: File
        get() = File(service.cacheDir, "screenshots").also { it.mkdirs() }

    /**
     * 截取或提取当前屏幕信息。
     *
     * @param onResult 回调：PNG 文件路径 或 "text:" + 提取的节点文本
     */
    fun captureForAI(onResult: (String?) -> Unit) {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            captureByApiWithFallback(onResult)
        } else {
            captureByNodeText(onResult)
        }
    }

    @RequiresApi(Build.VERSION_CODES.S)
    private fun captureByApiWithFallback(onResult: (String?) -> Unit) {
        LoggerPlugin.info(TAG, "调用 takeScreenshot()")
        service.takeScreenshot(
            Display.DEFAULT_DISPLAY,
            service.mainExecutor,
            object : AccessibilityService.TakeScreenshotCallback {
                override fun onSuccess(result: AccessibilityService.ScreenshotResult) {
                    val buffer = result.hardwareBuffer ?: run {
                        LoggerPlugin.warning(TAG, "takeScreenshot hardwareBuffer 为 null，降级到文本提取")
                        captureByNodeText(onResult)
                        return@onSuccess
                    }
                    val bitmap = Bitmap.wrapHardwareBuffer(buffer, null) ?: run {
                        LoggerPlugin.warning(TAG, "wrapHardwareBuffer 失败，降级到文本提取")
                        buffer.close()
                        captureByNodeText(onResult)
                        return@onSuccess
                    }
                    val file = File(cacheDir, "auto_bill_${System.currentTimeMillis()}.png")
                    try {
                        file.outputStream().use { out ->
                            bitmap.compress(Bitmap.CompressFormat.PNG, 90, out)
                        }
                        LoggerPlugin.info(TAG, "截屏成功，保存到 ${file.absolutePath} (${file.length()} bytes)")
                        onResult(file.absolutePath)
                    } catch (e: Exception) {
                        LoggerPlugin.error(TAG, "保存截屏图片失败: ${e.message}，降级到文本提取")
                        captureByNodeText(onResult)
                    } finally {
                        buffer.close()
                    }
                }

                override fun onFailure(errorCode: Int) {
                    LoggerPlugin.warning(TAG, "takeScreenshot 失败(errorCode=$errorCode)，降级到文本提取")
                    captureByNodeText(onResult)
                }
            }
        )
    }

    /**
     * API 30- 降级方案：提取当前窗口的 Accessibility 节点文本。
     *
     * 输出格式为 "text:" + 提取的文本，Flutter 侧根据前缀走
     * AiBookkeeper.fromText()（文字 AI 记账）。
     */
    private fun captureByNodeText(onResult: (String?) -> Unit) {
        val root = service.rootInActiveWindow ?: run {
            LoggerPlugin.error(TAG, "文本提取失败: rootInActiveWindow 为 null")
            onResult(null)
            return
        }
        val text = extractAllText(root)
        if (text.isBlank()) {
            LoggerPlugin.warning(TAG, "文本提取失败: 节点文本为空")
            onResult(null)
            return
        }
        LoggerPlugin.info(TAG, "文本提取成功: ${text.length} 字符")
        onResult("text:$text")
    }

    /** 递归提取节点中的全部文本 */
    private fun extractAllText(node: AccessibilityNodeInfo?): String {
        if (node == null) return ""
        val sb = StringBuilder()
        if (!node.text.isNullOrBlank()) {
            sb.appendLine(node.text)
        }
        for (i in 0 until node.childCount) {
            sb.append(extractAllText(node.getChild(i)))
        }
        return sb.toString()
    }

    /** 清理缓存目录中的所有截图文件 */
    fun cleanup() {
        val dir = cacheDir
        if (dir.exists()) {
            dir.listFiles()?.forEach { it.delete() }
        }
    }
}
