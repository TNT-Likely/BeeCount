//
//  BeeCountNetWorthWidget.swift
//  BeeCountWidget
//
//  Created by matrix on 2026/7/19.
//

import WidgetKit
import SwiftUI

struct BeeCountNetWorthEntry: TimelineEntry {
    let date: Date
    let widgetImagePath: String
}

struct BeeCountNetWorthProvider: TimelineProvider {
    /// 按 widget family 选渲染管线写入的图片 key（对应
    /// `lib/widget/widget_spec.dart` 的 `netWorthSmall/Medium/Large`）。
    private func imageKey(for family: WidgetFamily) -> String {
        switch family {
        case .systemSmall:
            return "widget_netWorth_small"
        case .systemLarge:
            return "widget_netWorth_large"
        default:
            return "widget_netWorth_medium"
        }
    }

    func placeholder(in context: Context) -> BeeCountNetWorthEntry {
        BeeCountNetWorthEntry(
            date: Date(),
            widgetImagePath: ""
        )
    }

    func getSnapshot(in context: Context, completion: @escaping (BeeCountNetWorthEntry) -> ()) {
        let userDefaults = UserDefaults(suiteName: "group.com.tntlikely.beecount")
        let imagePath = userDefaults?.string(forKey: imageKey(for: context.family)) ?? ""
        let entry = BeeCountNetWorthEntry(date: Date(), widgetImagePath: imagePath)
        completion(entry)
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<Entry>) -> ()) {
        let userDefaults = UserDefaults(suiteName: "group.com.tntlikely.beecount")
        let imagePath = userDefaults?.string(forKey: imageKey(for: context.family)) ?? ""
        let entry = BeeCountNetWorthEntry(date: Date(), widgetImagePath: imagePath)

        // 设置30分钟后刷新
        let nextUpdate = Calendar.current.date(byAdding: .minute, value: 30, to: Date())!
        let timeline = Timeline(entries: [entry], policy: .after(nextUpdate))
        completion(timeline)
    }
}

struct BeeCountNetWorthWidgetEntryView : View {
    var entry: BeeCountNetWorthProvider.Entry
    @Environment(\.widgetFamily) var widgetFamily

    // 净资产卡片点击 → 资产页。第一版整块点击、不分区；后续如需按账户明细
    // 列表分区跳转，可参考 BeeCountWidget.swift 的 GeometryReader 分区写法。
    // TODO: 大号有账户明细列表时，考虑按行分区深链到具体账户。
    private let assetsURL = URL(string: "beecount://open?page=assets")!

    var body: some View {
        if let uiImage = UIImage(contentsOfFile: entry.widgetImagePath) {
            Link(destination: assetsURL) {
                Image(uiImage: uiImage)
                    .resizable()
                    .scaledToFill()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .clipped()
            }
        } else {
            // Placeholder view when image is not available
            ZStack {
                Color(red: 1.0, green: 0.76, blue: 0.03)
                VStack {
                    Image(systemName: "chart.pie.fill")
                        .font(.system(size: 32))
                        .foregroundColor(.white)
                    Text("净资产")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.white)
                }
            }
            .widgetURL(assetsURL)
        }
    }
}

struct BeeCountNetWorthWidget: Widget {
    let kind: String = "BeeCountNetWorthWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: BeeCountNetWorthProvider()) { entry in
            if #available(iOS 17.0, *) {
                BeeCountNetWorthWidgetEntryView(entry: entry)
                    .containerBackground(for: .widget) {
                        Color.clear
                    }
            } else {
                BeeCountNetWorthWidgetEntryView(entry: entry)
            }
        }
        .configurationDisplayName("净资产")
        .description("总资产、总负债与净值趋势")
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge])
        .contentMarginsDisabled()  // Remove default padding/margins in iOS 17+
    }
}
