import XCTest
final class QASmoke: XCTestCase {
    func testNormalAppAfterPermissions() {
        continueAfterFailure = false
        let app = XCUIApplication(bundleIdentifier: "com.tntlikely.beecount.qa")
        app.activate()
        let springboard = XCUIApplication(bundleIdentifier: "com.apple.springboard")
        for _ in 0..<3 {
            if springboard.alerts.firstMatch.waitForExistence(timeout: 4) {
                let allow = springboard.alerts.buttons.matching(NSPredicate(format: "label IN %@", ["允许", "Allow"]))
                XCTAssertEqual(allow.count, 1)
                allow.firstMatch.tap()
            }
        }
        XCTAssertTrue(app.wait(for: .runningForeground, timeout: 20))
        let copied = app.descendants(matching: .any).matching(NSPredicate(format: "label CONTAINS %@", "QA Cloud 修改后")).firstMatch
        for _ in 0..<6 {
            if copied.waitForExistence(timeout: 2) && copied.isHittable { break }
            app.swipeUp()
        }
        XCTAssertTrue(copied.exists && copied.isHittable, "Synchronized copy must be visible in normal homepage")
        XCTAssertTrue(app.descendants(matching: .any).matching(NSPredicate(format: "label CONTAINS %@", "55.5")).firstMatch.exists)
        let picture = XCTAttachment(screenshot: app.screenshot())
        picture.lifetime = .keepAlways
        add(picture)
    }
}
