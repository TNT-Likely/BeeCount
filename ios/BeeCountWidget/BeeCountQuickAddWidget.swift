//
//  BeeCountQuickAddWidget.swift
//  BeeCountWidget
//
//  Created by matrix on 2026/7/19.
//

import WidgetKit
import SwiftUI
import UIKit

struct BeeCountQuickAddProvider: WidgetImageProviding {
    /// 按 widget family 选渲染管线写入的图片 key（对应
    /// `lib/widget/widget_spec.dart` 的 `quickAddSmall/Medium`）。
    func imageKey(for family: WidgetFamily) -> String {
        switch family {
        case .systemSmall:
            return "widget_quickAdd_small"
        default:
            return "widget_quickAdd_medium"
        }
    }
}

struct BeeCountQuickAddWidgetEntryView : View {
    let image: UIImage?

    // The categories describe recent usage. The entire card opens one expense form.
    private let addExpenseURL = URL(string: "beecount://new?type=expense")!

    var body: some View {
        WidgetCardImage(image: image, symbol: "plus.circle.fill", label: BehaviorWidgetCopy.localized(
            simplifiedChinese: "快速记账", traditionalChinese: "快速記帳", english: "Quick Add"))
            .widgetURL(addExpenseURL)
    }
}

struct BeeCountQuickAddWidget: Widget {
    let kind: String = "BeeCountQuickAddWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: BeeCountQuickAddProvider()) { entry in
            WidgetImageContent(entry: entry) { image in
                BeeCountQuickAddWidgetEntryView(image: image)
            }
        }
        .configurationDisplayName(BehaviorWidgetCopy.localized(
            simplifiedChinese: "快速记账", traditionalChinese: "快速記帳",
            english: "Quick Add"))
        .description(BehaviorWidgetCopy.localized(
            simplifiedChinese: "查看常用分类，轻点记支出",
            traditionalChinese: "查看常用分類，點一下記支出",
            english: "View frequent categories and tap to add an expense"))
        .supportedFamilies([.systemSmall, .systemMedium])
        .contentMarginsDisabled()  // Remove default padding/margins in iOS 17+
    }
}
