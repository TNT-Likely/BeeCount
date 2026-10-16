import XCTest

// Installed only after the runner has verified this run's UDID and QA bundle IDs.
final class QASmoke: XCTestCase {
    func testReceiptShareCancellation() {
        continueAfterFailure = false
        let app = XCUIApplication(bundleIdentifier: "com.tntlikely.beecount.qa")
        let springboard = XCUIApplication(bundleIdentifier: "com.apple.springboard")
        let deadline = Date().addingTimeInterval(240)
        while Date() < deadline {
            let alert = springboard.alerts.firstMatch
            if alert.exists {
                let allow = alert.buttons.matching(NSPredicate(format: "label IN %@", ["允许", "Allow", "允许添加照片", "Allow Photos to Be Added"]))
                if allow.count == 1 { allow.firstMatch.tap() }
            }
            // iOS 26 uses a draggable sheet without a visible Cancel button.
            let copy = app.descendants(matching: .any).matching(NSPredicate(format: "label IN %@", ["拷贝", "复制", "Copy"]))
            if copy.firstMatch.exists && copy.firstMatch.isHittable {
                let shot = XCTAttachment(screenshot: app.screenshot())
                shot.name = "receipt-native-share-sheet"
                shot.lifetime = .keepAlways
                add(shot)
                app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.61))
                    .press(forDuration: 0.1, thenDragTo: app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.98)))
                XCTAssertTrue(copy.firstMatch.waitForNonExistence(timeout: 10), "Share sheet must dismiss after dragging down")
                return
            }
            Thread.sleep(forTimeInterval: 0.5)
        }
        XCTFail("The actual receipt share sheet was never presented")
    }
}
