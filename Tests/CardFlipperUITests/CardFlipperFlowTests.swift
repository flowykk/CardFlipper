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
        tapTrailingEmptySpace(in: firstCard)
        assertExists("editor.root")
        XCTAssertEqual(app.textFields["editor.russian.0"].value as? String, "книга")
        let noun = app.descendants(matching: .any)[
            "editor.english.0.partOfSpeech.noun"
        ]
        XCTAssertTrue(noun.waitForExistence(timeout: 3))
        XCTAssertTrue(noun.label.contains("Noun"), "Expected localized POS label, got \(noun.label)")
        XCTAssertFalse(noun.label.contains("partOfSpeech.noun"))
        tap("editor.english.0.example.add")
        let newExample = app.descendants(matching: .any)["editor.english.0.example.1.text"]
        scrollToHittable(newExample)
        newExample.tap()
        newExample.typeText("This is another useful example.")
        dismissKeyboard()
        let save = app.navigationBars.buttons["Save"]
        XCTAssertTrue(save.waitForExistence(timeout: 3))
        save.tap()
        assertExists("library.card")

        let savedCard = app.buttons.matching(identifier: "library.card").firstMatch
        tapTrailingEmptySpace(in: savedCard)
        let reopenedExample = app.descendants(matching: .any)[
            "editor.english.0.example.1.text"
        ]
        XCTAssertTrue(reopenedExample.waitForExistence(timeout: 5))
        XCTAssertEqual(reopenedExample.value as? String, "This is another useful example.")
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

        tapEmptyCardSpace("study.card.prompt")
        assertExists("study.forget")
        snap("F2-04-first-answer")

        tapEmptyCardSpace("study.card.answer")
        assertExists("study.card.prompt")
        assertExists("study.forget")
        assertExists("study.remember")
        snap("F2-04b-returned-prompt-assessment-unlocked")

        tapEmptyCardSpace("study.card.prompt")
        assertExists("study.card.answer")
        tap("study.forget")
        waitForStablePromptAfterAssessment()
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

    func testF4SeededUsageExamplesExpandBelowAssessmentActions() throws {
        launch(seed: true)
        tap("library.study")
        assertExists("study.setup")
        tap("study.start")

        for _ in 0..<3 {
            assertExists("study.card.prompt")
            tapEmptyCardSpace("study.card.prompt")
            assertExists("study.remember")

            let examplesToggle = app.descendants(matching: .any)["study.examples.toggle"]
            if examplesToggle.waitForExistence(timeout: 1) {
                let example = app.descendants(matching: .any)["study.usageExample"]
                XCTAssertFalse(example.exists)

                tap("study.examples.toggle")
                XCTAssertEqual(example.label, "This book is easy to read.")
                assertExists("study.usageExample.speak")
                snap("F4-01-expanded-usage-examples")

                tapEmptyCardSpace("study.card.answer")
                assertExists("study.card.prompt")
                XCTAssertEqual(example.label, "This book is easy to read.")

                tapEmptyCardSpace("study.card.prompt")
                assertExists("study.card.answer")
                XCTAssertEqual(example.label, "This book is easy to read.")

                tap("study.remember")
                assertExists("study.card.prompt")
                XCTAssertFalse(
                    app.descendants(matching: .any)["study.examples.container"].waitForExistence(timeout: 1)
                )
                return
            }

            tap("study.forget")
            waitForStablePromptAfterAssessment()
        }

        XCTFail("Expected seeded usage example within the study queue")
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
        tapEmptyCardSpace("study.card.prompt")
        assertExists("study.remember")
        tap("study.remember")
    }

    private func tapEmptyCardSpace(_ identifier: String) {
        let card = app.descendants(matching: .any)[identifier]
        scrollToHittable(card)
        card.coordinate(withNormalizedOffset: CGVector(dx: 0.9, dy: 0.15)).tap()
    }

    private func tapTrailingEmptySpace(in row: XCUIElement) {
        scrollToHittable(row)
        let appOrigin = app.coordinate(withNormalizedOffset: CGVector(dx: 0, dy: 0))
        appOrigin.withOffset(
            CGVector(dx: app.frame.width - 24, dy: row.frame.midY)
        ).tap()
    }

    private func dismissKeyboard() {
        guard app.keyboards.firstMatch.exists else { return }

        let hideKeyboard = app.keyboards.buttons["Hide keyboard"]
        if hideKeyboard.exists {
            hideKeyboard.tap()
        } else {
            app.navigationBars.firstMatch.coordinate(
                withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)
            ).tap()
        }
    }

    private func waitForStablePromptAfterAssessment() {
        let prompt = app.descendants(matching: .any)["study.card.prompt"]
        let forget = app.descendants(matching: .any)["study.forget"]
        let remember = app.descendants(matching: .any)["study.remember"]
        let nextPrompt = XCTNSPredicateExpectation(
            predicate: NSPredicate { _, _ in
                prompt.exists && prompt.isHittable && !forget.exists && !remember.exists
            },
            object: nil
        )
        wait(for: [nextPrompt], timeout: 5)

        let animationSettled = expectation(description: "Next prompt animation settled")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            animationSettled.fulfill()
        }
        wait(for: [animationSettled], timeout: 1)

        XCTAssertTrue(prompt.exists && prompt.isHittable)
        XCTAssertFalse(forget.exists)
        XCTAssertFalse(remember.exists)
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
