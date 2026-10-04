import Foundation
import UIKit
import ImageIO
import UniformTypeIdentifiers

// 使用条件编译，只在iOS 16+编译AppIntents代码
#if canImport(AppIntents)
import AppIntents

/// 原生侧生成识别副本，避免 iOS 后台 Flutter channel 冻结影响附件保存。
struct ShortcutBillingImages {
    let attachment: URL
    let recognition: URL

    static func prepare(_ data: Data, keepOriginal: Bool, directory: URL) throws -> ShortcutBillingImages {
        guard let image = UIImage(data: data),
              let imageSource = CGImageSourceCreateWithData(data as CFData, nil) else {
            throw CocoaError(.fileReadCorruptFile)
        }
        let timestamp = UUID().uuidString
        let recognitionPath = directory.appendingPathComponent("shortcut_recognition_\(timestamp).jpg")
        let pixelWidth = image.size.width * image.scale
        let pixelHeight = image.size.height * image.scale
        // 从图片源直接降采样，避免为了识别副本解码整张超长截图。
        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceThumbnailMaxPixelSize: min(1920, max(pixelWidth, pixelHeight)),
        ]
        guard let thumbnail = CGImageSourceCreateThumbnailAtIndex(imageSource, 0, options as CFDictionary) else {
            throw CocoaError(.fileReadCorruptFile)
        }
        let recognitionImage = UIImage(cgImage: thumbnail)
        guard let recognitionData = recognitionImage.jpegData(compressionQuality: 0.85) else {
            throw CocoaError(.fileWriteUnknown)
        }

        let typeIdentifier = CGImageSourceGetType(imageSource) as String?
        let fileExtension = keepOriginal
            ? (typeIdentifier.flatMap { UTType($0)?.preferredFilenameExtension } ?? "jpg")
            : "jpg"
        let attachmentPath = directory.appendingPathComponent("shortcut_screenshot_\(timestamp).\(fileExtension)")
        // 关闭开关时沿用原有 JPEG 质量；开启时直接保存传入字节。
        let attachmentData = keepOriginal ? data : image.jpegData(compressionQuality: 0.85)
        guard let attachmentData = attachmentData else {
            throw CocoaError(.fileWriteUnknown)
        }
        try attachmentData.write(to: attachmentPath)
        try recognitionData.write(to: recognitionPath)
        return ShortcutBillingImages(attachment: attachmentPath, recognition: recognitionPath)
    }
}

/// 蜜蜂记账 - 截图自动记账 AppIntent
/// 通过iOS快捷指令触发，实现截图后自动识别并记账
/// 仅iOS 16+可用，但App可在iOS 15+运行
///
/// openAppWhenRun = false:Shortcut 触发时不把 app 拉到前台。iOS 仍会
/// background-launch app 进程把 Flutter Engine 跑起来,AI 识别 + 落库
/// 全在后台完成,用户只感知到系统通知。
///
/// iOS 后台执行硬窗口 30 秒,实测 AI 视觉 + 落库 4-9 秒,留有余量。
/// 极端情况(网络抖动)若超时被 iOS kill,这张截图不会再被 Shortcut
/// 重试(Shortcut 已经把图传过来一次就走了),用户感知为「截图后没收到
/// 通知」,可手动改用相册记账兜底。
@available(iOS 16.0, *)
struct AutoBillingAppIntent: AppIntent {
    static var title: LocalizedStringResource = "截图自动记账"
    static var description: LocalizedStringResource = "自动识别截图中的支付信息并创建账单"
    static var openAppWhenRun: Bool = false

    // 接收截图参数
    @Parameter(title: "截图")
    var screenshot: IntentFile?

    @MainActor
    func perform() async throws -> some IntentResult {
        // 如果快捷指令传递了图片，保存到临时目录
        if let screenshot = screenshot {
            print("[AppIntent] 收到截图参数，文件名: \(screenshot.filename)")

            // 尝试获取图片数据
            var imageData: Data?

            // 优先使用fileURL
            if let fileURL = screenshot.fileURL {
                print("[AppIntent] 从fileURL读取: \(fileURL.path)")
                imageData = try? Data(contentsOf: fileURL)
            }

            // 如果没有fileURL，尝试直接获取data
            if imageData == nil {
                print("[AppIntent] 尝试直接获取data属性")
                imageData = screenshot.data
            }

            // 如果都没有，尝试从filename构造路径
            if imageData == nil {
                print("[AppIntent] 尝试从filename读取: \(screenshot.filename)")
                let fileURL = URL(fileURLWithPath: screenshot.filename)
                imageData = try? Data(contentsOf: fileURL)
            }

            if let imageData = imageData {
                do {
                    let images = try ShortcutBillingImages.prepare(
                        imageData,
                        keepOriginal: UserDefaults.standard.bool(forKey: "flutter.attachmentKeepOriginal"),
                        directory: FileManager.default.temporaryDirectory
                    )
                    print("[AppIntent] 图片已保存到: \(images.attachment.path)")

                    // 分别传递识别副本和附件源文件，JSON 编码保留路径中的特殊字符。
                    let eventData = try JSONSerialization.data(withJSONObject: [
                        "action": "auto-billing",
                        "imagePath": images.attachment.path,
                        "recognitionImagePath": images.recognition.path,
                    ])
                    AppIntentsBridge.sendEvent(String(decoding: eventData, as: UTF8.self))
                    // 等 Flutter 完成附件保存和通知，避免后台进程提前退出。
                    await AppIntentsBridge.waitForBillingComplete()
                    return .result()
                } catch {
                    print("[AppIntent] 保存图片失败: \(error)")
                }
            } else {
                print("[AppIntent] 无法加载图片数据")
            }
        } else {
            print("[AppIntent] 未收到截图参数")
        }

        // 如果没有图片参数或处理失败，只发送事件（让Flutter端处理）
        let event = "{\"action\":\"auto-billing\"}"
        AppIntentsBridge.sendEvent(event)
        await AppIntentsBridge.waitForBillingComplete()
        return .result()
    }

    static var parameterSummary: some ParameterSummary {
        Summary("识别\(\.$screenshot)中的支付信息")
    }
}

/// Siri快捷语音指令配置（可选）
/// 用户可以对Siri说："在蜜蜂记账中截图记账"来触发
@available(iOS 16.0, *)
struct AutoBillingShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: AutoBillingAppIntent(),
            phrases: [
                "在\(.applicationName)中截图记账",
                "用\(.applicationName)记账",
                "打开\(.applicationName)自动记账"
            ]
        )
    }
}
#endif
