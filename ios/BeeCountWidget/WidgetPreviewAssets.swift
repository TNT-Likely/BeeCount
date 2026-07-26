//
//  WidgetPreviewAssets.swift
//  BeeCountWidget
//
//  添加页(widget gallery)的静态预览资产。
//
//  背景:各 provider 的 getSnapshot 读的是 App Group 里由主 App 渲染管线
//  写入的运行时图片路径——但 iOS 添加页的预览渲染发生在受限上下文里,
//  读不到 App Group 文件(已知系统行为),导致添加页只能看到占位色块。
//  解法:把与 Android 选择器同一套静态预览 PNG(Previews/ 目录,随
//  test/widget/widget_preview_generator_test.dart 生成,中英双语)打进扩展
//  bundle,placeholder / isPreview 快照直接用 bundle 内文件——bundle 内
//  资源在预览上下文里没有访问限制。
//

import Foundation

enum WidgetPreviewAssets {
    /// 渲染管线 imageKey → 预览资产 base 名(与 Android
    /// res/drawable-nodpi 的文件名一致;语言后缀 _zh/_en 由 [path] 追加)。
    private static let assetByImageKey: [String: String] = [
        "widgetImage": "widget_preview_glance",
        "widget_glance_small": "widget_preview_glance_small",
        "widget_netWorth_small": "widget_preview_networth_small",
        "widget_netWorth_medium": "widget_preview_networth",
        "widget_netWorth_large": "widget_preview_networth_large",
        "widget_quickAdd_small": "widget_preview_quickadd",
        "widget_quickAdd_medium": "widget_preview_quickadd_medium",
        "widget_budget_small": "widget_preview_budget",
        "widget_budget_medium": "widget_preview_budget_medium",
        "widget_recent_medium": "widget_preview_recent",
        "widget_recent_large": "widget_preview_recent_large",
        "widget_dashboard_large": "widget_preview_dashboard",
    ]

    /// 按系统语言(zh → 中文,其余 → 英文)返回 bundle 内预览 PNG 的路径;
    /// 找不到时返回空串(EntryView 会走占位分支,不崩)。
    static func path(forImageKey imageKey: String) -> String {
        guard let base = assetByImageKey[imageKey] else { return "" }
        let lang = Locale.preferredLanguages.first?.lowercased().hasPrefix("zh") == true
            ? "zh" : "en"
        return Bundle.main.path(forResource: "\(base)_\(lang)", ofType: "png")
            ?? Bundle.main.path(forResource: "\(base)_zh", ofType: "png")
            ?? ""
    }
}
