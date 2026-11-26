package com.tntlikely.beecount

import android.app.LocaleManager
import android.appwidget.AppWidgetManager
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.SharedPreferences
import android.graphics.BitmapFactory
import android.graphics.drawable.Icon
import android.os.Build
import android.os.LocaleList
import android.widget.RemoteViews
import org.json.JSONException
import org.json.JSONObject
import java.io.File
import java.io.IOException
import java.util.Locale

/** The image paths in a manifest all belong to the same ledger snapshot. */
internal data class WidgetArtwork(val light: String?, val dark: String?, val fallback: String?) {
    companion object {
        fun resolve(manifest: String?, legacyPath: String?, locales: List<Locale>): WidgetArtwork {
            val legacy = WidgetArtwork(null, null, legacyPath)
            if (manifest == null) return legacy
            val json = try {
                JSONObject(manifest)
            } catch (_: JSONException) {
                return legacy
            }
            val preference = json.opt("locale") as? String ?: return legacy
            val theme = json.opt("theme") as? String ?: return legacy
            val images = json.optJSONObject("images") ?: return legacy
            val fallback = json.opt("fallback") as? String ?: return legacy
            val locale = if (preference == "system") systemLocale(locales) else preference
            fun path(appearance: String): String? {
                val variant = if (theme == "system") appearance else theme
                return images.opt("$locale.$variant") as? String
            }
            return WidgetArtwork(path("light"), path("dark"), fallback)
        }

        private fun systemLocale(locales: List<Locale>): String {
            for (locale in locales) {
                when (locale.language) {
                    "en", "ko", "ru" -> return locale.language
                    "zh" -> {
                        val traditional = locale.script == "Hant" ||
                            (locale.script != "Hans" && locale.country in setOf("TW", "HK", "MO"))
                        return if (traditional) "zh-TW" else "zh"
                    }
                }
            }
            return "en"
        }
    }
}

@Suppress("DEPRECATION")
private fun Context.widgetLocales(): List<Locale> {
    if (Build.VERSION.SDK_INT < 24) return listOf(resources.configuration.locale)
    fun locales(list: LocaleList) = List(list.size()) { list[it] }
    if (Build.VERSION.SDK_INT >= 33) {
        val manager = getSystemService(LocaleManager::class.java)
        if (manager != null) return locales(manager.applicationLocales) + locales(manager.systemLocales)
    }
    // Resources may reorder the list to match an Android strings.xml. The images
    // support every Flutter locale, including languages without native resources.
    return locales(LocaleList.getDefault())
}

// Transport compressed PNGs. Two decoded large cards can exceed the launcher's
// per-widget bitmap budget, while the host only needs to decode one appearance.
private fun readArtworkIcon(path: String?): Icon? {
    if (path.isNullOrEmpty()) return null
    val bytes = try {
        File(path).readBytes()
    } catch (_: IOException) {
        return null
    }
    val bounds = BitmapFactory.Options().apply { inJustDecodeBounds = true }
    BitmapFactory.decodeByteArray(bytes, 0, bytes.size, bounds)
    if (bounds.outWidth <= 0 || bounds.outHeight <= 0) return null
    return Icon.createWithData(bytes, 0, bytes.size)
}

internal fun RemoteViews.setWidgetArtwork(context: Context, data: SharedPreferences, imageKey: String) {
    val artwork = WidgetArtwork.resolve(
        data.getString("$imageKey.appearance.v1", null), data.getString(imageKey, null), context.widgetLocales()
    )
    val fallback by lazy {
        readArtworkIcon(artwork.fallback) ?: Icon.createWithResource(context, R.mipmap.ic_launcher)
    }
    fun icon(path: String?) = if (path == artwork.fallback) fallback else readArtworkIcon(path) ?: fallback

    val light = icon(artwork.light)
    val dark = if (artwork.light == artwork.dark) light else icon(artwork.dark)
    if (Build.VERSION.SDK_INT >= 31) {
        // The launcher resolves this action in its own configuration on apply/reapply.
        if (light === dark) setImageViewIcon(R.id.widget_image, light)
        else setIcon(R.id.widget_image, "setImageIcon", light, dark)
    } else {
        // Before Android 12 the night-qualified layout gives the ImageView a different ID.
        // When the launcher reinflates, only the action for its current view is applied.
        setImageViewIcon(R.id.widget_image, light)
        setImageViewIcon(R.id.widget_image_dark, dark)
    }
}

/** LOCALE_CHANGED is delivered even when BeeCount has no running activity. */
class WidgetLocaleReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        if (intent.action != Intent.ACTION_LOCALE_CHANGED) return
        val manager = AppWidgetManager.getInstance(context)
        for (provider in manager.installedProviders) {
            if (provider.provider.packageName != context.packageName) continue
            val ids = manager.getAppWidgetIds(provider.provider)
            if (ids.isEmpty()) continue
            context.sendBroadcast(Intent(AppWidgetManager.ACTION_APPWIDGET_UPDATE).apply {
                component = provider.provider
                putExtra(AppWidgetManager.EXTRA_APPWIDGET_IDS, ids)
            })
        }
    }
}
