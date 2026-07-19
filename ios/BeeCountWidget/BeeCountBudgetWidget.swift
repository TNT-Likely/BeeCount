//
//  BeeCountBudgetWidget.swift
//  BeeCountWidget
//
//  Created by matrix on 2026/7/19.
//

import WidgetKit
import SwiftUI
import UIKit

struct BeeCountBudgetEntry: TimelineEntry {
    let date: Date
    let widgetImagePath: String
}

struct BeeCountBudgetProvider: TimelineProvider {
    /// 按 widget family 选渲染管线写入的图片 key（对应
    /// `lib/widget/widget_spec.dart` 的 `budgetSmall/Medium`）。
    private func imageKey(for family: WidgetFamily) -> String {
        switch family {
        case .systemSmall:
            return "widget_budget_small"
        default:
            return "widget_budget_medium"
        }
    }

    func placeholder(in context: Context) -> BeeCountBudgetEntry {
        BeeCountBudgetEntry(
            date: Date(),
            widgetImagePath: ""
        )
    }

    func getSnapshot(in context: Context, completion: @escaping (BeeCountBudgetEntry) -> ()) {
        let userDefaults = UserDefaults(suiteName: "group.com.tntlikely.beecount")
        let imagePath = userDefaults?.string(forKey: imageKey(for: context.family)) ?? ""
        let entry = BeeCountBudgetEntry(date: Date(), widgetImagePath: imagePath)
        completion(entry)
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<Entry>) -> ()) {
        let userDefaults = UserDefaults(suiteName: "group.com.tntlikely.beecount")
        let imagePath = userDefaults?.string(forKey: imageKey(for: context.family)) ?? ""
        let entry = BeeCountBudgetEntry(date: Date(), widgetImagePath: imagePath)

        // 设置30分钟后刷新
        let nextUpdate = Calendar.current.date(byAdding: .minute, value: 30, to: Date())!
        let timeline = Timeline(entries: [entry], policy: .after(nextUpdate))
        completion(timeline)
    }
}

struct BeeCountBudgetWidgetEntryView : View {
    var entry: BeeCountBudgetProvider.Entry
    @Environment(\.widgetFamily) var widgetFamily

    // 预算卡片点击 → 预算页。第一版整块点击、不分区。
    // TODO: 中号有分类用量列表时，考虑按行分区深链到该分类的筛选明细。
    private let budgetURL = URL(string: "beecount://open?page=budget")!

    var body: some View {
        if let uiImage = UIImage(contentsOfFile: entry.widgetImagePath) {
            Link(destination: budgetURL) {
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
                    Image(systemName: "creditcard.fill")
                        .font(.system(size: 32))
                        .foregroundColor(.white)
                    Text("预算")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.white)
                }
            }
            .widgetURL(budgetURL)
        }
    }
}

struct BeeCountBudgetWidget: Widget {
    let kind: String = "BeeCountBudgetWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: BeeCountBudgetProvider()) { entry in
            if #available(iOS 17.0, *) {
                BeeCountBudgetWidgetEntryView(entry: entry)
                    .containerBackground(for: .widget) {
                        Color.clear
                    }
            } else {
                BeeCountBudgetWidgetEntryView(entry: entry)
            }
        }
        .configurationDisplayName("预算进度")
        .description("预算进度实时掌握")
        .supportedFamilies([.systemSmall, .systemMedium])
        .contentMarginsDisabled()  // Remove default padding/margins in iOS 17+
    }
}
