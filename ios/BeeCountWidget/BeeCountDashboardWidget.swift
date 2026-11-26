//
//  BeeCountDashboardWidget.swift
//  BeeCountWidget
//
//  Created by matrix on 2026/7/19.
//

import WidgetKit
import SwiftUI
import UIKit

struct BeeCountDashboardProvider: WidgetImageProviding {
    // 仅 systemLarge 一个尺寸（对应 `lib/widget/widget_spec.dart` 的
    // `dashboardLarge`），无需按 family 分支。
    func imageKey(for family: WidgetFamily) -> String { "widget_dashboard_large" }
}

struct BeeCountDashboardWidgetEntryView : View {
    let image: UIImage?

    // 分区点击(2026-07 真机反馈:底部画着「记一笔」却整块跳明细,点记一笔
    // 进了洞察页):上部主体 → 明细,底部快捷记账行 → 记支出。
    private let detailURL = URL(string: "beecount://open?page=detail")!
    private let expenseURL = URL(string: "beecount://new?type=expense")!

    var body: some View {
        if let uiImage = image {
            GeometryReader { geometry in
                ZStack {
                    Image(uiImage: uiImage)
                        .resizable()
                        .scaledToFill()
                        .frame(width: geometry.size.width, height: geometry.size.height)
                        .clipped()

                    // 透明点击层:底部快捷记账行约占卡片高度 18%
                    // (与 DashboardView 底部按钮行的布局比例对齐)。
                    VStack(spacing: 0) {
                        Link(destination: detailURL) {
                            Color.clear
                        }
                        .frame(height: geometry.size.height * 0.82)
                        Link(destination: expenseURL) {
                            Color.clear
                        }
                    }
                }
            }
        } else {
            // Placeholder view when image is not available
            ZStack {
                Color(red: 1.0, green: 0.76, blue: 0.03)
                VStack {
                    Image(systemName: "square.grid.2x2.fill")
                        .font(.system(size: 32))
                        .foregroundColor(.white)
                    Text(BehaviorWidgetCopy.localized(
                        simplifiedChinese: "综合仪表盘", traditionalChinese: "綜合儀表盤",
                        english: "Dashboard"))
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
            WidgetImageContent(entry: entry) { image in
                BeeCountDashboardWidgetEntryView(image: image)
            }
        }
        .configurationDisplayName(BehaviorWidgetCopy.localized(
            simplifiedChinese: "综合仪表盘", traditionalChinese: "綜合儀表盤",
            english: "Dashboard"))
        .description(BehaviorWidgetCopy.localized(
            simplifiedChinese: "收支、趋势与最近交易一屏看尽",
            traditionalChinese: "收支、趨勢與最近交易一屏看盡",
            english: "Income, trend, and recent activity in one view"))
        .supportedFamilies([.systemLarge])
        .contentMarginsDisabled()  // Remove default padding/margins in iOS 17+
    }
}
