import XCTest

// The host replaces this only in a private, owned QA run.
private let controlOrigin = "__QA_CONTROL_ORIGIN__"

final class QASmoke: XCTestCase {
    private let app = XCUIApplication(bundleIdentifier: "com.tntlikely.beecount.qa")
    private let springboard = XCUIApplication(bundleIdentifier: "com.apple.springboard")

    private func control(_ path: String) {
        let done = expectation(description: path)
        URLSession.shared.dataTask(with: URL(string: controlOrigin + path)!) { _, response, error in
            XCTAssertNil(error)
            XCTAssertEqual((response as? HTTPURLResponse)?.statusCode, 200)
            done.fulfill()
        }.resume()
        wait(for: [done], timeout: 20)
    }

    private func badge(_ expected: String?) {
        // Localized InfoPlist.strings can override the QA display name.
        // This device is newly owned and contains only the verified QA App.
        let icon = springboard.icons.matching(NSPredicate(format: "label IN %@", ["BeeCount QA", "蜜蜂记账", "蜜蜂記帳", "BeeCount"])).firstMatch
        XCTAssertTrue(icon.waitForExistence(timeout: 10), springboard.debugDescription)
        let condition = NSPredicate { _, _ in
            let value = icon.value as? String ?? ""
            if let expected = expected { return value.contains(expected) }
            return value.isEmpty
        }
        let result = XCTWaiter.wait(for: [XCTNSPredicateExpectation(predicate: condition, object: icon)], timeout: 12)
        XCTAssertEqual(result, .completed, "Expected badge \(expected ?? "none"), got \(String(describing: icon.value))")
    }

    private func home() {
        XCUIDevice.shared.press(.home)
        XCTAssertTrue(springboard.wait(for: .runningForeground, timeout: 10))
        let background = NSPredicate { _, _ in
            self.app.state == .runningBackground || self.app.state == .runningBackgroundSuspended
        }
        XCTAssertEqual(XCTWaiter.wait(for: [XCTNSPredicateExpectation(predicate: background, object: app)], timeout: 10), .completed)
    }

    private func foreground() {
        XCTAssertTrue(app.wait(for: .runningForeground, timeout: 20))
        XCTAssertTrue(app.descendants(matching: .any).matching(NSPredicate(format: "label CONTAINS %@", "QA Cloud 修改后")).firstMatch.waitForExistence(timeout: 20))
    }

    func testNotificationBadgesOnNormalEntry() {
        continueAfterFailure = false
        app.activate()
        foreground()
        home()
        control("/push/warm")
        badge("7")
        control("/capture/badge-warm-before")
        app.activate()
        foreground()
        home()
        badge(nil)
        control("/capture/badge-warm-after")
        control("/pass/warm-resume")

        app.terminate()
        control("/push/cold")
        badge("9")
        control("/capture/badge-cold-before")
        app.launch()
        foreground()
        home()
        badge(nil)
        control("/capture/badge-cold-after")
        control("/pass/cold-launch")

        app.activate()
        foreground()
        control("/push/foreground")
        let banner = springboard.descendants(matching: .any).matching(NSPredicate(format: "label CONTAINS %@", "QA badge foreground")).firstMatch
        XCTAssertTrue(banner.waitForExistence(timeout: 10), "Foreground notification banner must remain visible")
        control("/capture/badge-foreground-banner")
        home()
        badge(nil)
        control("/capture/badge-foreground-after")
        control("/pass/foreground-banner-no-badge")

        control("/push/tap")
        badge("3")
        let notification = springboard.descendants(matching: .any).matching(NSPredicate(format: "label CONTAINS %@", "QA badge tap")).firstMatch
        XCTAssertTrue(notification.waitForExistence(timeout: 10))
        notification.tap()
        foreground()
        home()
        badge(nil)
        control("/capture/badge-tap-after")
        control("/pass/notification-tap")

        for _ in 0..<3 {
            app.activate()
            foreground()
            home()
            badge(nil)
        }
        control("/pass/repeated-activation")
        app.activate()
        foreground()
        control("/capture/badge-final-app")
    }
}
