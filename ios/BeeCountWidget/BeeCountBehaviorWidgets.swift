import WidgetKit
import SwiftUI
import UIKit

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
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: BehaviorWidgetProvider(imageKey: "widget_consumptionRhythm_medium")) { entry in
            BehaviorWidgetEntryView(entry: entry, destination: URL(string: "beecount://open?page=statistics")!, symbol: "chart.bar.fill", label: "消费节奏")
        }
        .configurationDisplayName("消费节奏").description("近 30 天消费节奏一眼看清")
        .supportedFamilies([.systemMedium]).contentMarginsDisabled()
    }
}

struct BeeCountBeeTrailWidget: Widget {
    let kind = "BeeCountBeeTrailWidget"
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: BehaviorWidgetProvider(imageKey: "widget_beeTrail_small")) { entry in
            BehaviorWidgetEntryView(entry: entry, destination: URL(string: "beecount://open?page=transactions")!, symbol: "hexagon.fill", label: "记账连续蜂迹")
        }
        .configurationDisplayName("记账连续蜂迹").description("用蜂巢格养成每日记账习惯")
        .supportedFamilies([.systemSmall]).contentMarginsDisabled()
    }
}
