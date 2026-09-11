import XCTest

@MainActor
final class AccessibilityLayoutTests: XCTestCase {
    private lazy var app = XCUIApplication()

    func testStudyPrimaryActionsRemainReachableAtAccessibilityXXXL() {
        continueAfterFailure = false
        app.launchArguments = [
            "-uiTesting",
            "-uiTestSeed",
            "-AppleLanguages", "(en)",
            "-AppleLocale", "en_US",
            "-AppleInterfaceStyle", "Dark",
            "-UIPreferredContentSizeCategoryName",
            "UICTContentSizeCategoryAccessibilityXXXL",
        ]
        app.launch()

        tap("library.study")
        assertExists("study.setup")
        tap("study.start")
        assertExists("study.card.prompt")
        tapCard("study.card.prompt")

        let remember = app.descendants(matching: .any)["study.remember"]
        let forget = app.descendants(matching: .any)["study.forget"]
        let timer = app.descendants(matching: .any)["study.timer"]
        XCTAssertTrue(remember.waitForExistence(timeout: 5))
        XCTAssertTrue(forget.waitForExistence(timeout: 5))
        XCTAssertTrue(timer.waitForExistence(timeout: 5))
        XCTAssertTrue(remember.isHittable)
        XCTAssertTrue(forget.isHittable)
        XCTAssertFalse(remember.frame.intersects(timer.frame))
        XCTAssertFalse(forget.frame.intersects(timer.frame))

        let screenshot = XCTAttachment(screenshot: app.screenshot())
        screenshot.name = "AX-Study-Answer"
        screenshot.lifetime = .keepAlways
        add(screenshot)
    }

    private func tap(_ identifier: String) {
        let element = app.descendants(matching: .any)[identifier]
        scrollToHittable(element)
        element.tap()
    }

    private func tapCard(_ identifier: String) {
        let card = app.descendants(matching: .any)[identifier]
        scrollToHittable(card)
        card.coordinate(withNormalizedOffset: CGVector(dx: 0.9, dy: 0.15)).tap()
    }

    private func assertExists(_ identifier: String) {
        XCTAssertTrue(
            app.descendants(matching: .any)[identifier].waitForExistence(timeout: 5),
            "Expected accessibility identifier \(identifier)"
        )
    }

    private func scrollToHittable(_ element: XCUIElement) {
        for _ in 0..<10 {
            if element.exists, element.isHittable { return }
            app.swipeUp()
        }
        XCTFail("Expected hittable element: \(element)")
    }
}
