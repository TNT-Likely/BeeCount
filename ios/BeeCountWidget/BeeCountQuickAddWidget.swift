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

    // 快速记账卡片点击 → 新建支出。第一版整块点击、不分区。
    // TODO: 常用分类格拆分点击区域后，改为按分类深链
    // `beecount://new?type=expense&category=<id>`（分类 id 取自渲染时
    // 的取数结果，需要额外把每格坐标信息一并写入共享存储或改用
    // AppIntent 交互式布局）。
    private let addExpenseURL = URL(string: "beecount://new?type=expense")!

    var body: some View {
        if let uiImage = image {
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
                    Text(BehaviorWidgetCopy.localized(
                        simplifiedChinese: "快速记账", traditionalChinese: "快速記帳",
                        english: "Quick Add"))
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
            WidgetImageContent(entry: entry) { image in
                BeeCountQuickAddWidgetEntryView(image: image)
            }
        }
        .configurationDisplayName(BehaviorWidgetCopy.localized(
            simplifiedChinese: "快速记账", traditionalChinese: "快速記帳",
            english: "Quick Add"))
        .description(BehaviorWidgetCopy.localized(
            simplifiedChinese: "常用分类一键速记",
            traditionalChinese: "常用分類一鍵速記",
            english: "One-tap entry for your top categories"))
        .supportedFamilies([.systemSmall, .systemMedium])
        .contentMarginsDisabled()  // Remove default padding/margins in iOS 17+
    }
}
