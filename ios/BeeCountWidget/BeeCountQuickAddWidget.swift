//
//  BeeCountQuickAddWidget.swift
//  BeeCountWidget
//
//  Created by matrix on 2026/7/19.
//

import WidgetKit
import SwiftUI
import UIKit

struct BeeCountQuickAddEntry: TimelineEntry {
    let date: Date
    let widgetImagePath: String
}

struct BeeCountQuickAddProvider: TimelineProvider {
    /// 按 widget family 选渲染管线写入的图片 key（对应
    /// `lib/widget/widget_spec.dart` 的 `quickAddSmall/Medium`）。
    private func imageKey(for family: WidgetFamily) -> String {
        switch family {
        case .systemSmall:
            return "widget_quickAdd_small"
        default:
            return "widget_quickAdd_medium"
        }
    }

    func placeholder(in context: Context) -> BeeCountQuickAddEntry {
        BeeCountQuickAddEntry(
            date: Date(),
            // 添加页预览:用 bundle 内静态资产(见 WidgetPreviewAssets 注释)。
            widgetImagePath: WidgetPreviewAssets.path(forImageKey: imageKey(for: context.family))
        )
    }

    func getSnapshot(in context: Context, completion: @escaping (BeeCountQuickAddEntry) -> ()) {
        // 添加页预览(isPreview):运行时图片在预览上下文读不到(App
        // Group 访问受限,添加页只会显示占位色块),改用 bundle 内静态
        // 预览资产,详见 WidgetPreviewAssets。
        if context.isPreview {
            completion(BeeCountQuickAddEntry(
                date: Date(),
                widgetImagePath: WidgetPreviewAssets.path(forImageKey: imageKey(for: context.family))))
            return
        }
        let userDefaults = UserDefaults(suiteName: "group.com.tntlikely.beecount")
        let imagePath = userDefaults?.string(forKey: imageKey(for: context.family)) ?? ""
        let entry = BeeCountQuickAddEntry(date: Date(), widgetImagePath: imagePath)
        completion(entry)
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<Entry>) -> ()) {
        let userDefaults = UserDefaults(suiteName: "group.com.tntlikely.beecount")
        let imagePath = userDefaults?.string(forKey: imageKey(for: context.family)) ?? ""
        let entry = BeeCountQuickAddEntry(date: Date(), widgetImagePath: imagePath)

        // 设置30分钟后刷新
        let nextUpdate = Calendar.current.date(byAdding: .minute, value: 30, to: Date())!
        let timeline = Timeline(entries: [entry], policy: .after(nextUpdate))
        completion(timeline)
    }
}

struct BeeCountQuickAddWidgetEntryView : View {
    var entry: BeeCountQuickAddProvider.Entry
    @Environment(\.widgetFamily) var widgetFamily

    // 快速记账卡片点击 → 新建支出。第一版整块点击、不分区。
    // TODO: 常用分类格拆分点击区域后，改为按分类深链
    // `beecount://new?type=expense&category=<id>`（分类 id 取自渲染时
    // 的取数结果，需要额外把每格坐标信息一并写入共享存储或改用
    // AppIntent 交互式布局）。
    private let addExpenseURL = URL(string: "beecount://new?type=expense")!

    var body: some View {
        if let uiImage = UIImage(contentsOfFile: entry.widgetImagePath) {
            Link(destination: addExpenseURL) {
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
                    Image(systemName: "plus.circle.fill")
                        .font(.system(size: 32))
                        .foregroundColor(.white)
                    Text("快速记账")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.white)
                }
            }
            .widgetURL(addExpenseURL)
        }
    }
}

struct BeeCountQuickAddWidget: Widget {
    let kind: String = "BeeCountQuickAddWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: BeeCountQuickAddProvider()) { entry in
            if #available(iOS 17.0, *) {
                BeeCountQuickAddWidgetEntryView(entry: entry)
                    .containerBackground(for: .widget) {
                        Color.clear
                    }
            } else {
                BeeCountQuickAddWidgetEntryView(entry: entry)
            }
        }
        .configurationDisplayName("快速记账")
        .description("常用分类一键速记")
        .supportedFamilies([.systemSmall, .systemMedium])
        .contentMarginsDisabled()  // Remove default padding/margins in iOS 17+
    }
}
