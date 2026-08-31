import WidgetKit
import SwiftUI
import UIKit

private enum BehaviorWidgetCopy {
    static func localized(
        simplifiedChinese: String,
        traditionalChinese: String,
        english: String,
        korean: String
    ) -> String {
        let locale = Locale.current
        switch locale.languageCode {
        case "en": return english
        case "ko": return korean
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

    private func entry() -> BehaviorWidgetEntry {
        let path = UserDefaults(suiteName: "group.com.tntlikely.beecount")?.string(forKey: imageKey) ?? ""
        return BehaviorWidgetEntry(date: Date(), imagePath: path)
    }

    func placeholder(in context: Context) -> BehaviorWidgetEntry { entry() }
    func getSnapshot(in context: Context, completion: @escaping (BehaviorWidgetEntry) -> ()) { completion(entry()) }
    func getTimeline(in context: Context, completion: @escaping (Timeline<BehaviorWidgetEntry>) -> ()) {
        let next = Calendar.current.date(byAdding: .minute, value: 30, to: Date())!
        completion(Timeline(entries: [entry()], policy: .after(next)))
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
        BehaviorWidgetCopy.localized(simplifiedChinese: "消费节奏", traditionalChinese: "消費節奏", english: "Spending Rhythm", korean: "소비 리듬")
    }
    private var description: String {
        BehaviorWidgetCopy.localized(simplifiedChinese: "近 30 天消费节奏一眼看清", traditionalChinese: "近 30 天消費節奏一眼看清", english: "See your spending pace across the last 30 days", korean: "최근 30일의 소비 흐름을 한눈에 확인하세요")
    }
    var body: some WidgetConfiguration {
        let widgetTitle = title
        let widgetDescription = description
        return StaticConfiguration(kind: kind, provider: BehaviorWidgetProvider(imageKey: "widget_consumptionRhythm_medium")) { entry in
            BehaviorWidgetEntryView(entry: entry, destination: URL(string: "beecount://open?page=statistics")!, symbol: "chart.bar.fill", label: widgetTitle)
        }
        .configurationDisplayName(widgetTitle).description(widgetDescription)
        .supportedFamilies([.systemMedium]).contentMarginsDisabled()
    }
}

struct BeeCountBeeTrailWidget: Widget {
    let kind = "BeeCountBeeTrailWidget"
    private var title: String {
        BehaviorWidgetCopy.localized(simplifiedChinese: "记账连续蜂迹", traditionalChinese: "記帳連續蜂跡", english: "Record Bee Trail", korean: "기록 꿀벌 궤적")
    }
    private var description: String {
        BehaviorWidgetCopy.localized(simplifiedChinese: "用蜂巢格养成每日记账习惯", traditionalChinese: "用蜂巢格養成每日記帳習慣", english: "Build a daily recording habit with a honeycomb trail", korean: "벌집 칸으로 매일 기록하는 습관을 만들어 보세요")
    }
    var body: some WidgetConfiguration {
        let widgetTitle = title
        let widgetDescription = description
        return StaticConfiguration(kind: kind, provider: BehaviorWidgetProvider(imageKey: "widget_beeTrail_small")) { entry in
            BehaviorWidgetEntryView(entry: entry, destination: URL(string: "beecount://open?page=transactions")!, symbol: "hexagon.fill", label: widgetTitle)
        }
        .configurationDisplayName(widgetTitle).description(widgetDescription)
        .supportedFamilies([.systemSmall]).contentMarginsDisabled()
    }
}
