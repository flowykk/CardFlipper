import Core
import DesignSystem
import SwiftUI

public struct WritingSessionView: View {
    @State private var model: WritingSessionViewModel
    @FocusState private var isAnswerFocused: Bool
    @ScaledMetric(relativeTo: .body) private var answerControlSize: CGFloat = 52
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @Environment(\.scenePhase) private var scenePhase

    private let onEdit: (VocabularyCard) -> Void
    private let onRepeat: (StudyConfiguration) -> Void
    private let onFinish: () -> Void
    private let onComplete: (StudyResult) -> Void

    public init(
        model: WritingSessionViewModel,
        onRepeat: @escaping (StudyConfiguration) -> Void,
        onFinish: @escaping () -> Void,
        onComplete: @escaping (StudyResult) -> Void,
        onEdit: @escaping (VocabularyCard) -> Void = { _ in }
    ) {
        _model = State(initialValue: model)
        self.onRepeat = onRepeat
        self.onFinish = onFinish
        self.onComplete = onComplete
        self.onEdit = onEdit
    }

    public var body: some View {
        Group {
            if let result = model.result {
                StudyResultView(
                    result: result,
                    difficultCards: model.difficultCards,
                    dailyGoalProgress: model.dailyGoalProgress,
                    onRepeatDifficult: model.difficultRepeatConfiguration.map { configuration in
                        { onRepeat(configuration) }
                    },
                    onFinish: onFinish
                )
            } else {
                activeSession
            }
        }
        .toolbar {
            if model.result == nil {
                if model.canEditCard {
                    ToolbarItem(placement: .topBarTrailing) {
                        HapticButton {
                            if let card = model.session.currentCard {
                                onEdit(card)
                            }
                        } label: {
                            Label {
                                Text("study.edit", bundle: .module)
                            } icon: {
                                Image(systemName: "pencil")
                            }
                        }
                        .accessibilityIdentifier("study.edit")
                    }
                    if #available(iOS 26.0, *) {
                        ToolbarSpacer(.fixed, placement: .topBarTrailing)
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    HapticButton(role: .destructive) {
                        model.requestExit()
                    } label: {
                        Label("common.close", systemImage: "xmark")
                    }
                    .accessibilityHint(Text("study.exit.message", bundle: .module))
                }
            }
        }
        .safeAreaInset(edge: .top, spacing: 0) {
            if model.result == nil {
                progressHeader
            }
        }
        .safeAreaInset(edge: .bottom) {
            Group {
                if model.result == nil, model.canAssess {
                    assessmentActions
                        .padding(.horizontal)
                        .padding(.vertical, 6)
                        .background(.bar)
                }
            }
            .animation(
                reduceMotion ? .easeInOut(duration: 0.18) : .snappy,
                value: model.canAssess
            )
        }
        .alert(
            Text("study.exit.title", bundle: .module),
            isPresented: exitConfirmation
        ) {
            HapticButton {
                model.cancelExit()
                model.persistSnapshot()
                onFinish()
            } label: {
                Text("study.exit.saveAndExit", bundle: .module)
            }
            HapticButton(role: .cancel) {
                model.cancelExit()
            } label: {
                Text("study.exit.continueGame", bundle: .module)
            }
        } message: {
            Text("study.exit.message", bundle: .module)
        }
        .onChange(of: model.result) { _, result in
            if let result { onComplete(result) }
        }
        .onChange(of: scenePhase) { _, phase in
            if phase != .active { model.persistSnapshot() }
        }
    }

    private var activeSession: some View {
        ScrollView {
            VStack(spacing: 20) {
                if let card = model.session.currentCard {
                    writingCard(card)
                    answerControls

                    if model.isShowingAnswer, model.hasUsageExamples {
                        StudyUsageExamplesView(
                            variants: card.englishVariants,
                            isExpanded: model.isShowingUsageExamples,
                            onToggle: { model.toggleUsageExamples() },
                            onSpeak: { model.speakUsageExample(variantID: $0, exampleID: $1) }
                        )
                    }
                } else {
                    ContentUnavailableView(
                        "library.filteredEmpty",
                        systemImage: "rectangle.stack.badge.minus"
                    )
                }
            }
            .padding()
        }
        .scrollBounceBehavior(.basedOnSize)
        .onAppear {
            isAnswerFocused = !model.isShowingAnswer && model.evaluation != .correct
        }
    }

    private func writingCard(_ card: VocabularyCard) -> some View {
        EqualSizeZStack {
            promptFace(card)
                .allowsHitTesting(!model.isShowingAnswer)
                .accessibilityHidden(model.isShowingAnswer)
                .accessibilityAddTraits(.isButton)
                .accessibilityHint("study.flipHint")
                .accessibilityAction(.default) {
                    model.toggleAnswer()
                }
                .modifier(StableStudyCardFlip(
                    progress: model.isShowingAnswer ? 1 : 0,
                    face: .front,
                    reduceMotion: reduceMotion
                ))

            answerFace(card)
                .allowsHitTesting(model.isShowingAnswer)
                .accessibilityHidden(!model.isShowingAnswer)
                .accessibilityAddTraits(.isButton)
                .accessibilityHint("study.hideAnswerHint")
                .accessibilityAction(.default) {
                    model.toggleAnswer()
                }
                .modifier(StableStudyCardFlip(
                    progress: model.isShowingAnswer ? 1 : 0,
                    face: .back,
                    reduceMotion: reduceMotion
                ))
        }
        .id(card.id)
        .frame(maxWidth: .infinity)
        .contentShape(Rectangle())
        .onTapGesture {
            model.toggleAnswer()
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("study.writing.card")
        .animation(reduceMotion ? .easeInOut(duration: 0.18) : .smooth(duration: 0.4), value: model.isShowingAnswer)
    }

    private func promptFace(_ card: VocabularyCard) -> some View {
        FlashcardSurface {
            VStack(spacing: 20) {
                ForEach(card.russianMeanings) { meaning in
                    Text(verbatim: meaning.text)
                        .font(.largeTitle.weight(.semibold))
                        .multilineTextAlignment(.center)
                }

                if let variant = card.englishVariants.first {
                    StudySpeakButton(
                        accessibilityIdentifier: "study.writing.prompt.speak",
                        action: { model.speakEnglish(variantID: variant.id) }
                    )
                }
            }
        }
    }

    private func answerFace(_ card: VocabularyCard) -> some View {
        FlashcardSurface {
            VStack(spacing: 20) {
                StudyEnglishVariantsView(
                    variants: card.englishVariants,
                    speakAccessibilityIdentifier: "study.writing.speak",
                    onSpeak: { model.speakEnglish(variantID: $0) }
                )
            }
        }
    }

    private var answerControls: some View {
        answerInputRow
    }

    @ViewBuilder
    private var answerInputRow: some View {
        if #available(iOS 26.0, *) {
            GlassEffectContainer(spacing: 10) {
                HStack(spacing: 10) {
                    answerTextField
                        .glassEffect(answerGlass, in: .capsule)
                        .overlay(answerFieldBorder)

                    checkButton
                        .foregroundStyle(.white)
                        .glassEffect(
                            .regular.tint(.accentColor).interactive(),
                            in: .circle
                        )
                }
            }
        } else {
            HStack(spacing: 10) {
                answerTextField
                    .background(.thinMaterial, in: .capsule)
                    .overlay(answerFieldBorder)

                checkButton
                    .foregroundStyle(.white)
                    .background(.tint, in: Circle())
            }
        }
    }

    private var answerTextField: some View {
        TextField(
            "study.writing.answer.placeholder",
            text: Binding(
                get: { model.response },
                set: { model.setResponse($0) }
            )
        )
        .textFieldStyle(.plain)
        .textInputAutocapitalization(.never)
        .autocorrectionDisabled()
        .submitLabel(.done)
        .focused($isAnswerFocused)
        .disabled(model.evaluation == .correct)
        .padding(.horizontal, 18)
        .frame(height: answerControlSize)
        .onSubmit(checkResponse)
        .accessibilityIdentifier("study.writing.answer")
    }

    private var checkButton: some View {
        HapticButton(action: { checkResponse() }) {
            Image(systemName: "checkmark")
                .font(.headline)
                .frame(width: 20, height: 20)
        }
        .buttonStyle(.plain)
        .frame(width: answerControlSize, height: answerControlSize)
        .contentShape(Circle())
        .disabled(!model.canCheck)
        .accessibilityLabel("study.writing.check")
        .accessibilityValue(evaluationAccessibilityValue)
        .accessibilityIdentifier("study.writing.check")
    }

    private var evaluationAccessibilityValue: Text {
        switch model.evaluation {
        case .unanswered:
            Text("")
        case .incorrect:
            Text("study.writing.incorrect")
        case .correct:
            Text("study.writing.correct")
        }
    }

    private var assessmentActions: some View {
        Group {
            if AdaptiveControlLayout.usesVerticalControls(
                dynamicTypeSize: dynamicTypeSize,
                horizontalSizeClass: horizontalSizeClass
            ) {
                VStack(spacing: 8) {
                    rememberButton
                    forgetButton
                }
            } else {
                HStack(spacing: 12) {
                    forgetButton
                    rememberButton
                }
            }
        }
        .transition(
            reduceMotion
                ? .opacity
                : .move(edge: .bottom).combined(with: .opacity)
        )
    }

    private var forgetButton: some View {
        HapticButton(feedback: .none) {
            try? model.forget()
            isAnswerFocused = true
        } label: {
            Label("study.forget", systemImage: AppSymbol.repeatedCards)
                .padding(.vertical, 4)
                .frame(maxWidth: .infinity)
        }
        .buttonStyle(.bordered)
        .frame(minHeight: 44)
        .contentShape(Rectangle())
        .tint(.orange)
        .accessibilityIdentifier("study.forget")
        .accessibilityHint("study.forget.hint")
    }

    private var rememberButton: some View {
        HapticButton(feedback: .none) {
            try? model.remember()
            isAnswerFocused = model.result == nil
        } label: {
            Label("study.remember", systemImage: "checkmark.circle.fill")
                .padding(.vertical, 4)
                .frame(maxWidth: .infinity)
        }
        .buttonStyle(.borderedProminent)
        .frame(minHeight: 44)
        .contentShape(Rectangle())
        .accessibilityIdentifier("study.remember")
        .accessibilityHint("study.remember.hint")
    }

    private var answerFieldBorder: some View {
        Capsule()
            .stroke(
                evaluationColor,
                lineWidth: model.evaluation == .unanswered ? 0 : 2
            )
    }

    @available(iOS 26.0, *)
    private var answerGlass: Glass {
        switch model.evaluation {
        case .unanswered:
            .regular.interactive()
        case .incorrect:
            .regular.tint(.red.opacity(0.18)).interactive()
        case .correct:
            .regular.tint(.green.opacity(0.18)).interactive()
        }
    }

    private var evaluationColor: Color {
        switch model.evaluation {
        case .unanswered: .secondary.opacity(0.35)
        case .incorrect: .red
        case .correct: .green
        }
    }

    private func checkResponse() {
        model.checkResponse()
        isAnswerFocused = model.evaluation == .incorrect
    }

    private var progressHeader: some View {
        HStack(spacing: 12) {
            Text(verbatim: model.progressPresentation.positionText)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .monospacedDigit()
            ProgressView(value: model.progressPresentation.fractionCompleted)
                .accessibilityHidden(true)
                .animation(
                    reduceMotion ? nil : .easeInOut(duration: 0.35),
                    value: model.progressPresentation.fractionCompleted
                )
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
        .background(.bar)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(Text(verbatim: model.progressPresentation.positionText))
        .accessibilityIdentifier("study.progress")
    }

    private var exitConfirmation: Binding<Bool> {
        Binding(
            get: { model.isExitConfirmationPresented },
            set: { isPresented in
                if !isPresented { model.cancelExit() }
            }
        )
    }
}
