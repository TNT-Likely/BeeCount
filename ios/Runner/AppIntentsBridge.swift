import Foundation
import Flutter

/// AppIntents桥接插件
/// 使用弱链接支持iOS 15.0+，AppIntents功能仅在iOS 16+可用
@available(iOS 13.0, *)
class AppIntentsBridge: NSObject, FlutterPlugin {
    static let channelName = "com.beecount.app_intents"
    private static var eventChannel: FlutterEventChannel?
    private static var eventSink: FlutterEventSink?

    // 事件缓存队列（解决冷启动时序问题）
    private static var pendingEvents: [String] = []
    private static let maxPendingEvents = 5

    // openAppWhenRun=false 时,perform() 把事件丢给 Flutter 后必须**等 Flutter
    // 处理完**再返回。否则 iOS 认为 AppIntent 已结束,会很快 kill 进程,导致
    // 「正在识别」通知出来了但「成功」通知发不出去。
    //
    // Flutter 处理完 processScreenshot 后通过 MethodChannel 调
    // `notifyBillingComplete`,触发这里的 continuation 让 perform() 返回。
    private static var billingCompletionContinuations: [CheckedContinuation<Void, Never>] = []
    private static let continuationLock = NSLock()

    static func register(with registrar: FlutterPluginRegistrar) {
        let channel = FlutterMethodChannel(
            name: channelName,
            binaryMessenger: registrar.messenger()
        )

        let instance = AppIntentsBridge()
        registrar.addMethodCallDelegate(instance, channel: channel)

        // 创建事件通道用于发送AppIntent事件
        eventChannel = FlutterEventChannel(
            name: "\(channelName)/events",
            binaryMessenger: registrar.messenger()
        )
        eventChannel?.setStreamHandler(instance)
    }

    func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        switch call.method {
        case "isSupported":
            // 检查是否支持AppIntents（iOS 16+）
            if #available(iOS 16.0, *) {
                result(true)
            } else {
                result(false)
            }
        case "notifyBillingComplete":
            // Flutter 端 processScreenshot 处理完(成功/失败/超时都算)后回调
            // 唤醒所有等待的 perform() continuations
            AppIntentsBridge.resumeAllContinuations()
            print("[AppIntentsBridge] ✅ 收到 Flutter 处理完成信号")
            result(nil)
        default:
            result(FlutterMethodNotImplemented)
        }
    }

    /// 从AppIntent发送事件到Flutter
    /// 如果Flutter还未订阅，事件会被缓存，等待订阅后发送
    static func sendEvent(_ event: String) {
        DispatchQueue.main.async {
            if let sink = eventSink {
                // 如果已连接，立即发送
                sink(event)
                print("[AppIntentsBridge] ✅ 事件已发送: \(event)")
            } else {
                // 如果未连接，缓存事件（解决冷启动时序问题）
                pendingEvents.append(event)
                if pendingEvents.count > maxPendingEvents {
                    pendingEvents.removeFirst()
                }
                print("[AppIntentsBridge] 📦 事件已缓存（共\(pendingEvents.count)个）: \(event)")
            }
        }
    }

    /// AppIntent perform() 用这个方法等 Flutter 完成处理。
    /// 默认 25 秒超时(留 5s buffer 给 iOS 的 30s 后台窗口)。
    static func waitForBillingComplete(timeout: TimeInterval = 25.0) async {
        await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
            continuationLock.lock()
            billingCompletionContinuations.append(continuation)
            continuationLock.unlock()
            print("[AppIntentsBridge] ⏳ perform() 等待 Flutter 处理完成(超时 \(timeout)s)")

            // 兜底超时:如果 Flutter 卡了/挂了,iOS 30s 窗口快到时强制返回
            DispatchQueue.main.asyncAfter(deadline: .now() + timeout) {
                AppIntentsBridge.resumeAllContinuations()
            }
        }
    }

    /// 唤醒所有等待中的 continuations。重复调用安全(已 resume 的会被跳过)。
    private static func resumeAllContinuations() {
        continuationLock.lock()
        let conts = billingCompletionContinuations
        billingCompletionContinuations.removeAll()
        continuationLock.unlock()

        for cont in conts {
            cont.resume()
        }
    }
}

// MARK: - FlutterStreamHandler
@available(iOS 13.0, *)
extension AppIntentsBridge: FlutterStreamHandler {
    func onListen(withArguments arguments: Any?, eventSink events: @escaping FlutterEventSink) -> FlutterError? {
        AppIntentsBridge.eventSink = events

        // 发送缓存的事件（解决冷启动时序问题）
        DispatchQueue.main.async {
            for event in AppIntentsBridge.pendingEvents {
                events(event)
                print("[AppIntentsBridge] 📤 发送缓存事件: \(event)")
            }
            if !AppIntentsBridge.pendingEvents.isEmpty {
                print("[AppIntentsBridge] ✅ 已发送 \(AppIntentsBridge.pendingEvents.count) 个缓存事件")
            }
            AppIntentsBridge.pendingEvents.removeAll()
        }

        return nil
    }

    func onCancel(withArguments arguments: Any?) -> FlutterError? {
        AppIntentsBridge.eventSink = nil
        return nil
    }
}
