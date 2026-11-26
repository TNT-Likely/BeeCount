import SwiftUI
import UIKit
import WidgetKit

struct WidgetImageEntry: TimelineEntry {
    enum Source {
        case preview(imageKey: String)
        case runtime(WidgetImageManifest)
    }

    let date: Date
    let source: Source
}

protocol WidgetImageProviding: TimelineProvider where Entry == WidgetImageEntry {
    func imageKey(for family: WidgetFamily) -> String
}

extension WidgetImageProviding {
    func placeholder(in context: Context) -> WidgetImageEntry {
        WidgetImageEntry(date: Date(), source: .preview(imageKey: imageKey(for: context.family)))
    }

    func getSnapshot(in context: Context, completion: @escaping (WidgetImageEntry) -> Void) {
        completion(entry(in: context))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<WidgetImageEntry>) -> Void) {
        let entry = entry(in: context)
        completion(Timeline(entries: [entry], policy: .after(entry.date.addingTimeInterval(30 * 60))))
    }

    private func entry(in context: Context) -> WidgetImageEntry {
        if context.isPreview { return placeholder(in: context) }
        let manifest = WidgetImageManifest.read(
            imageKey: imageKey(for: context.family),
            from: UserDefaults(suiteName: "group.com.tntlikely.beecount")
        )
        return WidgetImageEntry(date: Date(), source: .runtime(manifest))
    }
}

/// WidgetKit can render a single timeline entry in both light and dark ahead of time.
/// Select the image here, inside the view with the actual rendering environment.
struct WidgetImageContent<Content: View>: View {
    let entry: WidgetImageEntry
    @ViewBuilder let content: (UIImage?) -> Content
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.locale) private var locale

    private var image: UIImage? {
        let locales = [locale] + Locale.preferredLanguages.map(Locale.init(identifier:))
        switch entry.source {
        case .preview(let key):
            let path = WidgetPreviewAssets.path(forImageKey: key, locales: locales)
            return UIImage(contentsOfFile: path)
        case .runtime(let manifest):
            if let path = manifest.preferredPath(locales: locales, dark: colorScheme == .dark),
               let image = UIImage(contentsOfFile: path) {
                return image
            }
            return UIImage(contentsOfFile: manifest.fallback)
        }
    }

    var body: some View {
        if #available(iOS 17.0, *) {
            content(image).containerBackground(for: .widget) { Color.clear }
        } else {
            content(image)
        }
    }
}
