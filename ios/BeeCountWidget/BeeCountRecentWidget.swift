//
//  BeeCountRecentWidget.swift
//  BeeCountWidget
//
//  Created by matrix on 2026/7/19.
//

import WidgetKit
import SwiftUI
import UIKit

struct BeeCountRecentEntry: TimelineEntry {
    let date: Date
    let widgetImagePath: String
}

struct BeeCountRecentProvider: TimelineProvider {
    /// 按 widget family 选渲染管线写入的图片 key（对应
    /// `lib/widget/widget_spec.dart` 的 `recentMedium/Large`）。
    private func imageKey(for family: WidgetFamily) -> String {
        switch family {
        case .systemLarge:
            return "widget_recent_large"
        default:
            return "widget_recent_medium"
        }
    }

    func placeholder(in context: Context) -> BeeCountRecentEntry {
        BeeCountRecentEntry(
            date: Date(),
            // 添加页预览:用 bundle 内静态资产(见 WidgetPreviewAssets 注释)。
            widgetImagePath: WidgetPreviewAssets.path(forImageKey: imageKey(for: context.family))
        )
    }

    func getSnapshot(in context: Context, completion: @escaping (BeeCountRecentEntry) -> ()) {
        // 添加页预览(isPreview):运行时图片在预览上下文读不到(App
        // Group 访问受限,添加页只会显示占位色块),改用 bundle 内静态
        // 预览资产,详见 WidgetPreviewAssets。
        if context.isPreview {
            completion(BeeCountRecentEntry(
                date: Date(),
                widgetImagePath: WidgetPreviewAssets.path(forImageKey: imageKey(for: context.family))))
            return
        }
        let userDefaults = UserDefaults(suiteName: "group.com.tntlikely.beecount")
        let imagePath = userDefaults?.string(forKey: imageKey(for: context.family)) ?? ""
        let entry = BeeCountRecentEntry(date: Date(), widgetImagePath: imagePath)
        completion(entry)
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<Entry>) -> ()) {
        let userDefaults = UserDefaults(suiteName: "group.com.tntlikely.beecount")
        let imagePath = userDefaults?.string(forKey: imageKey(for: context.family)) ?? ""
        let entry = BeeCountRecentEntry(date: Date(), widgetImagePath: imagePath)

        // 设置30分钟后刷新
        let nextUpdate = Calendar.current.date(byAdding: .minute, value: 30, to: Date())!
        let timeline = Timeline(entries: [entry], policy: .after(nextUpdate))
        completion(timeline)
    }
}

struct BeeCountRecentWidgetEntryView : View {
    var entry: BeeCountRecentProvider.Entry
    @Environment(\.widgetFamily) var widgetFamily

    // 最近交易卡片点击 → 明细页。第一版整块点击、不分区。
    // TODO: 点单笔交易跳转到该笔详情是二期优化（见 plan.md §二.5），需要
    // 按行分区深链并携带交易 id，例如 `beecount://open?page=detail&id=<id>`。
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
                    Image(systemName: "clock.fill")
                        .font(.system(size: 32))
                        .foregroundColor(.white)
                    Text("最近交易")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.white)
                }
            }
            .widgetURL(detailURL)
        }
    }
}

struct BeeCountRecentWidget: Widget {
    let kind: String = "BeeCountRecentWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: BeeCountRecentProvider()) { entry in
            if #available(iOS 17.0, *) {
                BeeCountRecentWidgetEntryView(entry: entry)
                    .containerBackground(for: .widget) {
                        Color.clear
                    }
            } else {
                BeeCountRecentWidgetEntryView(entry: entry)
            }
        }
        .configurationDisplayName("最近交易")
        .description("快速查看最近几笔账单")
        .supportedFamilies([.systemMedium, .systemLarge])
        .contentMarginsDisabled()  // Remove default padding/margins in iOS 17+
    }
}
