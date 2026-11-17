import WidgetKit
import SwiftUI
import UIKit

/// 组件目标内共用的多语言文案 helper(按系统语言取词)。韩语不单独声明,
/// 与其他未覆盖语言一同走英文兜底(developmentRegion = en)。
enum BehaviorWidgetCopy {
    static func localized(
        simplifiedChinese: String,
        traditionalChinese: String,
        english: String
    ) -> String {
        let locale = Locale.current
        switch locale.languageCode {
        case "en": return english
        case "zh" where locale.scriptCode == "Hant" || locale.regionCode == "TW" || locale.regionCode == "HK":
            return traditionalChinese
        default: return simplifiedChinese
        }
    }
}

private struct BehaviorWidgetEntry: TimelineEntry {
    let date: Date
    let imagePath: String
}

private struct BehaviorWidgetProvider: TimelineProvider {
    let imageKey: String

    private func runtimeEntry() -> BehaviorWidgetEntry {
        let path = UserDefaults(suiteName: "group.com.tntlikely.beecount")?.string(forKey: imageKey) ?? ""
        return BehaviorWidgetEntry(date: Date(), imagePath: path)
    }

    private func previewEntry() -> BehaviorWidgetEntry {
        BehaviorWidgetEntry(
            date: Date(),
            imagePath: WidgetPreviewAssets.path(forImageKey: imageKey)
        )
    }

    func placeholder(in context: Context) -> BehaviorWidgetEntry {
        previewEntry()
    }

    func getSnapshot(in context: Context, completion: @escaping (BehaviorWidgetEntry) -> ()) {
        // Widget gallery 的预览上下文无法稳定读取 App Group；与既有组件
        // 一致，改读扩展 bundle 内的静态预览图。
        completion(context.isPreview ? previewEntry() : runtimeEntry())
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<BehaviorWidgetEntry>) -> ()) {
        let next = Calendar.current.date(byAdding: .minute, value: 30, to: Date())!
        completion(Timeline(entries: [runtimeEntry()], policy: .after(next)))
    }
}

private struct BehaviorWidgetEntryView: View {
    let entry: BehaviorWidgetEntry
    let destination: URL
    let symbol: String
    let label: String

    var body: some View {
        if let image = UIImage(contentsOfFile: entry.imagePath) {
            Link(destination: destination) {
                Image(uiImage: image).resizable().scaledToFill().frame(maxWidth: .infinity, maxHeight: .infinity).clipped()
            }
        } else {
            ZStack {
                Color(red: 1.0, green: 0.76, blue: 0.03)
                VStack { Image(systemName: symbol).font(.system(size: 28)); Text(label).font(.system(size: 13, weight: .semibold)) }.foregroundColor(.white)
            }.widgetURL(destination)
        }
    }
}

struct BeeCountConsumptionRhythmWidget: Widget {
    let kind = "BeeCountConsumptionRhythmWidget"
    private var title: String {
        BehaviorWidgetCopy.localized(simplifiedChinese: "消费节奏", traditionalChinese: "消費節奏", english: "Spending Rhythm")
    }
    private var description: String {
        BehaviorWidgetCopy.localized(simplifiedChinese: "近 30 天消费节奏一眼看清", traditionalChinese: "近 30 天消費節奏一眼看清", english: "See your spending pace across the last 30 days")
    }
    var body: some WidgetConfiguration {
        let widgetTitle = title
        let widgetDescription = description
        return StaticConfiguration(kind: kind, provider: BehaviorWidgetProvider(imageKey: "widget_consumptionRhythm_medium")) { entry in
            if #available(iOS 17.0, *) {
                BehaviorWidgetEntryView(entry: entry, destination: URL(string: "beecount://open?page=statistics")!, symbol: "chart.bar.fill", label: widgetTitle)
                    .containerBackground(for: .widget) { Color.clear }
            } else {
                BehaviorWidgetEntryView(entry: entry, destination: URL(string: "beecount://open?page=statistics")!, symbol: "chart.bar.fill", label: widgetTitle)
            }
        }
        .configurationDisplayName(widgetTitle).description(widgetDescription)
        .supportedFamilies([.systemMedium]).contentMarginsDisabled()
    }
}

struct BeeCountBeeTrailWidget: Widget {
    let kind = "BeeCountBeeTrailWidget"
    private var title: String {
        BehaviorWidgetCopy.localized(simplifiedChinese: "记账连续蜂迹", traditionalChinese: "記帳連續蜂跡", english: "Record Bee Trail")
    }
    private var description: String {
        BehaviorWidgetCopy.localized(simplifiedChinese: "用蜂巢格养成每日记账习惯", traditionalChinese: "用蜂巢格養成每日記帳習慣", english: "Build a daily recording habit with a honeycomb trail")
    }
    var body: some WidgetConfiguration {
        let widgetTitle = title
        let widgetDescription = description
        return StaticConfiguration(kind: kind, provider: BehaviorWidgetProvider(imageKey: "widget_beeTrail_small")) { entry in
            if #available(iOS 17.0, *) {
                BehaviorWidgetEntryView(entry: entry, destination: URL(string: "beecount://open?page=transactions")!, symbol: "hexagon.fill", label: widgetTitle)
                    .containerBackground(for: .widget) { Color.clear }
            } else {
                BehaviorWidgetEntryView(entry: entry, destination: URL(string: "beecount://open?page=transactions")!, symbol: "hexagon.fill", label: widgetTitle)
            }
        }
        .configurationDisplayName(widgetTitle).description(widgetDescription)
        .supportedFamilies([.systemSmall]).contentMarginsDisabled()
    }
}
