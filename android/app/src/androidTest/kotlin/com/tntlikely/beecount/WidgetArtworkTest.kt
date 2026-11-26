package com.tntlikely.beecount

import androidx.test.ext.junit.runners.AndroidJUnit4
import org.json.JSONObject
import org.junit.Assert.assertEquals
import org.junit.Test
import org.junit.runner.RunWith
import java.util.Locale

@RunWith(AndroidJUnit4::class)
class WidgetArtworkTest {
    private val images = JSONObject().apply {
        for (locale in listOf("en", "zh", "zh-TW", "ko", "ru")) {
            for (theme in listOf("light", "dark")) put("$locale.$theme", "/$locale.$theme.png")
        }
    }
    private fun artwork(preferred: String, locale: String = "system", theme: String = "system"): WidgetArtwork {
        val manifest = JSONObject().put("images", images).put("locale", locale).put("theme", theme)
            .put("fallback", "/current.png")
        return WidgetArtwork.resolve(manifest.toString(), "/previous.png",
            preferred.split(',').map { Locale.forLanguageTag(it) })
    }

    @Test fun followsScriptRegionAndOrderedLanguagePreferences() {
        for (tag in listOf("zh-Hant", "zh-HK", "zh-MO", "zh-TW", "zh-Latn-HK")) {
            assertEquals("/zh-TW.dark.png", artwork(tag).dark)
        }
        assertEquals("/zh.light.png", artwork("zh-Hans-TW").light)
        assertEquals("/ko.light.png", artwork("fr-FR,ko-KR,en-GB").light)
        assertEquals("/ru.dark.png", artwork("ru-RU").dark)
        assertEquals("/en.light.png", artwork("es-ES").light)
    }

    @Test fun explicitAppPreferencesOverrideTheLauncher() {
        val fixed = artwork("zh-TW", "en", "dark")
        assertEquals("/en.dark.png", fixed.light)
        assertEquals(fixed.light, fixed.dark)
    }

    @Test fun usesLegacyForMissingOrCorruptManifestAndCurrentFallbackForPartialSets() {
        assertEquals("/previous.png", WidgetArtwork.resolve(null, "/previous.png", emptyList()).fallback)
        assertEquals("/previous.png", WidgetArtwork.resolve("{", "/previous.png", emptyList()).fallback)
        assertEquals("/previous.png", WidgetArtwork.resolve("{}", "/previous.png", emptyList()).fallback)
        val partial = JSONObject().put("locale", "system").put("theme", "system")
            .put("images", JSONObject()).put("fallback", "/current.png").toString()
        assertEquals(WidgetArtwork(null, null, "/current.png"),
            WidgetArtwork.resolve(partial, "/previous.png", emptyList()))
    }
}
