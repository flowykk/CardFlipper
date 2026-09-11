import XCTest

@MainActor
final class CardFlipperFlowTests: XCTestCase {
    private lazy var app = XCUIApplication()

    func testAppIconNamesAreLocalizedInRussian() {
        continueAfterFailure = false
        app.launchArguments = ["-uiTesting", "-AppleLanguages", "(ru)", "-AppleLocale", "ru_RU"]
        app.launch()
        tap("library.settings")
        let titles = ["default": "Океан", "IconViolet3D": "Ирис", "IconOrange3D": "Коралл", "IconMint3D": "Мята", "IconMidnight3D": "Ночь", "IconOrigami": "Оригами", "IconPixel": "Пиксель", "IconOwl": "Сова", "IconMonogram": "Буквы", "IconOrbit": "Орбита"]
        snap("app-icons-russian-top")
        for name in ["default", "IconViolet3D", "IconOrange3D", "IconMint3D", "IconMidnight3D", "IconOrigami", "IconPixel", "IconOwl", "IconMonogram", "IconOrbit"] {
            let title = titles[name]
            let button = app.buttons["settings.icon.\(name)"]
            XCTAssertTrue(button.waitForExistence(timeout: 5))
            scrollIconToHittable(button)
            XCTAssertEqual(button.label, title)
        }
        snap("app-icons-russian")
    }

    func testAllTenAppIconsCanBeSelectedAndRestoredAfterRelaunch() throws {
        launch(seed: false)
        tap("library.settings")
        let names = ["IconViolet3D", "IconOrange3D", "IconMint3D", "IconMidnight3D", "IconOrigami", "IconPixel", "IconOwl", "IconMonogram", "IconOrbit", "default"]
        let titles = ["IconViolet3D": "Iris", "IconOrange3D": "Coral", "IconMint3D": "Mint", "IconMidnight3D": "Night", "IconOrigami": "Origami", "IconPixel": "Pixel", "IconOwl": "Owl", "IconMonogram": "Type", "IconOrbit": "Orbit", "default": "Ocean"]
        let springboard = XCUIApplication(bundleIdentifier: "com.apple.springboard")
        for name in names {
            let button = app.buttons["settings.icon.\(name)"]
            XCTAssertTrue(button.waitForExistence(timeout: 5))
            XCTAssertEqual(button.label, titles[name])
            scrollIconToHittable(button)
            button.tap()
            if springboard.alerts.firstMatch.waitForExistence(timeout: 2) {
                springboard.alerts.firstMatch.buttons.firstMatch.tap()
            }
            if app.alerts.firstMatch.exists {
                if app.alerts["Couldn’t Change Icon"].exists {
                    throw XCTSkip("Alternate app icons are unavailable in this simulator runtime")
                }
                app.alerts.firstMatch.buttons.firstMatch.tap()
            }
            let selected = NSPredicate(format: "isSelected == true")
            expectation(for: selected, evaluatedWith: button)
            waitForExpectations(timeout: 10)
            snap("app-icon-\(name)")
            if name == "IconMidnight3D" {
                app.terminate()
                app.launch()
                tap("library.settings")
                XCTAssertTrue(app.buttons["settings.icon.IconMidnight3D"].isSelected)
            }
        }
    }

    func testSettingsExposeCustomAccentColorPicker() throws {
        launch(seed: false)

        tap("library.settings")

        let colorPicker = app.descendants(matching: .any)["settings.colorPicker"]
        XCTAssertTrue(colorPicker.waitForExistence(timeout: 3))
        XCTAssertTrue(colorPicker.isHittable)
        XCTAssertTrue(app.navigationBars["Settings"].exists)
        snap("settings-custom-accent-picker")
    }

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

    func testDirtyEditorRequiresExplicitDiscard() throws {
        launch(seed: false)
        tap("library.add")
        assertExists("editor.root")

        let russianField = app.textFields["editor.russian.0"]
        XCTAssertTrue(russianField.waitForExistence(timeout: 3))
        russianField.tap()
        russianField.typeText("слово")
        app.navigationBars.buttons["Cancel"].tap()

        XCTAssertTrue(app.staticTexts["Discard Changes?"].waitForExistence(timeout: 3))
        app.buttons["Continue Editing"].tap()
        assertExists("editor.root")

        app.navigationBars.buttons["Cancel"].tap()
        app.buttons["Discard Changes"].tap()
        XCTAssertTrue(app.staticTexts["Your Library Is Empty"].waitForExistence(timeout: 5))
    }

    func testEditorDetailsExpandAndCollapse() {
        launch(seed: false)
        tap("library.add")
        assertExists("editor.root")

        let details = app.buttons["editor.english.0.details"]
        XCTAssertTrue(details.waitForExistence(timeout: 3))
        details.tap()

        let ipa = app.textFields["editor.ipa.0"]
        XCTAssertTrue(ipa.waitForExistence(timeout: 3))
        details.tap()

        let detailsCollapsed = XCTNSPredicateExpectation(
            predicate: NSPredicate(format: "exists == false"),
            object: ipa
        )
        wait(for: [detailsCollapsed], timeout: 3)
    }

    func testLibraryExposesLabeledPrimaryActionsAndHidesEmptySearch() {
        launch(seed: false)

        XCTAssertFalse(app.searchFields["Search Cards"].exists)
        XCTAssertTrue(app.buttons["Add Card"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.descendants(matching: .any)["library.study"].exists)

        app.terminate()
        launch(seed: true)

        let study = app.buttons["library.study"].firstMatch
        XCTAssertTrue(study.waitForExistence(timeout: 3))
        XCTAssertTrue(study.label.contains("Study Today"))
        XCTAssertTrue(study.label.contains("3"))
        XCTAssertTrue(study.isHittable)
        let add = app.navigationBars.buttons["library.add"]
        XCTAssertTrue(add.isHittable)

        let search = app.searchFields["Search cards"]
        XCTAssertTrue(search.waitForExistence(timeout: 3))
        let filters = app.buttons["library.filters"].firstMatch
        XCTAssertTrue(filters.isHittable)
        XCTAssertGreaterThan(filters.frame.minX, search.frame.maxX)
        XCTAssertGreaterThan(study.frame.minX, filters.frame.maxX)
        XCTAssertLessThan(study.frame.minY, search.frame.maxY)
        XCTAssertGreaterThan(study.frame.maxY, search.frame.minY)
        snap("library-primary-actions")
    }

    func testEmptyLibraryOffersAddAndImportAsVisibleActions() {
        launch(seed: false)

        let add = app.descendants(matching: .any)["library.add"]
        let importCards = app.descendants(matching: .any)["library.import"]
        XCTAssertTrue(add.waitForExistence(timeout: 3))
        XCTAssertTrue(importCards.waitForExistence(timeout: 3))
        XCTAssertTrue(add.isHittable)
        XCTAssertTrue(importCards.isHittable)
        XCTAssertEqual(importCards.label, "Import Cards")
        snap("library-empty-actions")
    }

    func testTagManagementShowsLifecycleActionsAndAffectedCardCount() {
        launch(seed: true)

        tap("library.filters")
        tap("library.tags.manage")
        XCTAssertTrue(app.navigationBars["Manage Tags"].waitForExistence(timeout: 3))
        assertExists("tag.create.name")
        assertExists("tag.create")

        let basics = app.buttons["tag.manage.00000000-0000-0000-0000-000000000100"]
        XCTAssertTrue(basics.waitForExistence(timeout: 3))
        XCTAssertTrue(basics.label.contains("Основы"))
        XCTAssertTrue(basics.label.contains("3 cards"))
        basics.tap()

        assertExists("tag.rename.name")
        XCTAssertFalse(app.buttons["Rename Tag"].exists)
        assertExists("tag.rename.save")
        XCTAssertTrue(app.buttons["Merge Tag"].exists)
        XCTAssertTrue(app.buttons["Delete Tag"].exists)
        snap("tag-management-detail")
    }

    func testStatisticsZeroStateExplainsWhatWillAppearAndStartsStudy() {
        launch(seed: true)

        tap("library.statistics")
        assertExists("statistics.zeroState")
        XCTAssertTrue(app.staticTexts["No Study History Yet"].exists)
        XCTAssertTrue(app.staticTexts.matching(
            NSPredicate(format: "label CONTAINS %@", "streak")
        ).firstMatch.exists)

        let start = app.buttons["Start Studying"]
        XCTAssertTrue(start.waitForExistence(timeout: 3))
        XCTAssertTrue(start.isHittable)
        start.tap()
        assertExists("study.setup")
        snap("statistics-zero-state")
    }

    func testLearningStatusIsVisibleAndCanBeUndone() {
        launch(seed: true)

        let firstCard = app.buttons.matching(identifier: "library.card").firstMatch
        XCTAssertTrue(firstCard.waitForExistence(timeout: 5))
        XCTAssertTrue(firstCard.label.contains("Unlearned"))

        firstCard.swipeRight()
        tap("library.markLearned")

        XCTAssertTrue(app.descendants(matching: .any)["library.undoBanner"].waitForExistence(timeout: 3))
        XCTAssertTrue(firstCard.label.contains("Learned"))
        tap("library.undo")

        XCTAssertTrue(firstCard.waitForExistence(timeout: 3))
        XCTAssertTrue(firstCard.label.contains("Unlearned"))
        XCTAssertFalse(app.descendants(matching: .any)["library.undoBanner"].exists)
        snap("library-visible-learning-status")
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
        let addExample = app.buttons["Add Example"].firstMatch
        scrollToHittable(addExample)
        XCTAssertTrue(addExample.isEnabled)
        addExample.tap()
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

    func testLibraryHidesTranslationsUntilToggleIsEnabled() throws {
        launch(seed: true)

        let firstCard = app.buttons.matching(identifier: "library.card").firstMatch
        XCTAssertTrue(firstCard.waitForExistence(timeout: 5))
        XCTAssertTrue(firstCard.staticTexts["book"].exists)
        XCTAssertFalse(firstCard.staticTexts["книга"].exists)

        tap("library.filters")
        let translationsToggle = app.switches["library.translations.toggle"]
        XCTAssertTrue(translationsToggle.waitForExistence(timeout: 3))
        translationsToggle.coordinate(
            withNormalizedOffset: CGVector(dx: 0.9, dy: 0.5)
        ).tap()
        tap("library.filters.done")

        XCTAssertTrue(firstCard.staticTexts["book"].waitForExistence(timeout: 3))
        XCTAssertTrue(firstCard.staticTexts["книга"].waitForExistence(timeout: 3))
    }

    func testLearningFiltersAreAvailableInLibraryAndStudySetup() throws {
        launch(seed: true)

        XCTAssertFalse(app.descendants(matching: .any)["library.learningFilter"].exists)
        XCTAssertFalse(app.descendants(matching: .any)["library.tags.manage"].exists)
        tap("library.filters")
        assertExists("library.filters.sheet")
        assertExists("library.learningFilter")
        assertExists("library.translations.toggle")
        assertExists("library.tags.manage")
        snap("library-filters-sheet")
        tap("library.filters.done")

        tap("library.study")
        assertExists("study.setup")
        assertExists("study.learningFilter")
    }

    func testLibraryFilterSheetShowsTagsBelowLearningStatus() throws {
        launch(seed: true)

        tap("library.filters")
        let tag = app.buttons["Основы"]
        let filter = app.segmentedControls["library.learningFilter"]
        XCTAssertTrue(tag.waitForExistence(timeout: 5))
        XCTAssertTrue(filter.waitForExistence(timeout: 5))
        XCTAssertGreaterThan(tag.frame.minY, filter.frame.maxY)
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
        XCTAssertEqual(app.buttons.matching(identifier: "library.card").count, 3)
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

    func testBulkTagAssignmentSelectsCardsAndCompletes() throws {
        launch(seed: true)
        tap("library.bulk.select")
        assertExists("library.bulk.bar")
        XCTAssertTrue(app.navigationBars.buttons["library.bulk.cancel"].waitForExistence(timeout: 3))

        let cards = app.buttons.matching(identifier: "library.card")
        XCTAssertGreaterThanOrEqual(cards.count, 2)
        tapTrailingEmptySpace(in: cards.element(boundBy: 0))
        tapTrailingEmptySpace(in: cards.element(boundBy: 1))
        tap("library.bulk.tags")

        let tag = app.buttons["library.bulk.tag.00000000-0000-0000-0000-000000000101"]
        XCTAssertTrue(tag.waitForExistence(timeout: 3))
        XCTAssertTrue(tag.isHittable)
        tag.tap()
        expectation(for: NSPredicate(format: "isSelected == true"), evaluatedWith: tag)
        waitForExpectations(timeout: 3)

        let confirm = app.buttons["library.bulk.confirm"]
        XCTAssertTrue(confirm.waitForExistence(timeout: 3))
        XCTAssertTrue(confirm.isHittable)
        confirm.tap()
        let selectionBar = app.descendants(matching: .any)["library.bulk.bar"]
        let selectionBarDismissed = XCTNSPredicateExpectation(
            predicate: NSPredicate(format: "exists == false"),
            object: selectionBar
        )
        wait(for: [selectionBarDismissed], timeout: 3)
        XCTAssertTrue(cards.element(boundBy: 0).label.contains("Повторение"))
        XCTAssertTrue(cards.element(boundBy: 1).label.contains("Повторение"))
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

    func testF5CreatedTagIsReusableInAnotherCard() throws {
        launch(seed: false)

        tap("library.add")
        fillRequiredFields(russian: "первый", english: "first")

        let newTag = app.textFields["editor.tag.new"]
        scrollToHittable(newTag)
        newTag.tap()
        newTag.typeText("Reusable")
        dismissKeyboard()
        assertExists("editor.tag.chip.Reusable")

        app.navigationBars.buttons["Save"].tap()
        waitForCardCount(1)

        tap("library.add")
        fillRequiredFields(russian: "второй", english: "second")
        tap("editor.tag.chip.Reusable")
        app.navigationBars.buttons["Save"].tap()
        waitForCardCount(2)

        let cards = app.buttons.matching(identifier: "library.card")
        XCTAssertTrue(cards.element(boundBy: 0).staticTexts["Reusable"].exists)
        XCTAssertTrue(cards.element(boundBy: 1).staticTexts["Reusable"].exists)
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

    private func fillRequiredFields(russian: String, english: String) {
        let russianField = app.textFields["editor.russian.0"]
        scrollToHittable(russianField)
        russianField.tap()
        russianField.typeText(russian)

        let englishField = app.textFields["editor.english.0"]
        scrollToHittable(englishField)
        englishField.tap()
        englishField.typeText(english)
        dismissKeyboard()
    }

    private func waitForCardCount(_ count: Int) {
        let expectedCount = XCTNSPredicateExpectation(
            predicate: NSPredicate { _, _ in
                self.app.buttons.matching(identifier: "library.card").count == count
            },
            object: nil
        )
        wait(for: [expectedCount], timeout: 5)
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
        let keyboard = app.keyboards.firstMatch
        guard keyboard.exists else { return }

        let returnKey = keyboard.buttons["Return"]
        let hideKeyboard = keyboard.buttons["Hide keyboard"]
        if returnKey.isHittable {
            returnKey.tap()
        } else if hideKeyboard.isHittable {
            hideKeyboard.tap()
        } else {
            XCTFail("Expected a hittable keyboard dismissal control")
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
        let element = app.buttons[identifier].firstMatch
        scrollToHittable(element)
        element.tap()
    }

    private func assertExists(_ identifier: String) {
        XCTAssertTrue(
            app.descendants(matching: .any)[identifier].waitForExistence(timeout: 5),
            "Expected accessibility identifier \(identifier)"
        )
    }

    private func scrollIconToHittable(_ element: XCUIElement) {
        let picker = app.scrollViews["settings.iconPicker"]
        scrollToHittable(picker)
        for _ in 0..<10 {
            if element.exists, element.isHittable { return }
            dragIconPickerLeft(picker)
        }
        XCTAssertTrue(element.exists, "Expected \(element)")
        XCTAssertTrue(element.isHittable, "Expected horizontally reachable \(element)")
    }

    private func dragIconPickerLeft(_ picker: XCUIElement) {
        let start = picker.coordinate(withNormalizedOffset: CGVector(dx: 0.85, dy: 0.5))
        let end = picker.coordinate(withNormalizedOffset: CGVector(dx: 0.15, dy: 0.5))
        start.press(forDuration: 0.05, thenDragTo: end)
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
