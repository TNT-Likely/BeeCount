//
//  BeeCountDashboardWidget.swift
//  BeeCountWidget
//
//  Created by matrix on 2026/7/19.
//

import WidgetKit
import SwiftUI
import UIKit

struct BeeCountDashboardEntry: TimelineEntry {
    let date: Date
    let widgetImagePath: String
}

struct BeeCountDashboardProvider: TimelineProvider {
    // 仅 systemLarge 一个尺寸（对应 `lib/widget/widget_spec.dart` 的
    // `dashboardLarge`），无需按 family 分支。
    private let imageKey = "widget_dashboard_large"

    func placeholder(in context: Context) -> BeeCountDashboardEntry {
        BeeCountDashboardEntry(
            date: Date(),
            widgetImagePath: ""
        )
    }

    func getSnapshot(in context: Context, completion: @escaping (BeeCountDashboardEntry) -> ()) {
        let userDefaults = UserDefaults(suiteName: "group.com.tntlikely.beecount")
        let imagePath = userDefaults?.string(forKey: imageKey) ?? ""
        let entry = BeeCountDashboardEntry(date: Date(), widgetImagePath: imagePath)
        completion(entry)
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<Entry>) -> ()) {
        let userDefaults = UserDefaults(suiteName: "group.com.tntlikely.beecount")
        let imagePath = userDefaults?.string(forKey: imageKey) ?? ""
        let entry = BeeCountDashboardEntry(date: Date(), widgetImagePath: imagePath)

        // 设置30分钟后刷新
        let nextUpdate = Calendar.current.date(byAdding: .minute, value: 30, to: Date())!
        let timeline = Timeline(entries: [entry], policy: .after(nextUpdate))
        completion(timeline)
    }
}

struct BeeCountDashboardWidgetEntryView : View {
    var entry: BeeCountDashboardProvider.Entry
    @Environment(\.widgetFamily) var widgetFamily

    // 综合仪表盘卡片点击 → 明细页。第一版整块点击、不分区。
    // TODO: 各分区（本月收支/趋势/最近交易/快捷记账行）分区深链是后续细化，
    // 例如最近交易区域跳 `open?page=detail`、快捷记账行跳
    // `new?type=expense`，届时参考 BeeCountWidget.swift 的
    // GeometryReader 分区写法。
    private let detailURL = URL(string: "beecount://open?page=detail")!

    var body: some View {
        if let uiImage = UIImage(contentsOfFile: entry.widgetImagePath) {
            Link(destination: detailURL) {
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
                    Image(systemName: "square.grid.2x2.fill")
                        .font(.system(size: 32))
                        .foregroundColor(.white)
                    Text("综合仪表盘")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.white)
                }
            }
            .widgetURL(detailURL)
        }
    }
}

struct BeeCountDashboardWidget: Widget {
    let kind: String = "BeeCountDashboardWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: BeeCountDashboardProvider()) { entry in
            if #available(iOS 17.0, *) {
                BeeCountDashboardWidgetEntryView(entry: entry)
                    .containerBackground(for: .widget) {
                        Color.clear
                    }
            } else {
                BeeCountDashboardWidgetEntryView(entry: entry)
            }
        }
        .configurationDisplayName("综合仪表盘")
        .description("收支、趋势与最近交易一屏看尽")
        .supportedFamilies([.systemLarge])
        .contentMarginsDisabled()  // Remove default padding/margins in iOS 17+
    }
}
