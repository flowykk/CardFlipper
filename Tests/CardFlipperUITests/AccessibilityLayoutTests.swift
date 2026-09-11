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

    func testEditorProgressiveDetailsRemainReachableAtAccessibilityXXXL() {
        continueAfterFailure = false
        app.launchArguments = [
            "-uiTesting",
            "-AppleLanguages", "(en)",
            "-AppleLocale", "en_US",
            "-UIPreferredContentSizeCategoryName",
            "UICTContentSizeCategoryAccessibilityXXXL",
        ]
        app.launch()

        tap("library.add")
        assertExists("editor.root")
        XCTAssertFalse(app.staticTexts["Add at least one English translation."].exists)
        XCTAssertFalse(app.staticTexts["Add at least one Russian meaning."].exists)

        let russian = app.textFields["editor.russian.0"]
        let english = app.textFields["editor.english.0"]
        let details = app.descendants(matching: .any)["editor.english.0.details"]
        XCTAssertTrue(russian.waitForExistence(timeout: 3))
        scrollToHittable(english)
        XCTAssertTrue(english.isHittable)
        english.tap()
        english.typeText("word")
        scrollToHittable(details)
        details.tap()

        let ipa = app.textFields["editor.ipa.0"]
        let partPicker = app.descendants(matching: .any)["editor.english.0.partOfSpeechPicker"]
        scrollToHittable(ipa)
        XCTAssertTrue(ipa.isHittable)
        scrollToHittable(partPicker)
        XCTAssertTrue(partPicker.isHittable)
        XCTAssertTrue(app.navigationBars.buttons["Save"].isHittable)

        partPicker.tap()
        XCTAssertTrue(app.searchFields["Search parts of speech"].waitForExistence(timeout: 3))

        let screenshot = XCTAttachment(screenshot: app.screenshot())
        screenshot.name = "AX-Editor-Progressive-Details"
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
