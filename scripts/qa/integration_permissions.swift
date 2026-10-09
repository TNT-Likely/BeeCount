import XCTest

// This runner is installed only after its IDs and the new QA UDID are verified.
final class QASmoke: XCTestCase {
    func testNotificationPermissionOnOwnedDevice() {
        continueAfterFailure = false
        let springboard = XCUIApplication(bundleIdentifier: "com.apple.springboard")
        let deadline = Date().addingTimeInterval(90)
        while Date() < deadline {
            let alert = springboard.alerts.firstMatch
            if alert.waitForExistence(timeout: 1) {
                let text = alert.label + " " + alert.staticTexts.allElementsBoundByIndex.map { $0.label }.joined(separator: " ")
                if text.contains("发送通知") || text.lowercased().contains("send you notifications") {
                    let allow = alert.buttons.matching(NSPredicate(format: "label IN %@", ["允许", "Allow"]))
                    XCTAssertEqual(allow.count, 1)
                    allow.firstMatch.tap()
                    return
                }
            }
        }
        // Some scenarios never request notifications; no permission mutation is needed.
    }
}
