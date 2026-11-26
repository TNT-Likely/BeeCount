//
//  BeeCountBudgetWidget.swift
//  BeeCountWidget
//
//  Created by matrix on 2026/7/19.
//

import WidgetKit
import SwiftUI
import UIKit

struct BeeCountBudgetProvider: WidgetImageProviding {
    /// 按 widget family 选渲染管线写入的图片 key（对应
    /// `lib/widget/widget_spec.dart` 的 `budgetSmall/Medium`）。
    func imageKey(for family: WidgetFamily) -> String {
        switch family {
        case .systemSmall:
            return "widget_budget_small"
        default:
            return "widget_budget_medium"
        }
    }
}

struct BeeCountBudgetWidgetEntryView : View {
    let image: UIImage?

    // 预算卡片点击 → 预算页。第一版整块点击、不分区。
    // TODO: 中号有分类用量列表时，考虑按行分区深链到该分类的筛选明细。
    private let budgetURL = URL(string: "beecount://open?page=budget")!

    var body: some View {
        WidgetCardImage(image: image, symbol: "creditcard.fill", label: BehaviorWidgetCopy.localized(
            simplifiedChinese: "预算", traditionalChinese: "預算", english: "Budget"))
            .widgetURL(budgetURL)
    }
}

struct BeeCountBudgetWidget: Widget {
    let kind: String = "BeeCountBudgetWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: BeeCountBudgetProvider()) { entry in
            WidgetImageContent(entry: entry) { image in
                BeeCountBudgetWidgetEntryView(image: image)
            }
        }
        .configurationDisplayName(BehaviorWidgetCopy.localized(
            simplifiedChinese: "预算进度", traditionalChinese: "預算進度",
            english: "Budget"))
        .description(BehaviorWidgetCopy.localized(
            simplifiedChinese: "预算进度实时掌握",
            traditionalChinese: "預算進度即時掌握",
            english: "Track budget progress at a glance"))
        .supportedFamilies([.systemSmall, .systemMedium])
        .contentMarginsDisabled()  // Remove default padding/margins in iOS 17+
    }
}
