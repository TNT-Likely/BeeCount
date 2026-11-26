import WidgetKit
import SwiftUI
import UIKit

/// 添加页名称、说明及无数据占位使用现有的中英文原生文案。
enum BehaviorWidgetCopy {
    static func localized(
        simplifiedChinese: String,
        traditionalChinese: String,
        english: String
    ) -> String {
        let locales = [Locale.current] + Locale.preferredLanguages.map(Locale.init(identifier:))
        switch WidgetImageManifest.language(for: locales) {
        case "zh": return simplifiedChinese
        case "zh-TW": return traditionalChinese
        default: return english
        }
    }
}

private struct BehaviorWidgetProvider: WidgetImageProviding {
    let key: String

    func imageKey(for family: WidgetFamily) -> String { key }
}

private struct BehaviorWidgetEntryView: View {
    let image: UIImage?
    let destination: URL
    let symbol: String
    let label: String

    var body: some View {
        WidgetCardImage(image: image, symbol: symbol, label: label)
            .widgetURL(destination)
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
        return StaticConfiguration(kind: kind, provider: BehaviorWidgetProvider(key: "widget_consumptionRhythm_medium")) { entry in
            WidgetImageContent(entry: entry) { image in
                BehaviorWidgetEntryView(image: image, destination: URL(string: "beecount://open?page=statistics")!, symbol: "chart.bar.fill", label: widgetTitle)
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
        return StaticConfiguration(kind: kind, provider: BehaviorWidgetProvider(key: "widget_beeTrail_small")) { entry in
            WidgetImageContent(entry: entry) { image in
                BehaviorWidgetEntryView(image: image, destination: URL(string: "beecount://open?page=transactions")!, symbol: "hexagon.fill", label: widgetTitle)
            }
        }
        .configurationDisplayName(widgetTitle).description(widgetDescription)
        .supportedFamilies([.systemSmall]).contentMarginsDisabled()
    }
}
