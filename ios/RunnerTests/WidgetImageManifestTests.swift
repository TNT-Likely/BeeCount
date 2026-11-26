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
        XCTAssertNil(manifest.preferredPath(locales: [Locale(identifier: "zh-Hans")], dark: true))
        XCTAssertEqual(manifest.fallback, "/fallback")
    }

    func testChineseScriptPrecedesRegionAndUnsupportedLanguagesUseTheNextPreference() {
        let cases = [(["zh-Hans-TW"], "zh"), (["zh-Hant-CN"], "zh-TW"), (["zh-MO"], "zh-TW"),
                     (["zh-HK"], "zh-TW"), (["zh-TW"], "zh-TW"), (["zh-SG"], "zh"),
                     (["und", "zh-HK", "en"], "zh-TW"), (["und", "en-GB", "zh"], "en"), ([], "en")]
        for (identifiers, expected) in cases {
            XCTAssertEqual(WidgetImageManifest.language(for: identifiers.map(Locale.init(identifier:))), expected)
        }
    }

    func testGalleryLoadsOnlyLocalizedArtworkFromItsBundle() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString + ".bundle")
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        try Data("<?xml version=\"1.0\"?><plist version=\"1.0\"><dict><key>CFBundleIdentifier</key><string>test.widgetPreviews</string></dict></plist>".utf8)
            .write(to: directory.appendingPathComponent("Info.plist"))
        let names = ["en", "en_dark", "zh", "zh_dark", "zh_TW_dark"]
        for name in names {
            try Data().write(to: directory.appendingPathComponent("widget_preview_glance_" + name + ".png"))
        }
        let bundle = try XCTUnwrap(Bundle(url: directory))
        func resource(_ locale: String, _ dark: Bool, _ key: String = "widgetImage") -> String {
            let path = WidgetPreviewAssets.path(forImageKey: key, locales: [Locale(identifier: locale)],
                                                dark: dark, bundle: bundle)
            return (path as NSString).lastPathComponent
        }
        XCTAssertEqual(resource("zh-Hant-HK", true), "widget_preview_glance_zh_TW_dark.png")
        XCTAssertEqual(resource("zh-Hant-HK", false), "widget_preview_glance_zh.png")
        XCTAssertEqual(resource("zh-Hans-TW", true), "widget_preview_glance_zh_dark.png")
        XCTAssertEqual(resource("en-GB", false), "widget_preview_glance_en.png")
        XCTAssertEqual(resource("und", true), "widget_preview_glance_en_dark.png")
        XCTAssertEqual(resource("en", true, "missing"), "")
        XCTAssertEqual(resource("en", true, "widget_dashboard_large"), "")
    }

    func testPinnedSettingsOverrideOnlyTheirOwnDimension() {
        let chinese = [Locale(identifier: "zh-Hans-CN")]
        let pinnedLocale = WidgetImageManifest(locale: "en", theme: "system",
                                              images: ["en.dark": "/en-dark"], fallback: "")
        let pinnedTheme = WidgetImageManifest(locale: "system", theme: "light",
                                             images: ["zh.light": "/zh-light"], fallback: "")
        let pinnedBoth = WidgetImageManifest(locale: "zh-TW", theme: "light",
                                            images: ["zh-TW.light": "/tw-light"], fallback: "")
        XCTAssertEqual(pinnedLocale.preferredPath(locales: chinese, dark: true), "/en-dark")
        XCTAssertEqual(pinnedTheme.preferredPath(locales: chinese, dark: true), "/zh-light")
        XCTAssertEqual(pinnedBoth.preferredPath(locales: chinese, dark: true), "/tw-light")
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
