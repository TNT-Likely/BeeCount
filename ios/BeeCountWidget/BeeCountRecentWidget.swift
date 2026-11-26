//
//  BeeCountRecentWidget.swift
//  BeeCountWidget
//
//  Created by matrix on 2026/7/19.
//

import WidgetKit
import SwiftUI
import UIKit

struct BeeCountRecentProvider: WidgetImageProviding {
    /// 按 widget family 选渲染管线写入的图片 key（对应
    /// `lib/widget/widget_spec.dart` 的 `recentMedium/Large`）。
    func imageKey(for family: WidgetFamily) -> String {
        switch family {
        case .systemLarge:
            return "widget_recent_large"
        default:
            return "widget_recent_medium"
        }
    }
}

struct BeeCountRecentWidgetEntryView : View {
    let image: UIImage?

    // 最近交易卡片点击 → 明细页。第一版整块点击、不分区。
    // TODO: 点单笔交易跳转到该笔详情是二期优化（见 plan.md §二.5），需要
    // 按行分区深链并携带交易 id，例如 `beecount://open?page=detail&id=<id>`。
    private let detailURL = URL(string: "beecount://open?page=detail")!

    var body: some View {
        WidgetCardImage(image: image, symbol: "clock.fill", label: BehaviorWidgetCopy.localized(
            simplifiedChinese: "最近交易", traditionalChinese: "最近交易", english: "Recent"))
            .widgetURL(detailURL)
    }
}

struct BeeCountRecentWidget: Widget {
    let kind: String = "BeeCountRecentWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: BeeCountRecentProvider()) { entry in
            WidgetImageContent(entry: entry) { image in
                BeeCountRecentWidgetEntryView(image: image)
            }
        }
        .configurationDisplayName(BehaviorWidgetCopy.localized(
            simplifiedChinese: "最近交易", traditionalChinese: "最近交易",
            english: "Recent"))
        .description(BehaviorWidgetCopy.localized(
            simplifiedChinese: "快速查看最近几笔账单",
            traditionalChinese: "快速查看最近幾筆帳單",
            english: "A quick look at your latest transactions"))
        .supportedFamilies([.systemMedium, .systemLarge])
        .contentMarginsDisabled()  // Remove default padding/margins in iOS 17+
    }
}
