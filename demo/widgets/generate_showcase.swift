// 在 macOS 的项目根目录执行：swift demo/widgets/generate_showcase.swift
// 直接排版扩展内的真实小组件预览，不重绘组件 UI。
// 新增类型或尺寸后更新 columns；标题数量由目录自动计算。
import AppKit

struct WidgetGroup {
    let zh: String
    let en: String
    let sizes: String
    let assets: [String]
}

let columns: [[WidgetGroup]] = [
    [
        .init(zh: "收支速览", en: "Overview", sizes: "S · M",
              assets: ["glance_small", "glance"]),
        .init(zh: "快速记账", en: "Quick Add", sizes: "S · M",
              assets: ["quickadd", "quickadd_medium"]),
        .init(zh: "预算进度", en: "Budget", sizes: "S · M",
              assets: ["budget", "budget_medium"]),
    ],
    [
        .init(zh: "净资产", en: "Net Assets", sizes: "S · M · L",
              assets: ["networth_small", "networth", "networth_large"]),
        .init(zh: "消费节奏", en: "Spending Rhythm", sizes: "M",
              assets: ["consumption_rhythm"]),
        .init(zh: "记账连续蜂迹", en: "Record Bee Trail", sizes: "S",
              assets: ["bee_trail"]),
    ],
    [
        .init(zh: "最近交易", en: "Recent Transactions", sizes: "M · L",
              assets: ["recent", "recent_large"]),
        .init(zh: "综合仪表盘", en: "Dashboard", sizes: "L",
              assets: ["dashboard"]),
    ],
]

let repo = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
    .deletingLastPathComponent().deletingLastPathComponent()
let source = repo.appendingPathComponent("ios/BeeCountWidget/Previews")
let output = repo.appendingPathComponent("demo/widgets")
let groups = columns.flatMap { $0 }
let variants = groups.reduce(0) { $0 + $1.assets.count }
let canvasWidth: CGFloat = 1600
let margin: CGFloat = 48
let gap: CGFloat = 24
let cardWidth = (canvasWidth - margin * 2 - gap * 2) / 3
let inset: CGFloat = 20
let innerWidth = cardWidth - inset * 2
let ink = NSColor(srgbRed: 0.17, green: 0.15, blue: 0.12, alpha: 1)
let muted = NSColor(srgbRed: 0.45, green: 0.41, blue: 0.34, alpha: 1)
let honey = NSColor(srgbRed: 0.93, green: 0.58, blue: 0.03, alpha: 1)

func text(_ string: String, x: CGFloat, y: CGFloat, size: CGFloat,
          color: NSColor = ink, weight: NSFont.Weight = .regular) {
    (string as NSString).draw(at: .init(x: x, y: y), withAttributes: [
        .font: NSFont.systemFont(ofSize: size, weight: weight),
        .foregroundColor: color,
    ])
}

for lang in ["zh", "en"] {
    var previews: [String: NSImage] = [:]
    for group in groups {
        for asset in group.assets {
            let url = source.appendingPathComponent("widget_preview_\(asset)_\(lang).png")
            guard let image = NSImage(contentsOf: url) else {
                fatalError("缺少预览素材：\(url.path)")
            }
            previews[asset] = image
        }
    }
    func displaySize(_ asset: String) -> NSSize {
        let image = previews[asset]!
        let isSmall = abs(image.size.width - image.size.height) < 1
        let width = isSmall ? innerWidth * 155 / 364 : innerWidth
        return .init(width: width, height: width * image.size.height / image.size.width)
    }
    func cardHeight(_ group: WidgetGroup) -> CGFloat {
        48 + group.assets.reduce(CGFloat(0)) { $0 + displaySize($1).height }
            + CGFloat(group.assets.count - 1) * 16 + inset
    }
    let tallest = columns.map { column in
        column.reduce(CGFloat(0)) { $0 + cardHeight($1) }
            + CGFloat(column.count - 1) * gap
    }.max()!
    let canvasHeight = ceil(140 + tallest + 84)
    guard let bitmap = NSBitmapImageRep(bitmapDataPlanes: nil,
            pixelsWide: Int(canvasWidth), pixelsHigh: Int(canvasHeight),
            bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true,
            isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0,
            bitsPerPixel: 0), let context = NSGraphicsContext(bitmapImageRep: bitmap) else {
        fatalError("无法创建画布")
    }
    NSGraphicsContext.saveGraphicsState()
    let cg = context.cgContext
    cg.translateBy(x: 0, y: canvasHeight)
    cg.scaleBy(x: 1, y: -1)
    NSGraphicsContext.current = NSGraphicsContext(cgContext: cg, flipped: true)
    NSColor(srgbRed: 1, green: 0.975, blue: 0.94, alpha: 1).setFill()
    NSBezierPath(rect: .init(x: 0, y: 0, width: canvasWidth, height: canvasHeight)).fill()

    let title = lang == "zh" ? "蜜蜂记账桌面小组件" : "BeeCount Home Widgets"
    let count = lang == "zh" ? "\(groups.count) 类内容 · \(variants) 种规格"
                            : "\(groups.count) types · \(variants) variants"
    text(title, x: margin, y: 38, size: 32, weight: .bold)
    let titleWidth = (title as NSString).size(withAttributes: [
        .font: NSFont.systemFont(ofSize: 32, weight: .bold),
    ]).width
    text(count, x: margin + titleWidth + 26, y: 38, size: 32, color: honey, weight: .bold)
    text(lang == "zh" ? "随时看账，一点直达记账 · 支持 iOS 与 Android · 暗黑、语言与主题色跟随 App"
                     : "Your ledger at a glance, one tap to record · iOS & Android · Dark mode, language & theme aware",
         x: margin, y: 88, size: 18, color: muted)

    for (columnIndex, column) in columns.enumerated() {
        let x = margin + CGFloat(columnIndex) * (cardWidth + gap)
        var y: CGFloat = 140
        for group in column {
            let height = cardHeight(group)
            let card = NSBezierPath(roundedRect: .init(x: x, y: y,
                    width: cardWidth, height: height), xRadius: 24, yRadius: 24)
            NSColor.white.withAlphaComponent(0.8).setFill()
            card.fill()
            NSColor(srgbRed: 0.91, green: 0.88, blue: 0.83, alpha: 1).setStroke()
            card.lineWidth = 1
            card.stroke()
            let name = lang == "zh" ? group.zh : group.en
            text(name, x: x + inset, y: y + 14, size: 22, weight: .bold)
            let nameWidth = (name as NSString).size(withAttributes: [
                .font: NSFont.systemFont(ofSize: 22, weight: .bold),
            ]).width
            text(group.sizes, x: x + inset + nameWidth + 12, y: y + 19,
                 size: 15, color: honey, weight: .semibold)
            var imageY = y + 48
            for asset in group.assets {
                let size = displaySize(asset)
                let rect = NSRect(x: x + inset, y: imageY, width: size.width, height: size.height)
                NSGraphicsContext.saveGraphicsState()
                let shadow = NSShadow()
                shadow.shadowColor = NSColor.black.withAlphaComponent(0.09)
                shadow.shadowBlurRadius = 16
                shadow.shadowOffset = .init(width: 0, height: 6)
                shadow.set()
                NSColor.white.setFill()
                NSBezierPath(roundedRect: rect, xRadius: 22, yRadius: 22).fill()
                NSGraphicsContext.restoreGraphicsState()
                previews[asset]!.draw(in: rect, from: .zero, operation: .sourceOver,
                    fraction: 1, respectFlipped: true, hints: [.interpolation: NSImageInterpolation.high])
                imageY += size.height + 16
            }
            y += height + gap
        }
    }
    text(lang == "zh" ? "小 S · 中 M · 大 L   |   消费节奏：近 30 天支出   |   记账连续蜂迹：近 28 天记录"
                     : "S · Small   M · Medium   L · Large   |   Rhythm: 30-day spending   |   Bee Trail: 28-day records",
         x: margin, y: canvasHeight - 48, size: 18, color: muted)
    NSGraphicsContext.restoreGraphicsState()
    guard let png = bitmap.representation(using: .png, properties: [:]) else {
        fatalError("无法编码 PNG")
    }
    let destination = output.appendingPathComponent("widgets-showcase-\(lang).png")
    try png.write(to: destination)
    print("\(destination.lastPathComponent)：\(groups.count) 类、\(variants) 种规格，\(Int(canvasWidth))×\(Int(canvasHeight))")
}
