package com.tntlikely.beecount

import android.app.AlarmManager
import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.os.SystemClock
import androidx.core.app.NotificationCompat
import androidx.test.ext.junit.runners.AndroidJUnit4
import androidx.test.platform.app.InstrumentationRegistry
import androidx.test.uiautomator.By
import androidx.test.uiautomator.UiDevice
import androidx.test.uiautomator.UiObject2
import androidx.test.uiautomator.Until
import org.junit.Assert.*
import org.junit.Test
import org.junit.runner.RunWith
import java.io.File
import org.json.JSONArray
import org.json.JSONObject

@RunWith(AndroidJUnit4::class)
class NotificationBadgeTest {
    @Test fun clearsDeliveredBadgesAndPreservesTasksAndFutureReminder() {
        val instrumentation = InstrumentationRegistry.getInstrumentation()
        val context = instrumentation.targetContext
        // This test must never execute in a user's installed package or device.
        check(context.packageName == "com.tntlikely.beecount.qa.dev.debug")
        val device = UiDevice.getInstance(instrumentation)
        val manager = context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        val evidence = File(context.filesDir, "badge-qa").apply { mkdirs() }
        context.getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
            .edit().putBoolean("flutter.welcome_shown", true)
            .putString("flutter.selected_language", "zh").commit()
        manager.createNotificationChannel(NotificationChannel("accounting_reminder", "QA reminder", NotificationManager.IMPORTANCE_HIGH))
        manager.createNotificationChannel(NotificationChannel("accounting_reminder_backup", "QA backup", NotificationManager.IMPORTANCE_HIGH))
        manager.createNotificationChannel(NotificationChannel("screenshot_ocr", "QA result", NotificationManager.IMPORTANCE_DEFAULT))
        manager.createNotificationChannel(NotificationChannel("update_download", "QA download", NotificationManager.IMPORTANCE_LOW).apply { setShowBadge(false) })

        fun post(id: Int, channel: String = "accounting_reminder", ongoing: Boolean = false, tag: String? = null) {
            val intent = Intent(context, MainActivity::class.java).addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            val click = PendingIntent.getActivity(context, id, intent, PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE)
            val n = NotificationCompat.Builder(context, channel)
                .setSmallIcon(android.R.drawable.ic_dialog_info)
                .setContentTitle("QA badge $id").setContentText("Synthetic notification")
                .setContentIntent(click).setAutoCancel(false).setOngoing(ongoing).build()
            manager.notify(tag, id, n)
        }
        // Android 17 会额外生成分组摘要；只按本轮合成通知的身份核对业务结果。
        fun ids() = manager.activeNotifications.map { it.id }.filter { it in 5571..5580 }.toSet()
        fun waitUntil(message: String, timeout: Long = 15000, ready: () -> Boolean) {
            val deadline = SystemClock.elapsedRealtime() + timeout
            while (!ready() && SystemClock.elapsedRealtime() < deadline) SystemClock.sleep(100)
            assertTrue(message, ready())
        }
        fun capture(name: String) { assertTrue(device.takeScreenshot(File(evidence, "$name.png"))) }
        fun home() { device.pressHome(); device.waitForIdle() }
        fun icon(): UiObject2 {
            var item = device.findObject(By.text("BeeCount QA"))
            if (item == null) {
                home()
                device.swipe(device.displayWidth / 2, device.displayHeight * 9 / 10,
                    device.displayWidth / 2, device.displayHeight / 4, 25)
                item = device.wait(Until.findObject(By.text("BeeCount QA")), 10000)
            }
            return checkNotNull(item) { "Owned QA icon must be visible in the actual launcher" }
        }
        val iconChecks = JSONArray()
        fun captureIcon(name: String, expectedBadge: Boolean) {
            icon()
            var description = ""
            waitUntil("Launcher notification dot: $name") {
                description = device.findObject(By.text("BeeCount QA"))?.contentDescription ?: ""
                val hasBadge = description.contains("notification", ignoreCase = true) || description.contains("通知")
                description.isNotEmpty() && hasBadge == expectedBadge
            }
            iconChecks.put(JSONObject().put("stage", name).put("badge", expectedBadge).put("description", description))
            File(evidence, "launcher-badges.json").writeText(iconChecks.toString(2))
            capture(name)
        }
        fun launch() {
            icon().click()
            assertTrue(device.wait(Until.hasObject(By.pkg(context.packageName).depth(0)), 30000))
        }

        // Cold Activity entry clears legacy autoCancel=false and tagged notifications.
        home()
        post(5571)
        post(5572, "accounting_reminder_backup", tag = "backup")
        post(5573, "screenshot_ocr")
        post(5574, "update_download", ongoing = true)
        post(5575, "update_download")
        waitUntil("Synthetic notifications were delivered") { ids().containsAll((5571..5575).toList()) }
        captureIcon("android-cold-before", true)
        launch()
        waitUntil("Cold entry clears read badges only") { ids() == setOf(5574, 5575) }
        capture("android-cold-app")
        home()
        captureIcon("android-cold-after", false)

        // Schedule a real future alarm before resuming, then prove it still fires.
        val alarmIntent = Intent(context, NotificationReceiver::class.java)
            .setAction("${context.packageName}.NOTIFICATION_ALARM")
            .putExtra("notificationId", 5580).putExtra("title", "QA future reminder")
            .putExtra("body", "Future reminder survives badge clearing")
        val alarm = PendingIntent.getBroadcast(context, 5580, alarmIntent, PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE)
        val alarms = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager
        alarms.setExactAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, System.currentTimeMillis() + 30000, alarm)
        home()
        post(5577)
        waitUntil("Background notification was delivered") { 5577 in ids() }
        captureIcon("android-resume-before", true)
        launch()
        waitUntil("Resume clears the delivered notification") { 5577 !in ids() }
        assertNotNull(PendingIntent.getBroadcast(context, 5580, alarmIntent, PendingIntent.FLAG_NO_CREATE or PendingIntent.FLAG_IMMUTABLE))
        assertTrue(ids().containsAll(listOf(5574, 5575)))
        home()
        captureIcon("android-resume-after", false)
        waitUntil("Future reminder still fires after badge clearing", 45000) { 5580 in ids() }
        captureIcon("android-future-reminder", true)

        // Tap an actual delivered legacy notification to open the production Activity.
        post(5578)
        device.openNotification()
        val row = device.wait(Until.findObject(By.text("QA badge 5578")), 10000)
        assertNotNull(row)
        checkNotNull(row).click()
        assertTrue(device.wait(Until.hasObject(By.pkg(context.packageName).depth(0)), 20000))
        waitUntil("Notification tap clears stale delivered notifications") { ids() == setOf(5574, 5575) }
        capture("android-tap-after")
        // A protected task must survive even if its channel supports badges.
        post(5576, ongoing = true)
        repeat(3) {
            home(); launch()
            assertEquals(setOf(5574, 5575, 5576), ids())
        }
        // Remove only the test's persistent task fixtures before human review.
        for (id in listOf(5574, 5575, 5576)) manager.cancel(id)
        assertTrue(ids().isEmpty())
        capture("android-final-app")
        File(evidence, "result.json").writeText("""{"status":"PASS","cases":["cold-entry","tagged-notifications","resume","launcher-dot-before-after","ongoing-preserved","nonbadging-channel-preserved","future-reminder-delivered","notification-tap","repeated-resume"],"cloud":"not-applicable"}""")
    }
}
