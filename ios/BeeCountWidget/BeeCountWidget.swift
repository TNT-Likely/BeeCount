//
//  BeeCountWidget.swift
//  BeeCountWidget
//
//  Created by matrix on 2025/11/5.
//

import WidgetKit
import SwiftUI
import UIKit

struct BeeCountProvider: WidgetImageProviding {
    /// 按 widget family 选渲染管线写入的图片 key。中号沿用历史 key
    /// `widgetImage`(D2 back-compat:存量已放置的中号组件依赖它,不可改名),
    /// 小号是补全新增(对应 `lib/widget/widget_spec.dart` 的 `glanceSmall`,
    /// key `widget_glance_small`)。
    func imageKey(for family: WidgetFamily) -> String {
        switch family {
        case .systemSmall:
            return "widget_glance_small"
        default:
            return "widgetImage"
        }
    }
}

struct BeeCountWidgetEntryView : View {
    let image: UIImage?
    @Environment(\.widgetFamily) var widgetFamily

    private let expenseURL = URL(string: "beecount://new?type=expense")!
    private let incomeURL = URL(string: "beecount://new?type=income")!

    @ViewBuilder
    var body: some View {
        let artwork = WidgetCardImage(image: image, symbol: "chart.bar", label: BehaviorWidgetCopy.localized(
            simplifiedChinese: "收支速览", traditionalChinese: "收支速覽", english: "Overview"))
        if widgetFamily == .systemSmall || image == nil {
            artwork.widgetURL(expenseURL)
        } else {
            GeometryReader { geometry in
                ZStack {
                    artwork.frame(width: geometry.size.width, height: geometry.size.height)
                    VStack(spacing: 0) {
                        Color.clear.frame(height: geometry.size.height * 0.28)
                        HStack(spacing: 0) {
                            Link(destination: expenseURL) { Color.clear.contentShape(Rectangle()) }
                            Link(destination: incomeURL) { Color.clear.contentShape(Rectangle()) }
                        }
                    }
                }
            }
        }
    }
}

struct BeeCountWidget: Widget {
    let kind: String = "BeeCountWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: BeeCountProvider()) { entry in
            WidgetImageContent(entry: entry) { image in
                BeeCountWidgetEntryView(image: image)
            }
        }
        .configurationDisplayName(BehaviorWidgetCopy.localized(
            simplifiedChinese: "收支速览", traditionalChinese: "收支速覽",
            english: "Overview"))
        .description(BehaviorWidgetCopy.localized(
            simplifiedChinese: "显示今日和本月的收支情况",
            traditionalChinese: "查看今日和本月的收支情況",
            english: "Today's and this month's income & expenses"))
        .supportedFamilies([.systemSmall, .systemMedium])
        .contentMarginsDisabled()  // Remove default padding/margins in iOS 17+
    }
}
