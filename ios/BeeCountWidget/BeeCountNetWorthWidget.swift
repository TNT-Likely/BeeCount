//
//  BeeCountNetWorthWidget.swift
//  BeeCountWidget
//
//  Created by matrix on 2026/7/19.
//

import WidgetKit
import SwiftUI
import UIKit

struct BeeCountNetWorthProvider: WidgetImageProviding {
    /// 按 widget family 选渲染管线写入的图片 key（对应
    /// `lib/widget/widget_spec.dart` 的 `netWorthSmall/Medium/Large`）。
    func imageKey(for family: WidgetFamily) -> String {
        switch family {
        case .systemSmall:
            return "widget_netWorth_small"
        case .systemLarge:
            return "widget_netWorth_large"
        default:
            return "widget_netWorth_medium"
        }
    }
}

struct BeeCountNetWorthWidgetEntryView : View {
    let image: UIImage?

    // 净资产卡片点击 → 资产页。第一版整块点击、不分区；后续如需按账户明细
    // 列表分区跳转，可参考 BeeCountWidget.swift 的 GeometryReader 分区写法。
    // TODO: 大号有账户明细列表时，考虑按行分区深链到具体账户。
    private let assetsURL = URL(string: "beecount://open?page=assets")!

    var body: some View {
        WidgetCardImage(image: image, symbol: "chart.pie.fill", label: BehaviorWidgetCopy.localized(
            simplifiedChinese: "净资产", traditionalChinese: "淨資產", english: "Net Worth"))
            .widgetURL(assetsURL)
    }
}

struct BeeCountNetWorthWidget: Widget {
    let kind: String = "BeeCountNetWorthWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: BeeCountNetWorthProvider()) { entry in
            WidgetImageContent(entry: entry) { image in
                BeeCountNetWorthWidgetEntryView(image: image)
            }
        }
        .configurationDisplayName(BehaviorWidgetCopy.localized(
            simplifiedChinese: "净资产", traditionalChinese: "淨資產",
            english: "Net Worth"))
        .description(BehaviorWidgetCopy.localized(
            simplifiedChinese: "总资产、总负债与净值趋势",
            traditionalChinese: "總資產、總負債與淨值趨勢",
            english: "Assets, liabilities, and net-worth trend"))
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge])
        .contentMarginsDisabled()  // Remove default padding/margins in iOS 17+
    }
}
