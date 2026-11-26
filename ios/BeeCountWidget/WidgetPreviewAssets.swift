import Foundation

/// Synthetic chooser previews live in the extension bundle. Runtime ledger
/// images are read only for placed widgets by WidgetImageContent.
enum WidgetPreviewAssets {
    private static let assetByImageKey: [String: String] = [
        "widgetImage": "widget_preview_glance",
        "widget_glance_small": "widget_preview_glance_small",
        "widget_netWorth_small": "widget_preview_networth_small",
        "widget_netWorth_medium": "widget_preview_networth",
        "widget_netWorth_large": "widget_preview_networth_large",
        "widget_quickAdd_small": "widget_preview_quickadd",
        "widget_quickAdd_medium": "widget_preview_quickadd_medium",
        "widget_budget_small": "widget_preview_budget",
        "widget_budget_medium": "widget_preview_budget_medium",
        "widget_recent_medium": "widget_preview_recent",
        "widget_recent_large": "widget_preview_recent_large",
        "widget_dashboard_large": "widget_preview_dashboard",
        "widget_consumptionRhythm_medium": "widget_preview_consumption_rhythm",
        "widget_beeTrail_small": "widget_preview_bee_trail",
    ]

    static func path(forImageKey imageKey: String, locales: [Locale], dark: Bool,
                     bundle: Bundle = .main) -> String {
        guard let base = assetByImageKey[imageKey] else { return "" }
        let languages: [String]
        switch WidgetImageManifest.language(for: locales) {
        case "zh-TW": languages = ["zh_TW", "zh", "en"]
        case "zh": languages = ["zh", "en"]
        default: languages = ["en", "zh"]
        }

        for tag in languages {
            let name = "\(base)_\(tag)"
            if dark, let path = bundle.path(forResource: name + "_dark", ofType: "png") {
                return path
            }
            if let path = bundle.path(forResource: name, ofType: "png") { return path }
        }
        return ""
    }
}
