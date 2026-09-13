import Core
import DesignSystem
import SwiftUI

public struct StudySessionView: View {
    @State private var model: StudySessionViewModel
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @Environment(\.scenePhase) private var scenePhase

    private let onRepeat: (StudyConfiguration) -> Void
    private let onFinish: () -> Void
    private let onComplete: (StudyResult) -> Void

    public init(
        model: StudySessionViewModel,
        onRepeat: @escaping (StudyConfiguration) -> Void,
        onFinish: @escaping () -> Void,
        onComplete: @escaping (StudyResult) -> Void
    ) {
        _model = State(initialValue: model)
        self.onRepeat = onRepeat
        self.onFinish = onFinish
        self.onComplete = onComplete
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
                ToolbarItem(placement: .topBarTrailing) {
                    HapticButton(role: .destructive) {
                        model.requestExit()
                    } label: {
                        Label("common.close", systemImage: "xmark")
                    }
                    .accessibilityHint("study.exit.message")
                }
            }
        }
        .safeAreaInset(edge: .top, spacing: 0) {
            if model.result == nil {
                progressHeader
            }
        }
        .confirmationDialog(
            "study.exit.title",
            isPresented: exitConfirmation,
            titleVisibility: .visible
        ) {
            HapticButton("common.close", role: .destructive) {
                model.cancelExit()
                onFinish()
            }
            HapticButton("common.cancel", role: .cancel) {
                model.cancelExit()
            }
        } message: {
            Text("study.exit.message")
        }
        .onChange(of: model.result) { _, result in
            if let result {
                onComplete(result)
            }
        }
        .onChange(of: scenePhase) { _, phase in
            if phase != .active {
                model.persistSnapshot()
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
    }

    private var activeSession: some View {
        ScrollView {
            VStack(spacing: 20) {
                if let card = model.session.currentCard {
                    StudyCardView(
                        card: card,
                        direction: model.session.direction,
                        isShowingAnswer: model.isShowingAnswer,
                        reduceMotion: reduceMotion,
                        onToggle: model.toggleCardSide,
                        onSpeak: model.speakEnglish
                    )
                } else {
                    ContentUnavailableView(
                        "library.filteredEmpty",
                        systemImage: "rectangle.stack.badge.minus"
                    )
                }

                if model.canAssess {
                    if model.hasUsageExamples {
                        StudyUsageExamplesView(
                            variants: model.session.currentCard?.englishVariants ?? [],
                            isExpanded: model.isShowingUsageExamples,
                            onToggle: model.toggleUsageExamples,
                            onSpeak: model.speakUsageExample
                        )
                    }
                } else {
                    Text("study.flipHint")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
            }
            .padding()
        }
        .scrollBounceBehavior(.basedOnSize)
        .animation(reduceMotion ? .easeInOut(duration: 0.18) : .snappy, value: model.canAssess)
    }

    private var progressHeader: some View {
        HStack(spacing: 12) {
            Text(verbatim: model.progressPresentation.positionText)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .monospacedDigit()
                .contentTransition(.numericText())

            ProgressView(
                value: model.progressPresentation.fractionCompleted
            )
            .accessibilityHidden(true)
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
        .background(.bar)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(Text(verbatim: model.progressPresentation.positionText))
        .accessibilityIdentifier("study.progress")
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

    private var exitConfirmation: Binding<Bool> {
        Binding(
            get: { model.isExitConfirmationPresented },
            set: { isPresented in
                if isPresented {
                    model.requestExit()
                } else {
                    model.cancelExit()
                }
            }
        )
    }
}
