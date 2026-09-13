import XCTest
import UIKit

@MainActor
final class CardFlipperFlowTests: XCTestCase {
    private lazy var app = XCUIApplication()

    func testHistoryBannerUsesReadableForegroundForDarkAccent() {
        launchHistory(arguments: [
            "-uiTestResume",
            "-com.danilarahmanov.CardFlipper.appearance.accentColor", "invalid",
            "-com.danilarahmanov.CardFlipper.appearance.accent", "berry",
            "-AppleInterfaceStyle", "Light",
        ])
        let banner = app.buttons["study.resume.banner"]
        XCTAssertTrue(banner.waitForExistence(timeout: 5))
        let whiteTextCoverage = pixelCoverage(
            in: banner.frame.insetBy(dx: 18, dy: 18),
            screenshot: app.screenshot().image
        ) { red, green, blue in
            red > 0.92 && green > 0.92 && blue > 0.92
        }
        XCTAssertGreaterThan(whiteTextCoverage, 0.02)
        snap("history-banner-dark-accent-contrast")
    }

    func testHistorySeedShowsNewestFirstAndCompleteDetails() {
        launchHistory(arguments: ["-uiTestHistory"])
        tap("library.history")
        let newest = historyRow(902)
        let older = historyRow(901)
        XCTAssertTrue(newest.waitForExistence(timeout: 5))
        XCTAssertTrue(older.exists)
        XCTAssertLessThan(newest.frame.minY, older.frame.minY)
        XCTAssertTrue(newest.label.contains("Writing"))
        XCTAssertTrue(newest.label.contains("2 of 3"))
        XCTAssertTrue(newest.label.contains("50%"))
        snap("history-newest-first")
        XCUIDevice.shared.press(.home)
        app.activate()
        XCTAssertTrue(newest.waitForExistence(timeout: 5))
        newest.tap()
        assertHistoryDetail("completedAt", contains: "2026")
        assertHistoryDetail("startedAt", contains: "2026")
        assertHistoryDetail("duration", contains: "61 seconds")
        assertHistoryDetail("mode", contains: "Writing")
        assertHistoryDetail("direction", contains: "Russian to English")
        assertHistoryDetail("progress", contains: "2 of 3")
        assertHistoryDetail("recall", contains: "50%")
        assertHistoryDetail("encountered", contains: "2")
        assertHistoryDetail("repeated", contains: "1")
        assertHistoryDetail("forgotten", contains: "2")
        assertHistoryDetail("assessments", contains: "4")
        assertHistoryDetail("tags", contains: "Основы")
        let difficult = app.staticTexts["history.difficult.book"]
        scrollToHittable(difficult)
        XCTAssertEqual(difficult.label, "book")
        snap("history-detail-metrics")
        app.navigationBars.buttons.firstMatch.tap()
        older.tap()
        assertHistoryDetail("duration", contains: "1 second")
        assertHistoryDetail("direction", contains: "English to Russian")
        assertHistoryDetail("tags", contains: "All Cards")
        XCTAssertFalse(app.staticTexts["history.difficult.book"].exists)
    }

    func testHistoryResumeSurvivesRelaunchAndCompletionAppearsInHistory() {
        launchHistory(arguments: ["-uiTestResume", "-uiTestHistory"])
        let banner = app.buttons["study.resume.banner"]
        XCTAssertTrue(banner.waitForExistence(timeout: 5))
        XCTAssertTrue(banner.label.contains("1 of 2"))
        XCTAssertFalse(app.alerts.firstMatch.exists)
        app.terminate()
        launchHistory(arguments: ["-uiTestSeed", "-uiTestHistory", "-uiTestPreserveStudySession"])
        XCTAssertTrue(banner.waitForExistence(timeout: 5))
        tap("library.history")
        XCTAssertTrue(historyRow(902).waitForExistence(timeout: 5))
        tap("study.resume.banner")
        let progress = app.descendants(matching: .any)["study.progress"].firstMatch
        XCTAssertTrue(progress.waitForExistence(timeout: 5))
        XCTAssertTrue(progress.label.contains("2"))
        rememberCurrentCard()
        assertExists("study.result")
        snap("history-resumed-natural-completion")
        tap("study.finish")
        XCTAssertTrue(app.buttons["library.history"].waitForExistence(timeout: 5))
        XCTAssertFalse(banner.exists)
        tap("library.history")
        XCTAssertTrue(historyRow(900).waitForExistence(timeout: 5))
        XCTAssertTrue(historyRow(900).label.contains("2 of 2"))
        XCTAssertFalse(banner.exists)
        XCTAssertEqual(app.buttons.matching(identifier: historyRow(900).identifier).count, 1)
        snap("history-refreshed-after-completion")
    }

    func testHistoryConflictCancelContinueAndStartNewPreserveConfiguredWriting() {
        launchHistory(arguments: ["-uiTestResume"])
        tap("library.study")
        tap("study.mode.writing")
        tap("study.start")
        assertConflictActions()
        app.alerts.buttons["Cancel"].tap()
        XCTAssertTrue(app.buttons["study.mode.writing"].isSelected)
        tap("study.start")
        app.alerts.buttons["Continue Saved Game"].tap()
        assertExists("study.card.prompt")
        XCTAssertFalse(app.textFields["study.writing.answer"].exists)
        saveAndExit()
        tap("library.study")
        tap("study.mode.writing")
        tap("study.start")
        assertConflictActions()
        snap("history-replacement-conflict")
        app.alerts.buttons["Start New Game"].tap()
        XCTAssertTrue(app.textFields["study.writing.answer"].waitForExistence(timeout: 5))
        app.textFields["study.writing.answer"].tap()
        app.textFields["study.writing.answer"].typeText("ca")
        saveAndExit()
        XCTAssertTrue(app.buttons["study.resume.banner"].label.contains("Writing"))
        tap("library.history")
        let old = historyRow(900)
        XCTAssertTrue(old.waitForExistence(timeout: 5))
        XCTAssertTrue(old.label.contains("1 of 2"))
        XCTAssertTrue(old.label.contains("100%"))
        XCTAssertFalse(old.label.localizedCaseInsensitiveContains("early"))
        old.tap()
        assertHistoryDetail("progress", contains: "1 of 2")
        assertHistoryDetail("mode", contains: "Flashcards")
        snap("history-replaced-partial-detail")
        app.terminate()
        launchHistory(arguments: ["-uiTestSeed", "-uiTestPreserveStudySession"])
        XCTAssertTrue(app.buttons["study.resume.banner"].label.contains("Writing"))
        tap("study.resume.banner")
        let restoredAnswer = app.textFields["study.writing.answer"]
        XCTAssertTrue(restoredAnswer.waitForExistence(timeout: 5))
        XCTAssertEqual(restoredAnswer.value as? String, "ca")
        snap("history-writing-answer-restored")
    }

    func testHistorySaveAndExitResumesRemainingCardOfTwoCardGame() {
        launch(seed: true)
        tap("library.bulk.select")
        let cards = app.buttons.matching(identifier: "library.card")
        tapTrailingEmptySpace(in: cards.element(boundBy: 0))
        tapTrailingEmptySpace(in: cards.element(boundBy: 1))
        tap("library.bulk.tags")
        tap("library.bulk.tag.00000000-0000-0000-0000-000000000101")
        tap("library.bulk.confirm")
        tap("library.study")
        tap("Повторение")
        tap("study.start")
        rememberCurrentCard()
        waitForStablePromptAfterAssessment()
        app.navigationBars.buttons["Close"].tap()
        snap("history-close-confirmation")
        XCTAssertTrue(app.buttons["Continue Game"].waitForExistence(timeout: 5), app.debugDescription)
        app.buttons["Continue Game"].tap()
        assertExists("study.card.prompt")
        saveAndExit()
        let banner = app.buttons["study.resume.banner"]
        XCTAssertTrue(banner.waitForExistence(timeout: 5))
        XCTAssertTrue(banner.label.contains("1 of 2"))
        snap("history-saved-two-card-game")
        banner.tap()
        rememberCurrentCard()
        assertExists("study.result")
        tap("study.finish")
        XCTAssertFalse(banner.exists)
        tap("library.history")
        let rows = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH 'history.row.'"))
        XCTAssertEqual(rows.count, 1)
        XCTAssertTrue(rows.firstMatch.label.contains("2 of 2"))
    }

    func testHistoryRussianLabelsAndEmptyState() {
        launchHistory(arguments: [], language: "ru")
        tap("library.history")
        XCTAssertTrue(app.staticTexts["Истории занятий пока нет"].waitForExistence(timeout: 5))
        snap("history-russian-empty")
        app.terminate()
        launchHistory(arguments: ["-uiTestHistory", "-uiTestResume"], language: "ru")
        XCTAssertTrue(app.buttons["study.resume.banner"].label.contains("1 из 2"))
        tap("library.history")
        historyRow(902).tap()
        assertHistoryDetail("mode", contains: "Письмо")
        assertHistoryDetail("duration", contains: "61 секунда")
        assertHistoryDetail("direction", contains: "С русского на английский")
        assertHistoryDetail("progress", contains: "2 из 3")
        assertHistoryDetail("recall", contains: "50% вспоминания")
        snap("history-russian-details")
    }

    private func launchHistory(arguments: [String], language: String = "en") {
        continueAfterFailure = false
        app.launchArguments = ["-uiTesting", "-AppleLanguages", "(\(language))",
                               "-AppleLocale", language == "ru" ? "ru_RU" : "en_US"] + arguments
        app.launch()
        assertExists("library.root")
    }

    private func historyRow(_ suffix: Int) -> XCUIElement {
        app.buttons[String(format: "history.row.00000000-0000-0000-0000-%012d", suffix)]
    }

    private func assertHistoryDetail(_ field: String, contains value: String) {
        let metric = app.descendants(matching: .any)["history.detail.\(field)"].firstMatch
        scrollToHittable(metric)
        XCTAssertTrue(metric.label.contains(value), "Expected \(value) in \(metric.label)")
    }

    private func assertConflictActions() {
        for action in ["Continue Saved Game", "Start New Game", "Cancel"] {
            XCTAssertTrue(app.alerts.buttons[action].waitForExistence(timeout: 5))
        }
    }

    private func saveAndExit() {
        app.navigationBars.buttons["Close"].tap()
        let save = app.buttons["Save and Exit"]
        XCTAssertTrue(save.waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["Continue Game"].exists)
        save.tap()
        XCTAssertTrue(app.buttons["library.study"].waitForExistence(timeout: 5))
    }

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

    func testSettingsExplainHowToCreateAnImportFileWithAI() throws {
        launch(seed: false)
        tap("library.settings")

        tap("settings.cards.aiHelp")

        XCTAssertTrue(app.navigationBars["Create Import File"].waitForExistence(timeout: 3))
        XCTAssertTrue(app.staticTexts["settings.cards.aiHelp.prompt"].exists)

        let copyButton = app.buttons["settings.cards.aiHelp.copy"]
        XCTAssertTrue(copyButton.isHittable)
        copyButton.tap()
        XCTAssertEqual(copyButton.label, "Prompt Copied")
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

    func testPartOfSpeechPickerStaysOpenAfterSelection() {
        launch(seed: false)
        tap("library.add")
        assertExists("editor.root")

        let details = app.buttons["editor.english.0.details"]
        XCTAssertTrue(details.waitForExistence(timeout: 3))
        details.tap()

        let picker = app.buttons["editor.english.0.partOfSpeechPicker"]
        scrollToHittable(picker)
        picker.tap()

        let noun = app.buttons["editor.english.0.partOfSpeech.noun"]
        XCTAssertTrue(noun.waitForExistence(timeout: 3))
        noun.tap()

        XCTAssertTrue(app.searchFields["Search parts of speech"].waitForExistence(timeout: 3))
        XCTAssertTrue(noun.exists)
        XCTAssertTrue(noun.isSelected)
    }

    func testPartOfSpeechPickerUsesCompactRows() {
        launch(seed: false)
        tap("library.add")
        assertExists("editor.root")

        let details = app.buttons["editor.english.0.details"]
        XCTAssertTrue(details.waitForExistence(timeout: 3))
        details.tap()

        let picker = app.buttons["editor.english.0.partOfSpeechPicker"]
        scrollToHittable(picker)
        picker.tap()

        let noun = app.buttons["editor.english.0.partOfSpeech.noun"]
        XCTAssertTrue(noun.waitForExistence(timeout: 3))
        XCTAssertLessThanOrEqual(noun.frame.height, 46)
    }

    func testEditorUsesCompactToolbarActionsAndDisablesExampleUntilPartIsSelected() {
        launch(seed: false)
        tap("library.add")
        assertExists("editor.root")

        let cancel = app.buttons["editor.cancel"]
        let save = app.buttons["editor.save"]
        XCTAssertTrue(cancel.waitForExistence(timeout: 3))
        XCTAssertTrue(save.waitForExistence(timeout: 3))
        XCTAssertEqual(cancel.label, "Cancel")
        XCTAssertEqual(save.label, "Save")
        XCTAssertLessThan(abs(cancel.frame.width - cancel.frame.height), 8)
        XCTAssertLessThan(abs(save.frame.width - save.frame.height), 8)

        let details = app.buttons["editor.english.0.details"]
        XCTAssertTrue(details.waitForExistence(timeout: 3))
        details.tap()

        let addExample = app.buttons["editor.english.0.example.add"]
        scrollToHittable(addExample)
        XCTAssertFalse(addExample.isEnabled)
        snap("editor-disabled-add-example")
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

    func testLearnedIconAppearsOnlyForLearnedCardsAndCanBeUndone() {
        launch(seed: true)

        let firstCard = app.buttons.matching(identifier: "library.card").firstMatch
        let learnedIcon = app.descendants(matching: .any)["library.card.learningStatus"]
        XCTAssertTrue(firstCard.waitForExistence(timeout: 5))
        XCTAssertEqual(firstCard.value as? String, "Unlearned")
        XCTAssertFalse(learnedIcon.exists)

        firstCard.swipeRight()
        tap("library.markLearned")

        XCTAssertTrue(app.descendants(matching: .any)["library.undoBanner"].waitForExistence(timeout: 3))
        XCTAssertEqual(firstCard.value as? String, "Learned")
        XCTAssertTrue(learnedIcon.waitForExistence(timeout: 3))
        tap("library.undo")

        XCTAssertTrue(firstCard.waitForExistence(timeout: 3))
        XCTAssertEqual(firstCard.value as? String, "Unlearned")
        XCTAssertFalse(learnedIcon.exists)
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

    func testStudySetupUsesCompactTagRows() {
        launch(seed: true)

        tap("library.study")
        let tag = app.buttons["Основы"]
        XCTAssertTrue(tag.waitForExistence(timeout: 3))
        XCTAssertLessThan(tag.frame.height, 60)
    }

    func testStudyProgressIsPinnedOutsideScrollableContent() {
        launch(seed: true)

        tap("library.study")
        tap("study.start")

        let progress = app.descendants(matching: .any)["study.progress"]
        XCTAssertTrue(progress.waitForExistence(timeout: 3))
        XCTAssertFalse(app.scrollViews.descendants(matching: .any)["study.progress"].exists)
    }

    func testStudyLanguageLabelStaysAtCardBottomOnBothFaces() {
        launch(seed: true)

        tap("library.study")
        tap("study.direction.englishToRussian")
        tap("study.start")

        let prompt = app.descendants(matching: .any)["study.card.prompt"]
        let englishLabel = app.staticTexts["English"]
        XCTAssertTrue(prompt.waitForExistence(timeout: 3))
        XCTAssertTrue(englishLabel.waitForExistence(timeout: 3))
        XCTAssertLessThan(prompt.frame.maxY - englishLabel.frame.maxY, 12)

        tapEmptyCardSpace("study.card.prompt")

        let answer = app.descendants(matching: .any)["study.card.answer"]
        let russianLabel = app.staticTexts["Russian"]
        XCTAssertTrue(answer.waitForExistence(timeout: 3))
        XCTAssertTrue(russianLabel.waitForExistence(timeout: 3))
        XCTAssertLessThan(answer.frame.maxY - russianLabel.frame.maxY, 12)
    }

    func testLibraryFilterToolbarUsesCompactDoneAndKeepsTextReset() {
        launch(seed: true)
        tap("library.filters")

        let reset = app.buttons["library.filters.reset"]
        let done = app.buttons["library.filters.done"]
        XCTAssertTrue(reset.waitForExistence(timeout: 3))
        XCTAssertTrue(done.waitForExistence(timeout: 3))
        XCTAssertEqual(reset.label, "Reset")
        XCTAssertEqual(done.label, "Done")
        XCTAssertGreaterThan(reset.frame.width, reset.frame.height)
        XCTAssertLessThan(abs(done.frame.width - done.frame.height), 8)
    }

    func testSelectedFilterTagUsesConfiguredAccentColor() {
        launch(seed: true, accent: "berry")
        tap("library.filters")

        let tag = app.buttons["Основы"]
        XCTAssertTrue(tag.waitForExistence(timeout: 3))
        tag.tap()

        let screenshot = app.screenshot().image
        let accentCoverage = colorCoverage(
            in: tag.frame,
            screenshot: screenshot,
            matching: (red: 0xAD / 255, green: 0, blue: 0x4A / 255)
        )
        let blueCoverage = blueDominantCoverage(
            in: tag.frame,
            screenshot: screenshot
        )
        XCTAssertGreaterThan(accentCoverage, 0.005)
        XCTAssertLessThan(blueCoverage, 0.001)
    }

    func testActiveLibraryFilterButtonMatchesStudyButtonFilledStyle() {
        launch(seed: true, accent: "berry")
        tap("library.filters")
        tap("Основы")
        tap("library.filters.done")

        let filters = app.buttons["library.filters"].firstMatch
        XCTAssertTrue(filters.waitForExistence(timeout: 3))
        let accentCoverage = colorCoverage(
            in: filters.frame,
            screenshot: app.screenshot().image,
            matching: (red: 0xAD / 255, green: 0, blue: 0x4A / 255)
        )
        XCTAssertGreaterThan(accentCoverage, 0.8)
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
        XCTAssertFalse(app.scrollViews["study.card.prompt"].exists)
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

    func testWritingModeRetriesChecksRevealsDetailsAndAssessesExplicitly() throws {
        launch(seed: true)
        tap("library.study")
        tap("study.mode.writing")
        XCTAssertFalse(app.buttons["study.direction.englishToRussian"].exists)
        XCTAssertFalse(app.staticTexts["Direction"].exists)
        tap("study.start")

        let field = app.textFields["study.writing.answer"]
        XCTAssertTrue(field.waitForExistence(timeout: 3))
        let writingCard = app.otherElements["study.writing.card"]
        XCTAssertTrue(writingCard.waitForExistence(timeout: 3))
        XCTAssertGreaterThan(field.frame.minY, writingCard.frame.maxY)
        let checkButton = app.buttons["study.writing.check"]
        XCTAssertTrue(checkButton.waitForExistence(timeout: 3))
        XCTAssertGreaterThanOrEqual(checkButton.frame.width, 44)
        XCTAssertFalse(app.buttons["study.writing.showAnswer"].exists)
        XCTAssertFalse(app.buttons["study.writing.hideAnswer"].exists)

        let answer: String
        if writingCard.buttons["книга"].exists {
            answer = " BOOK "
        } else if writingCard.buttons["кот"].exists {
            answer = " CAT "
        } else {
            XCTAssertTrue(writingCard.buttons["дом"].exists)
            answer = " HOME "
        }

        field.tap()
        field.typeText("wrong")
        tap("study.writing.check")
        XCTAssertFalse(app.staticTexts["Try again"].exists)
        XCTAssertFalse(app.staticTexts["Correct"].exists)
        XCTAssertTrue(field.isEnabled)
        XCTAssertFalse(app.buttons["study.writing.next"].exists)
        XCTAssertFalse(app.buttons["study.remember"].exists)
        XCTAssertFalse(app.buttons["study.forget"].exists)

        tapEmptyCardSpace("study.writing.card")
        assertExists("study.writing.speak")
        XCTAssertTrue(field.isEnabled)
        XCTAssertTrue(app.keyboards.firstMatch.exists)

        for _ in "wrong" {
            field.typeText(XCUIKeyboardKey.delete.rawValue)
        }
        field.typeText(answer)
        XCTAssertEqual(
            (field.value as? String)?.trimmingCharacters(in: .whitespacesAndNewlines),
            answer.trimmingCharacters(in: .whitespacesAndNewlines)
        )
        tap("study.writing.check")
        XCTAssertFalse(app.staticTexts["Correct"].exists)
        assertExists("study.remember")
        assertExists("study.forget")
        XCTAssertFalse(app.buttons["study.writing.next"].exists)

        tap("study.forget")
        assertExists("study.writing.answer")
        XCTAssertTrue(field.isEnabled)
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

    private func launch(seed: Bool, accent: String? = nil) {
        continueAfterFailure = false
        app.launchArguments = [
            "-uiTesting",
            "-AppleLanguages", "(en)",
            "-AppleLocale", "en_US",
        ]
        if seed {
            app.launchArguments.append("-uiTestSeed")
        }
        if let accent {
            app.launchArguments += [
                "-com.danilarahmanov.CardFlipper.appearance.accentColor", "invalid",
                "-com.danilarahmanov.CardFlipper.appearance.accent", accent,
            ]
        }
        app.launch()
        assertExists("library.root")
    }

    private func colorCoverage(
        in frame: CGRect,
        screenshot: UIImage,
        matching expected: (red: CGFloat, green: CGFloat, blue: CGFloat)
    ) -> Double {
        pixelCoverage(in: frame, screenshot: screenshot) { red, green, blue in
            let distance = abs(red - expected.red) + abs(green - expected.green)
                + abs(blue - expected.blue)
            return distance < 0.24
        }
    }

    private func blueDominantCoverage(in frame: CGRect, screenshot: UIImage) -> Double {
        pixelCoverage(in: frame, screenshot: screenshot) { red, green, blue in
            blue > 0.5 && blue > red * 1.3 && blue > green * 1.1
        }
    }

    private func pixelCoverage(
        in frame: CGRect,
        screenshot: UIImage,
        matching predicate: (CGFloat, CGFloat, CGFloat) -> Bool
    ) -> Double {
        guard let image = screenshot.cgImage else { return 0 }
        let scaleX = CGFloat(image.width) / screenshot.size.width
        let scaleY = CGFloat(image.height) / screenshot.size.height
        let pixelRect = CGRect(
            x: frame.minX * scaleX,
            y: frame.minY * scaleY,
            width: frame.width * scaleX,
            height: frame.height * scaleY
        ).integral.intersection(CGRect(x: 0, y: 0, width: image.width, height: image.height))
        guard !pixelRect.isEmpty,
              let cropped = image.cropping(to: pixelRect)
        else { return 0 }

        let pixelCount = cropped.width * cropped.height
        let bytesPerPixel = 4
        let bytesPerRow = cropped.width * bytesPerPixel
        var bytes = [UInt8](repeating: 0, count: pixelCount * bytesPerPixel)
        guard let context = CGContext(
            data: &bytes,
            width: cropped.width,
            height: cropped.height,
            bitsPerComponent: 8,
            bytesPerRow: bytesPerRow,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else { return 0 }
        context.draw(cropped, in: CGRect(x: 0, y: 0, width: cropped.width, height: cropped.height))

        var matchingPixels = 0
        for y in 0 ..< cropped.height {
            for x in 0 ..< cropped.width {
                let offset = y * bytesPerRow + x * bytesPerPixel
                if predicate(
                    CGFloat(bytes[offset]) / 255,
                    CGFloat(bytes[offset + 1]) / 255,
                    CGFloat(bytes[offset + 2]) / 255
                ) {
                    matchingPixels += 1
                }
            }
        }
        return Double(matchingPixels) / Double(pixelCount)
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
