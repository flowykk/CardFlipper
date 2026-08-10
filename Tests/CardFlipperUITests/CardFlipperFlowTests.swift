import XCTest

@MainActor
final class CardFlipperFlowTests: XCTestCase {
    private lazy var app = XCUIApplication()

    func testF1FirstLaunchReachesEditorAndReturnsToEmptyLibrary() throws {
        launch(seed: false)

        XCTAssertTrue(app.staticTexts["Your Library Is Empty"].waitForExistence(timeout: 5))
        snap("F1-01-empty-library")

        tap("library.add")
        assertExists("editor.root")
        snap("F1-02-editor")
        XCTAssertTrue(app.navigationBars.buttons["Cancel"].waitForExistence(timeout: 3))
        app.navigationBars.buttons["Cancel"].tap()
        XCTAssertTrue(app.staticTexts["Your Library Is Empty"].waitForExistence(timeout: 5))
        snap("F1-03-returned-empty-library")
    }

    func testF1SeededLibraryReopensPrefilledEditor() throws {
        launch(seed: true)
        assertExists("library.card")
        snap("F1-04-seeded-library")

        let firstCard = app.buttons.matching(identifier: "library.card").firstMatch
        XCTAssertTrue(firstCard.waitForExistence(timeout: 5))
        firstCard.tap()
        assertExists("editor.root")
        XCTAssertEqual(app.textFields["editor.russian.0"].value as? String, "книга")
        snap("F1-05-reopened-editor")
    }

    func testF2StudyForgetRememberRepeatAndFinish() throws {
        launch(seed: true)

        assertExists("library.card")
        snap("F2-01-seeded-library")
        tap("library.study")
        assertExists("study.setup")
        snap("F2-02-study-setup")

        tap("study.direction.russianToEnglish")
        tap("study.start")
        assertExists("study.card.prompt")
        snap("F2-03-first-prompt")

        tap("study.card.prompt")
        assertExists("study.forget")
        snap("F2-04-first-answer")
        tap("study.forget")
        snap("F2-05-forgotten-card-requeued")

        rememberCurrentCard()
        rememberCurrentCard()
        rememberCurrentCard()
        assertExists("study.result")
        snap("F2-06-result")

        tap("study.repeat")
        assertExists("study.card.prompt")
        snap("F2-07-repeat-session")
        rememberCurrentCard()
        rememberCurrentCard()
        rememberCurrentCard()
        assertExists("study.result")
        tap("study.finish")
        assertExists("library.root")
        snap("F2-08-finished-library")
    }

    func testF3SeededCardDeletionRefreshesLibrary() throws {
        launch(seed: true)

        let card = app.buttons.matching(identifier: "library.card").firstMatch
        XCTAssertTrue(card.waitForExistence(timeout: 5))
        card.swipeLeft()
        XCTAssertTrue(app.buttons["Delete"].waitForExistence(timeout: 3))
        app.buttons["Delete"].tap()
        snap("F3-01-delete-confirmation")
        XCTAssertTrue(app.buttons["Delete"].waitForExistence(timeout: 3))
        app.buttons["Delete"].tap()
        let refreshed = XCTNSPredicateExpectation(
            predicate: NSPredicate { _, _ in
                self.app.buttons.matching(identifier: "library.card").count == 2
            },
            object: nil
        )
        wait(for: [refreshed], timeout: 5)
        snap("F3-02-library-refreshed")
    }

    private func launch(seed: Bool) {
        continueAfterFailure = false
        app.launchArguments = [
            "-uiTesting",
            "-AppleLanguages", "(en)",
            "-AppleLocale", "en_US",
        ]
        if seed {
            app.launchArguments.append("-uiTestSeed")
        }
        app.launch()
        assertExists("library.root")
    }

    private func rememberCurrentCard() {
        tap("study.card.prompt")
        assertExists("study.remember")
        tap("study.remember")
    }

    private func tap(_ identifier: String) {
        let element = app.descendants(matching: .any)[identifier]
        scrollToHittable(element)
        element.tap()
    }

    private func assertExists(_ identifier: String) {
        XCTAssertTrue(
            app.descendants(matching: .any)[identifier].waitForExistence(timeout: 5),
            "Expected accessibility identifier \(identifier)"
        )
    }

    private func scrollToHittable(_ element: XCUIElement) {
        var attempts = 0
        while (!element.exists || !element.isHittable) && attempts < 8 {
            let scrollView = app.collectionViews.firstMatch
            if scrollView.exists {
                scrollView.swipeUp()
            } else {
                app.swipeUp()
            }
            attempts += 1
        }
        XCTAssertTrue(element.exists, "Expected \(element)")
        XCTAssertTrue(element.isHittable, "Expected hittable \(element)")
    }

    private func snap(_ name: String) {
        let attachment = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }

}
