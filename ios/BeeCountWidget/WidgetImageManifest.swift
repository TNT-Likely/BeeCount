import Foundation

/// Flutter publishes the variant paths for one widget size and one set of ledger data together.
struct WidgetImageManifest: Decodable {
    let locale: String
    let theme: String
    let images: [String: String]
    let fallback: String

    static func read(imageKey: String, from defaults: UserDefaults?) -> Self {
        if let json = defaults?.string(forKey: imageKey + ".appearance.v1"),
           let manifest = try? JSONDecoder().decode(Self.self, from: Data(json.utf8)) {
            return manifest
        }
        // Widgets installed before the app first prepares appearance variants still have this key.
        return Self(locale: "system", theme: "system", images: [:],
                    fallback: defaults?.string(forKey: imageKey) ?? "")
    }

    static func language(for candidates: [Locale]) -> String {
        for candidate in candidates {
            guard let code = candidate.languageCode else { continue }
            switch code {
            case "en", "ko", "ru": return code
            case "zh":
                if candidate.scriptCode == "Hant" { return "zh-TW" }
                if candidate.scriptCode == "Hans" { return "zh" }
                return ["TW", "HK", "MO"].contains(candidate.regionCode ?? "") ? "zh-TW" : "zh"
            default:
                continue
            }
        }
        return "en"
    }

    func preferredPath(locales: [Locale], dark: Bool) -> String? {
        let language = locale == "system" ? Self.language(for: locales) : locale
        let scheme = theme == "system" ? (dark ? "dark" : "light") : theme
        return images["\(language).\(scheme)"]
    }
}
