import Foundation
import XCTest

final class WidgetImageManifestTests: XCTestCase {
    func testWidgetKitCanRenderBothAppearancesFromOneEntry() throws {
        let json = """
            {"locale":"system","theme":"system","images":{"zh-TW.light":"/tw-light","zh-TW.dark":"/tw-dark","en.dark":"/en-dark"},"fallback":"/fallback"}
            """
        let manifest = try JSONDecoder().decode(WidgetImageManifest.self, from: Data(json.utf8))
        let chinese = [Locale(identifier: "zh-Hant-HK")]
        XCTAssertEqual(manifest.preferredPath(locales: chinese, dark: false), "/tw-light")
        XCTAssertEqual(manifest.preferredPath(locales: chinese, dark: true), "/tw-dark")
        XCTAssertEqual(manifest.preferredPath(locales: [Locale(identifier: "en-GB")], dark: true), "/en-dark")
        XCTAssertNil(manifest.preferredPath(locales: [Locale(identifier: "ko")], dark: true))
        XCTAssertEqual(manifest.fallback, "/fallback")
    }

    func testChineseScriptPrecedesRegionAndUnsupportedLanguagesUseTheNextPreference() {
        let cases = [(["zh-Hans-TW"], "zh"), (["zh-Hant-CN"], "zh-TW"), (["zh-MO"], "zh-TW"),
                     (["zh-HK"], "zh-TW"), (["zh-TW"], "zh-TW"), (["zh-SG"], "zh"),
                     (["ja", "ko-KR"], "ko"), (["fr", "ru-RU", "en"], "ru"), (["fr"], "en")]
        for (identifiers, expected) in cases {
            XCTAssertEqual(WidgetImageManifest.language(for: identifiers.map(Locale.init(identifier:))), expected)
        }
    }

    func testPinnedSettingsOverrideOnlyTheirOwnDimension() {
        let ru = [Locale(identifier: "ru")]
        let pinnedLocale = WidgetImageManifest(locale: "en", theme: "system",
                                              images: ["en.dark": "/en-dark"], fallback: "")
        let pinnedTheme = WidgetImageManifest(locale: "system", theme: "light",
                                             images: ["ru.light": "/ru-light"], fallback: "")
        let pinnedBoth = WidgetImageManifest(locale: "zh-TW", theme: "light",
                                            images: ["zh-TW.light": "/tw-light"], fallback: "")
        XCTAssertEqual(pinnedLocale.preferredPath(locales: ru, dark: true), "/en-dark")
        XCTAssertEqual(pinnedTheme.preferredPath(locales: ru, dark: true), "/ru-light")
        XCTAssertEqual(pinnedBoth.preferredPath(locales: ru, dark: true), "/tw-light")
    }

    func testExistingWidgetSurvivesMissingOrInvalidManifestAndUsesNewFallbackWhenPublished() throws {
        let suite = "WidgetImageManifestTests." + UUID().uuidString
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let key = "widgetImage"
        defaults.set("/legacy", forKey: key)
        XCTAssertEqual(WidgetImageManifest.read(imageKey: key, from: defaults).fallback, "/legacy")
        defaults.set("invalid", forKey: key + ".appearance.v1")
        XCTAssertEqual(WidgetImageManifest.read(imageKey: key, from: defaults).fallback, "/legacy")
        defaults.set(#"{"locale":"system","theme":"system","images":{},"fallback":"/new"}"#,
                     forKey: key + ".appearance.v1")
        XCTAssertEqual(WidgetImageManifest.read(imageKey: key, from: defaults).fallback, "/new")
    }
}
