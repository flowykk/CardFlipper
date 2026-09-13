import XCTest

@MainActor
final class AccessibilityLayoutTests: XCTestCase {
    private lazy var app = XCUIApplication()

    func testEmptyLibraryClearsToolbarAtAccessibilityXXXL() {
        continueAfterFailure = false
        app.launchArguments = [
            "-uiTesting",
            "-AppleLanguages", "(en)",
            "-AppleLocale", "en_US",
            "-UIPreferredContentSizeCategoryName",
            "UICTContentSizeCategoryAccessibilityXXXL",
        ]
        app.launch()

        let title = app.staticTexts["Your Library Is Empty"]
        XCTAssertTrue(title.waitForExistence(timeout: 5))
        XCTAssertGreaterThan(title.frame.minY, app.navigationBars.firstMatch.frame.maxY)
        let addButton = app.buttons["Add Card"]
        let importCards = app.buttons["Import Cards"]
        scrollToHittable(addButton)
        scrollToHittable(importCards)

        let screenshot = XCTAttachment(screenshot: app.screenshot())
        screenshot.name = "AX-Empty-Library"
        screenshot.lifetime = .keepAlways
        add(screenshot)
    }

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

    func testWritingAnswerAndCheckRemainReachableAtAccessibilityXXXL() {
        continueAfterFailure = false
        app.launchArguments = [
            "-uiTesting",
            "-uiTestSeed",
            "-AppleLanguages", "(en)",
            "-AppleLocale", "en_US",
            "-UIPreferredContentSizeCategoryName",
            "UICTContentSizeCategoryAccessibilityXXXL",
        ]
        app.launch()

        let study = app.descendants(matching: .any)["library.study"].firstMatch
        XCTAssertTrue(study.waitForExistence(timeout: 5))
        study.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
        tap("study.mode.writing")
        tap("study.start")

        let field = app.textFields["study.writing.answer"]
        let check = app.buttons["study.writing.check"]
        let writingCard = app.otherElements["study.writing.card"]
        XCTAssertTrue(field.waitForExistence(timeout: 5))
        XCTAssertTrue(check.waitForExistence(timeout: 5))
        XCTAssertTrue(writingCard.waitForExistence(timeout: 5))
        XCTAssertFalse(app.buttons["study.writing.showAnswer"].exists)
        XCTAssertFalse(app.buttons["study.writing.hideAnswer"].exists)
        scrollToHittable(field)
        scrollToHittable(check)
        XCTAssertFalse(field.frame.intersects(check.frame))
        XCTAssertLessThan(field.frame.maxX, check.frame.minX)
        XCTAssertGreaterThanOrEqual(check.frame.width, 44)

        let screenshot = XCTAttachment(screenshot: app.screenshot())
        screenshot.name = "AX-Writing-Answer"
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
        let details = app.buttons["editor.english.0.details"]
        XCTAssertTrue(russian.waitForExistence(timeout: 3))
        scrollToHittable(english)
        XCTAssertTrue(english.isHittable)
        english.tap()
        english.typeText("word")
        dismissKeyboard()
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
        XCTAssertTrue(app.searchFields["Search parts of speech"].waitForExistence(timeout: 8))

        let screenshot = XCTAttachment(screenshot: app.screenshot())
        screenshot.name = "AX-Editor-Progressive-Details"
        screenshot.lifetime = .keepAlways
        add(screenshot)
    }

    func testAppearancePickersRemainReadableAtAccessibilityXXXL() {
        continueAfterFailure = false
        app.launchArguments = [
            "-uiTesting",
            "-uiTestSeed",
            "-AppleLanguages", "(en)",
            "-AppleLocale", "en_US",
            "-UIPreferredContentSizeCategoryName",
            "UICTContentSizeCategoryAccessibilityXXXL",
        ]
        app.launch()

        tap("library.settings")
        let colorPicker = app.descendants(matching: .any)["settings.colorPicker"]
        scrollToHittable(colorPicker)
        XCTAssertTrue(colorPicker.isHittable)

        let iconPicker = app.scrollViews["settings.iconPicker"]
        scrollToHittable(iconPicker)
        let midnight = app.buttons["settings.icon.IconMidnight3D"]
        for _ in 0..<10 {
            if midnight.exists, midnight.isHittable { break }
            let start = iconPicker.coordinate(withNormalizedOffset: CGVector(dx: 0.85, dy: 0.5))
            let end = iconPicker.coordinate(withNormalizedOffset: CGVector(dx: 0.15, dy: 0.5))
            start.press(forDuration: 0.05, thenDragTo: end)
        }
        XCTAssertTrue(midnight.label.contains("Night"))
        XCTAssertTrue(midnight.isHittable)

        let screenshot = XCTAttachment(screenshot: app.screenshot())
        screenshot.name = "AX-Appearance-Pickers"
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

    private func dismissKeyboard() {
        let keyboard = app.keyboards.firstMatch
        guard keyboard.exists else { return }
        let returnKey = keyboard.buttons["Return"]
        XCTAssertTrue(returnKey.waitForExistence(timeout: 2))
        returnKey.tap()
        XCTAssertFalse(keyboard.waitForExistence(timeout: 2))
    }

    private func scrollToHittable(_ element: XCUIElement) {
        for _ in 0..<10 {
            if element.exists, element.isHittable { return }
            app.swipeUp()
        }
        XCTFail("Expected hittable element: \(element), frame: \(element.frame), app: \(app.frame)")
    }
}
