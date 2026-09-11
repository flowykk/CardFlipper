# CardFlipper UX Remediation Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Устранить найденные UX/UI-дефекты CardFlipper, сохранив local-first архитектуру и разбив работу на независимо проверяемые изменения.

**Architecture:** Сначала устраняются риски потери данных и неидемпотентные операции. Затем вводятся reusable adaptive UI-примитивы и на них переводятся home, editor, study и settings. Продуктовые улучшения statistics/result/session restoration выполняются после стабилизации базового сценария.

**Tech Stack:** Swift 6, SwiftUI, Observation, SwiftData, Swift Testing, XCTest UI Testing, ActivityKit, Tuist 4.40.0, iOS 18+.

**Spec:** `.impeccable/critique/2026-09-11T06-37-31Z__sources.md`

## Global Constraints

- Deployment target остаётся iOS 18.0.
- Новые сторонние зависимости не добавляются.
- Данные карточек, статистики и незавершённой сессии остаются локальными.
- Английская и русская локализации изменяются одновременно.
- Интерактивная область каждого control — минимум 44×44 pt.
- Все новые layouts проверяются на iPhone 16e и iPhone 17 Pro, light/dark, стандартном размере и Accessibility XXXL.
- Reduce Motion, VoiceOver и Increase Contrast не должны терять функциональность.
- Каждый task выполняется отдельным изменением; следующий task не используется для маскировки незавершённых acceptance criteria предыдущего.

---

## Порядок и зависимости

| № | Приоритет | Изменение | Зависимость |
|---:|:---:|---|---|
| 1 | P1 | Сохранение `isLearned` при bulk/tag updates | — |
| 2 | P1 | Fail-safe export и точный import/export outcome | — |
| 3 | P1 | Защита editor draft и идемпотентный save | — |
| 4 | P1 | Adaptive UI test matrix и reusable layout policy | — |
| 5 | P1 | Исправление timer/assessment на MAX Dynamic Type | 4 |
| 6 | P1 | Новый home hierarchy и семантика toolbar | 4 |
| 7 | P1 | Видимый Learned-state и Undo | 1, 6 |
| 8 | P2 | Progressive-disclosure editor и adaptive input rows | 3, 4 |
| 9 | P2 | Безопасный dictionary lookup и manual IPA ownership | 3, 8 |
| 10 | P2 | Корректная flip-анимация и accessibility semantics | 4 |
| 11 | P2 | Полезный Study Result | 10 |
| 12 | P2 | Восстановление незавершённой study session | 3, 10 |
| 13 | P2 | Empty state, import entry point и полноценные tags | 2, 6, 7 |
| 14 | P2 | Statistics: trends, legend и zero state | 4, 11 |
| 15 | P2 | Accessible accent palette и adaptive app-icon picker | 4 |
| 16 | P3 | Финальная унификация copy/icons/motion и regression pass | 1–15 |

---

### Task 1: Не терять `isLearned` при bulk/tag updates

**Результат:** любое изменение tags сохраняет `id`, meanings, variants, dates и `isLearned` без ручного дублирования всех полей.

**Files:**
- Modify: `Sources/Core/Models/VocabularyCard.swift`
- Modify: `Sources/LibraryFeature/LibraryViewModel.swift:175-215`
- Test: `Tests/CoreTests/CardDraftTests.swift` или новый `Tests/CoreTests/VocabularyCardTests.swift`
- Test: `Tests/LibraryFeatureTests/LibraryViewModelTests.swift:297`

**Interface:**

```swift
public func updating(
    tags: [Tag]? = nil,
    isLearned: Bool? = nil,
    updatedAt: Date? = nil
) -> VocabularyCard
```

Метод обязан сохранять все значения, для которых аргумент равен `nil`.

- [x] Добавить failing test `bulkTagAssignmentPreservesLearnedStateAndDates` с learned-карточкой и новым тегом.
- [x] Добавить model-level tests для каждого optional override и сохранения остальных полей.
- [x] Реализовать единый value-preserving update API в Core.
- [x] Перевести `addingTags`, `removingTag` и `updatingLearningStatus` на новый API; локальные конструкторы удалить.
- [x] Запустить `LibraryFeatureTests`, `CoreTests`, `DataTests`.

**Acceptance:** learned-карточка после bulk tagging остаётся learned; `createdAt` не меняется; `updatedAt` меняется только там, где это явно требуется; старые tags не пропадают; дублей tags нет.

**Commit:** `fix: preserve card state during tag updates`

---

### Task 2: Fail-safe export и точный import/export outcome

**Результат:** ошибка чтения никогда не создаёт пустой backup, а пользователь всегда знает итог transfer-операции.

**Files:**
- Create: `Sources/CardFlipperApp/CardTransferCoordinator.swift`
- Modify: `Sources/CardFlipperApp/RootView.swift:156-205,405-446`
- Modify: `Resources/CardFlipperApp/Localizable.xcstrings`
- Test: `Tests/CardFlipperAppTests/AppCompositionTests.swift`
- UI Test: `Tests/CardFlipperUITests/CardFlipperFlowTests.swift`

**Interfaces:**

```swift
enum CardExportState: Equatable {
    case idle
    case preparing
    case ready(CardTransferFileDocument, cardCount: Int)
    case failed
    case completed(cardCount: Int)
}

struct CardImportSummary: Equatable {
    let added: Int
    let merged: Int
    let skipped: Int
}
```

- [x] Написать failing test: fetch error пробрасывается и document не создаётся.
- [x] Написать failing test: success содержит точный `cardCount`.
- [x] Вынести подготовку document из `RootViewModel` в `CardTransferCoordinator`.
- [x] Показывать progress во время подготовки и блокировать повторный запуск.
- [x] Обработать `fileExporter` completion: success, cancellation и failure различаются.
- [x] Исправить import message: показывать точные Added/Merged и не терять числа в localization catalog.
- [x] Покрыть fail-safe orchestration AppComposition tests; системный file exporter оставить UI-owned и не автоматизировать через нестабильный document picker.

**Acceptance:** exporter не появляется при fetch error; пустая библиотека экспортирует корректный осознанный `0 cards` только после успешного fetch; пользователь видит success/failure; import сообщает reconciliation summary.

**Commit:** `fix: make card transfer outcomes trustworthy`

---

### Task 3: Защита editor draft и идемпотентный save

**Результат:** случайный Cancel/swipe не уничтожает ввод; повторный tap Save не создаёт дубль.

**Files:**
- Modify: `Sources/CardEditorFeature/CardEditorViewModel.swift`
- Modify: `Sources/CardEditorFeature/CardEditorView.swift`
- Modify: `Sources/CardFlipperApp/RootView.swift:358`
- Modify: `Resources/CardEditorFeature/Localizable.xcstrings`
- Test: `Tests/CardEditorFeatureTests/CardEditorViewModelTests.swift`
- Test: `Tests/CardFlipperAppTests/AppCompositionTests.swift`

**Interfaces:**

```swift
public private(set) var isDirty: Bool
public private(set) var isSaving: Bool
public var canDismissWithoutConfirmation: Bool { !isDirty || didSave }
public func discardChanges()
```

Новая карточка получает стабильный `draftCardID` в initializer; все save attempts используют его.

- [x] Зафиксировать initial content snapshot и написать tests для `isDirty`.
- [x] Написать concurrent-save test: два вызова `save()` приводят максимум к одному repository save.
- [x] Сделать stable draft ID и `isSaving` guard.
- [x] Добавить доступный alert с действиями `Continue Editing` и `Discard Changes`.
- [x] Подключить `.interactiveDismissDisabled(model.isDirty)`; Cancel без изменений закрывает сразу.
- [x] Disable Save + progress во время операции; сохранить существующее поведение при failure.
- [x] Добавить UI-test: cancel не закрывает dirty editor без подтверждения; swipe-down заблокирован.

**Acceptance:** ни один dismissal path не теряет dirty draft молча; save failure сохраняет форму; double tap не создаёт вторую карточку; успешный save закрывает editor без лишнего confirmation.

**Commit:** `fix: protect unsaved card drafts`

---

### Task 4: Adaptive layout policy и regression matrix

**Результат:** появляется единый способ переключать compact controls в accessibility-layout и автоматическая проверка критических экранов.

**Files:**
- Create: `Sources/DesignSystem/AdaptiveControlLayout.swift`
- Create: `Tests/CardFlipperUITests/AccessibilityLayoutTests.swift`
- Modify: `Tests/CardFlipperUITests/CardFlipperFlowTests.swift` — вынести общие launch/seed helpers
- Modify: `docs/planning/ui-ux.md`

**Interface:**

```swift
public enum AdaptiveControlLayout {
    public static func usesVerticalControls(
        dynamicTypeSize: DynamicTypeSize,
        horizontalSizeClass: UserInterfaceSizeClass?
    ) -> Bool
}
```

- [x] Написать unit tests для standard и accessibility Dynamic Type размеров.
- [ ] Добавить UI launch helpers для locale, content size и appearance.
- [ ] Добавить screenshot/accessibility assertions для Empty, Editor, Setup, Prompt, Answer, Result, Statistics, Settings.
- [ ] Проверять существование и hittability primary action на каждом экране.
- [x] Документировать правило: segmented/horizontal controls обязаны иметь vertical alternative при accessibility sizes.

**Acceptance:** один test matrix запускается на iPhone 16e и 17 Pro; primary actions остаются в AX tree и viewport; screenshots сохраняются с устойчивыми именами.

**Commit:** `test: add adaptive layout regression matrix`

---

### Task 5: Timer и assessment controls при MAX Dynamic Type

**Результат:** timer не перекрывает карточку и кнопки; `Remember`/`Don’t remember` всегда доступны.

**Files:**
- Modify: `Sources/StatisticsFeature/StudyTimerPill.swift`
- Modify: `Sources/StudyTimerWidget/StudyTimerLiveActivity.swift`
- Modify: `Sources/StudyFeature/StudySessionView.swift:70-171`
- Modify: `Sources/CardFlipperApp/RootView.swift:379-383`
- Modify: localization catalogs Statistics/App/Widget
- Test: `Tests/StatisticsFeatureTests/StudyTimerControllerTests.swift`
- UI Test: `Tests/CardFlipperUITests/AccessibilityLayoutTests.swift`

**Interface/copy:**

```text
Today 00:12 · Session 00:12
Сегодня 00:12 · Сессия 00:12
```

- [x] Добавить formatter tests для EN/RU и accessibility value.
- [x] Убрать hardcoded English accessibility label.
- [x] При AX sizes перейти на компактный session-time block с полным AX summary.
- [x] Расположить timer и assessment в разных safe-area regions без overlap.
- [x] Проверить prompt, answer и assessment accessibility UI regression test.

**Acceptance:** timer readable и не закрывает контент; assessment actions существуют/hittable после reveal и requeue; visible и accessibility copy локализованы одинаково.

**Commit:** `fix: adapt study timer for accessibility sizes`

---

### Task 6: Новый home hierarchy и понятная навигация

**Результат:** пользователь без знания SF Symbols понимает, как добавить карточку и начать занятие.

**Files:**
- Modify: `Sources/CardFlipperApp/RootView.swift:302-355`
- Modify: `Sources/LibraryFeature/LibraryView.swift:39-64,152-199`
- Create: `Sources/LibraryFeature/LibraryPrimaryActionsView.swift`
- Modify: localization catalogs App/Library
- UI Test: `Tests/CardFlipperUITests/CardFlipperFlowTests.swift`

**Layout contract:**

- `Study today` — явный text+icon primary action с количеством доступных карточек.
- `Add card` — явный text+icon action.
- Settings/Statistics/Bulk — secondary menu либо отдельные подписанные destinations.
- Search отсутствует при `cards.isEmpty`.

- [ ] Добавить UI-test, находящий Add и Study по label без icon identifiers.
- [ ] Реализовать primary actions над list/empty state, в reachable зоне.
- [ ] Заменить Study symbol на `graduationcap.fill` или `play.rectangle.fill`.
- [ ] Убрать пять равновесных glyphs из top bar.
- [ ] Скрывать search при нулевой библиотеке.
- [ ] Проверить enabled/disabled Study и объясняющий disabled reason.

**Acceptance:** first-timer видит два главных действия; disabled Study объясняет необходимость карточек; Settings/Statistics доступны максимум за один tap; AX layout не обрезает labels.

**Commit:** `feat: clarify library primary actions`

---

### Task 7: Видимый Learned-state и Undo

**Результат:** статус карточки не нужно вспоминать или искать свайпом, а ошибочное изменение обратимо.

**Files:**
- Modify: `Sources/LibraryFeature/VocabularyCardRow.swift`
- Modify: `Sources/LibraryFeature/LibraryView.swift:235-287`
- Modify: `Sources/LibraryFeature/LibraryViewModel.swift`
- Create: `Sources/LibraryFeature/LibraryUndoAction.swift`
- Test: `Tests/LibraryFeatureTests/LibraryViewModelTests.swift`
- UI Test: `Tests/CardFlipperUITests/CardFlipperFlowTests.swift`

**Interface:**

```swift
public enum LibraryUndoAction: Equatable {
    case learningStatus(cardID: UUID, previousValue: Bool)
    case deletedCard(VocabularyCard)
}
```

- [ ] Написать tests для visible status, toggle failure и undo learning status.
- [ ] Добавить badge/check с текстовым accessibility value `Learned/Unlearned`.
- [ ] Оставить swipe как shortcut, добавить context menu/visible action.
- [ ] После status/delete показывать undo banner; repository rollback должен быть fallible и сообщать failure.
- [ ] Проверить контраст без опоры только на цвет.

**Acceptance:** статус читается из строки; VoiceOver объявляет его; ошибочный toggle можно отменить; failure не оставляет UI и repository в разных состояниях.

**Commit:** `feat: expose and undo learning status changes`

---

### Task 8: Progressive-disclosure editor и adaptive input rows

**Результат:** базовую пару можно сохранить быстро, advanced metadata не мешает первому действию.

**Files:**
- Modify: `Sources/CardEditorFeature/CardEditorView.swift`
- Modify: `Sources/CardEditorFeature/EnglishVariantsSection.swift`
- Modify: `Sources/CardEditorFeature/RussianMeaningsSection.swift`
- Create: `Sources/CardEditorFeature/PartOfSpeechPicker.swift`
- Modify: `Sources/CardEditorFeature/UsageExamplesEditor.swift`
- Modify: localization catalog CardEditor
- Test: `Tests/CardEditorFeatureTests/CardEditorViewModelTests.swift`
- UI Test: `Tests/CardFlipperUITests/AccessibilityLayoutTests.swift`

**State contract:**

```swift
public var hasAttemptedSave = false
public var expandedMetadataVariantIDs: Set<UUID> = []
```

- [ ] Добавить test: pristine editor не показывает validation errors.
- [ ] Validation показывать после blur соответствующего поля или `hasAttemptedSave`.
- [ ] Первый слой оставить Russian, English и Save; IPA/POS/examples раскрывать через `More details`.
- [ ] Заменить 14-chip strip на searchable picker: common/recent items сверху, полный список ниже.
- [ ] English TextField и speaker/remove раскладывать через `ViewThatFits`; placeholder не должен ellipsize при стандартном размере.
- [ ] Для examples явно показывать, почему сначала требуется POS.
- [ ] Проверить keyboard avoidance и сохранение scroll position.

**Acceptance:** чистый editor не выглядит ошибочным; базовая карточка создаётся без встречи с advanced controls; все функции остаются доступны; MAX AX не режет поле и actions.

**Commit:** `refactor: progressively disclose card metadata`

---

### Task 9: Dictionary lookup не перезаписывает ручной IPA

**Результат:** сетевой suggestion остаётся помощником, а не владельцем пользовательского ввода.

**Files:**
- Modify: `Sources/CardEditorFeature/CardEditorViewModel.swift:336-596`
- Modify: `Sources/CardEditorFeature/EnglishVariantsSection.swift:50-199`
- Test: `Tests/CardEditorFeatureTests/CardEditorViewModelTests.swift:336-473`

**Interface:**

```swift
enum SuggestedField<Value: Equatable>: Equatable {
    case empty
    case suggested(Value)
    case userEdited(Value)
}
```

- [ ] Добавить failing test: delayed lookup не меняет `.userEdited` IPA/POS.
- [ ] Добавить test: suggestion заполняет только пустое или предыдущее suggested value.
- [ ] Отмечать поле manual после прямого пользовательского изменения.
- [ ] Выбрать одну понятную модель: automatic lookup с retry либо manual button; не показывать обе как равноправные.
- [ ] Добавить `Use suggestion` для конфликта вместо автоматической замены.

**Acceptance:** ручной IPA/POS никогда не меняется сетевым ответом без явного согласия; cancellation/race tests остаются зелёными; offline не мешает save.

**Commit:** `fix: preserve manual dictionary fields`

---

### Task 10: Flip-анимация без ghosting и корректные AX hints

**Результат:** в любой фазе видна только одна сторона карточки; Reduce Motion сохраняет смысл перехода.

**Files:**
- Modify: `Sources/StudyFeature/StudyCardView.swift:128-223`
- Modify: localization catalog StudyFeature
- Test: `Tests/StudyFeatureTests/StudySessionViewModelTests.swift:300-359`
- UI Test: `Tests/CardFlipperUITests/CardFlipperFlowTests.swift`

**Presentation contract:**

```swift
struct StudyCardPresentation {
    let visibleFace: StudyCardFaceKind
    let frontRotationDegrees: Double
    let backRotationDegrees: Double
    let frontOpacity: Double
    let backOpacity: Double
}
```

Ровно одна opacity должна быть ненулевой возле midpoint; смена содержимого происходит около 90°.

- [ ] Добавить deterministic tests для start/midpoint/end и Reduce Motion.
- [ ] Развести phase/face visibility вместо одновременного implicit animation обеих сторон.
- [ ] Зафиксировать размер карточки на время flip.
- [ ] На answer-side заменить hint на `Hide answer` или отключить обратный toggle.
- [ ] Записать filmstrip и проверить отсутствие mirrored/double text.

**Acceptance:** ghosting отсутствует; focus переходит prompt → answer; AX label/hint соответствует фактическому tap; Reduce Motion использует короткий crossfade.

**Commit:** `fix: make card flip visually and semantically stable`

---

### Task 11: Study Result сообщает прогресс, а не только завершение

**Результат:** финал объясняет, что пользователь выучил и что делать дальше.

**Files:**
- Modify: `Sources/Core/Study/StudySession.swift`
- Modify: `Sources/StudyFeature/StudySessionViewModel.swift`
- Modify: `Sources/StudyFeature/StudyResultView.swift`
- Modify: `Sources/StatisticsFeature/StudyStatistics.swift`
- Modify: localization catalogs Study/Statistics
- Test: `Tests/CoreTests/StudySessionTests.swift`
- Test: `Tests/StudyFeatureTests/StudySessionViewModelTests.swift`

**Interface:**

```swift
public struct StudyResult: Equatable, Sendable {
    public let reviewedCardCount: Int
    public let repeatedCardIDs: [UUID]
    public let totalAssessmentCount: Int
    public let elapsedSeconds: Int
}
```

- [ ] Добавить result tests для recall rate, repeated cards и zero-repeat case.
- [ ] Заменить `extra attempts` на `cards repeated` с корректной pluralization.
- [ ] Показать duration, recall rate, daily-goal progress и список difficult cards.
- [ ] Добавить отдельное действие `Repeat difficult cards`; `Done` оставить primary exit.
- [ ] Проверить очень длинные слова и пустой difficult list.

**Acceptance:** пользователь понимает результат без знания внутренней queue-модели; repeat затрагивает только difficult cards; VoiceOver читает summary в логичном порядке.

**Commit:** `feat: make study completion actionable`

---

### Task 12: Восстановление незавершённой study session

**Результат:** kill/relaunch не уничтожает очередь и уже сделанные assessments.

**Files:**
- Create: `Sources/Core/Study/StudySessionSnapshot.swift`
- Create: `Sources/Core/Study/StudySessionStore.swift`
- Create: `Sources/Data/Repositories/UserDefaultsStudySessionStore.swift`
- Modify: `Sources/CardFlipperApp/AppContainer.swift`
- Modify: `Sources/CardFlipperApp/RootView.swift`
- Modify: `Sources/StudyFeature/StudySessionViewModel.swift`
- Test: `Tests/CoreTests/StudySessionTests.swift`
- Test: `Tests/DataTests/SwiftDataRepositoriesTests.swift` или отдельный store test file
- Test: `Tests/CardFlipperAppTests/AppCompositionTests.swift`

**Interfaces:**

```swift
public protocol StudySessionStore: Sendable {
    func load() -> StudySessionSnapshot?
    func save(_ snapshot: StudySessionSnapshot)
    func clear()
}
```

- [ ] Определить Codable snapshot: configuration, ordered queue IDs, current face, forget counts, startedAt и accumulated duration.
- [ ] Написать round-trip/corrupt-payload/versioning tests.
- [ ] Сохранять snapshot после reveal/assessment/background, а не каждую timer tick.
- [ ] При launch предлагать `Resume session` / `Discard`; отсутствующие карточки безопасно исключать.
- [ ] Очищать snapshot только после Finish или явного Discard.

**Acceptance:** relaunch восстанавливает ту же текущую карточку и очередь; corrupt snapshot не блокирует app launch; completed session не воскресает.

**Commit:** `feat: restore interrupted study sessions`

---

### Task 13: Полезный empty state, import entry point и управление tags

**Результат:** first launch ведёт к реальному действию, а tags можно обслуживать вне editor.

**Files:**
- Modify: `Sources/LibraryFeature/LibraryView.swift:152-233`
- Modify: `Sources/LibraryFeature/TagFilterView.swift`
- Create: `Sources/LibraryFeature/TagManagementView.swift`
- Modify: `Sources/LibraryFeature/TagChipLayout.swift`
- Modify: `Sources/CardEditorFeature/TagPickerSection.swift`
- Modify: `Sources/CardFlipperApp/RootView.swift`
- Modify: repositories if rename/merge is added
- Test: `Tests/LibraryFeatureTests/LibraryViewModelTests.swift`
- UI Test: `Tests/CardFlipperUITests/CardFlipperFlowTests.swift`

**Required behavior:**

- Empty: `Add card` primary, `Import cards` secondary.
- Tags: create, rename, merge, delete, affected-card count.
- Long tag labels wrap and expose full accessibility value.

- [ ] Добавить UI-tests для Add/Import с empty library.
- [ ] Добавить repository/model tests для rename/merge/delete, включая одинаковые normalized names.
- [ ] Создать явный Tag Management destination вместо `ellipsis.circle`-only affordance.
- [ ] Перед merge/delete показывать количество затрагиваемых карточек.
- [ ] Убрать `.lineLimit(1)` из tag chips и проверить AX sizes.
- [ ] Добавить optional sample-card action только если это не смешивает demo и реальные данные без явного согласия.

**Acceptance:** import доступен без захода в Settings; tag lifecycle выполняется явно; длинные названия не теряются; merge/delete не повреждают cards/learned state.

**Commit:** `feat: improve library onboarding and tag management`

---

### Task 14: Statistics с trends, legend и содержательным zero state

**Результат:** экран отвечает «как я продвигаюсь?» и «что делать дальше?», а не только показывает totals.

**Files:**
- Modify: `Sources/StatisticsFeature/StatisticsRepository.swift`
- Modify: `Sources/StatisticsFeature/StudyStatistics.swift`
- Modify: `Sources/StatisticsFeature/StatisticsMetric.swift`
- Modify: `Sources/StatisticsFeature/ProgressDashboardViewModel.swift`
- Modify: `Sources/StatisticsFeature/StatisticsView.swift`
- Modify: `Sources/StatisticsFeature/ActivityCalendarView.swift`
- Modify: localization catalog Statistics
- Test: `Tests/StatisticsFeatureTests/ProgressDashboardViewModelTests.swift`
- Test: `Tests/StatisticsFeatureTests/StatisticsMetricTests.swift`

**Metrics:** previous-7-day delta, streak, sessions, reviewed cards, repeat/recall rate, daily-goal progress.

- [ ] Добавить aggregation tests для empty, one day, crossing month и previous-window comparison.
- [ ] Разделить calendar states: future, no activity, activity below goal, goal achieved, today.
- [ ] Добавить legend с shape + text, не только цветом.
- [ ] Сделать zero state с объяснением, что появится после первой session, и CTA `Start studying`.
- [ ] Обеспечить 44×44 month navigation targets и осмысленные day AX labels.
- [ ] Проверить adaptive metric grid на AX sizes.

**Acceptance:** все цифры вычисляются из сохранённых данных; future day не выглядит как failure; пользователь видит trend и следующий шаг; zero state не является сеткой нулей.

**Commit:** `feat: turn statistics into learning feedback`

---

### Task 15: Accessible accent palette и adaptive app-icon picker

**Результат:** кастомизация не разрушает контраст, названия иконок не режутся.

**Files:**
- Modify: `Sources/CardFlipperApp/AppearanceSettings.swift`
- Modify: `Sources/CardFlipperApp/SettingsView.swift`
- Modify: `Sources/DesignSystem/PrimaryActionButton.swift`
- Create: `Sources/DesignSystem/AccessibleAccent.swift`
- Modify: localization catalog App
- Test: `Tests/CardFlipperAppTests/AppCompositionTests.swift`
- UI Test: `Tests/CardFlipperUITests/AccessibilityLayoutTests.swift`

**Interface:**

```swift
public struct AccessibleAccent: Identifiable, Equatable, Sendable {
    public let id: String
    public let lightColor: Color
    public let darkColor: Color
}
```

- [ ] Зафиксировать curated palette + `System`; проверить контраст primary foreground/background в light/dark.
- [ ] Мигрировать существующий raw sRGB value к ближайшему допустимому accent либо сохранить custom как explicit advanced option с warning.
- [ ] Primary button foreground выбирать по luminance/contrast, а не `.background` без проверки.
- [ ] App-icon carousel заменить adaptive grid/list при AX sizes; labels многострочные без искусственной ширины 88pt.
- [ ] Показать pending/error state рядом с выбранной иконкой.
- [ ] Проверить смену всех десяти иконок на физическом устройстве; simulator failure не считать acceptance gate для system limitation.

**Acceptance:** любой предлагаемый accent сохраняет читаемость; выбранность видна не только по цвету; полные icon names доступны визуально и VoiceOver; picker не ломается при MAX AX.

**Commit:** `feat: make appearance customization accessible`

---

### Task 16: Финальная унификация copy, icons, motion и regression pass

**Результат:** после функциональных изменений приложение воспринимается как единый продукт и проходит полный accessibility/UX regression.

**Files:**
- Create: `Sources/DesignSystem/AppSymbol.swift`
- Modify: `Sources/LibraryFeature/LibraryView.swift`
- Modify: `Sources/StudyFeature/StudyResultView.swift`
- Modify: `Sources/CardFlipperApp/SettingsView.swift`
- Modify: все затронутые localization catalogs
- Modify: `Tests/StudyFeatureTests/LocalizationCatalogTests.swift`
- Modify: `Tests/CardFlipperUITests/AccessibilityLayoutTests.swift`
- Modify: `docs/planning/ui-ux.md`

**Icon contract:** единый Library symbol; Study — отдельный узнаваемый symbol; Tags — `tag`; destructive actions сохраняют system semantics.

- [ ] Ввести semantic `AppSymbol`, исключить разные literal SF Symbol names для одной сущности.
- [ ] Исправить copy: `Show Russian meanings`, `cards repeated`, локализованный timer, точные import/export summaries.
- [ ] Убрать motion, имитирующий delete/reorder при обычной фильтрации.
- [ ] Проверить Reduce Motion, VoiceOver reading order, Increase Contrast и button shapes.
- [ ] Запустить полный `tuist test CardFlipper --no-selective-testing`.
- [ ] Запустить UI matrix на двух устройствах и сохранить финальные screenshots/filmstrip.
- [ ] Проверить отсутствие literal localization keys и accidental truncation.
- [ ] Обновить `docs/ui-ux.md` фактическими правилами и принятыми решениями.

**Acceptance:** все tests зелёные; primary flows проходят EN/RU, light/dark и MAX AX; одна сущность имеет одну icon semantics; финальные screenshots не содержат overlap, ghosting или случайного truncation.

**Commit:** `chore: complete UX accessibility regression pass`

---

## Definition of Done для каждого пункта

Пункт считается завершённым только когда одновременно выполнено следующее:

1. Сначала добавлен воспроизводящий test или screenshot assertion.
2. Исправление ограничено заявленным scope и не тащит соседний task.
3. Unit/integration tests соответствующих targets проходят.
4. Критический UI проверен минимум на iPhone 16e и 17 Pro.
5. Проверены EN/RU, light/dark, стандартный Dynamic Type и Accessibility XXXL.
6. VoiceOver labels/hints соответствуют фактическому действию.
7. Reduce Motion сохраняет понятный переход.
8. Нет новых silent data fallbacks.
9. Localization catalog не содержит literal keys в runtime UI.
10. Изменение может быть принято или отклонено отдельно от следующего пункта.

## Self-review

- Все проблемы исходного UX-аудита сопоставлены tasks 1–16.
- P1 data integrity закрывают tasks 1–3.
- MAX Dynamic Type и clipping закрывают tasks 4, 5, 8 и 15.
- Navigation/icon semantics закрывают tasks 6, 7, 13 и 16.
- Animation закрывает task 10.
- Result, session continuity и statistics закрывают tasks 11, 12 и 14.
- Import/export feedback и empty onboarding закрывают tasks 2 и 13.
- План не требует внешних зависимостей или изменения deployment target.
