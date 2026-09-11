import Core
import DesignSystem
import SwiftUI

public struct StudySessionView: View {
    @State private var model: StudySessionViewModel
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

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
                    onRepeat: { onRepeat(model.repeatConfiguration) },
                    onFinish: onFinish
                )
            } else {
                activeSession
            }
        }
        .toolbar {
            if model.result == nil {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(role: .destructive) {
                        model.requestExit()
                    } label: {
                        Label("common.close", systemImage: "xmark")
                    }
                    .accessibilityHint("study.exit.message")
                }
            }
        }
        .confirmationDialog(
            "study.exit.title",
            isPresented: exitConfirmation,
            titleVisibility: .visible
        ) {
            Button("common.close", role: .destructive) {
                model.cancelExit()
                onFinish()
            }
            Button("common.cancel", role: .cancel) {
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
        .safeAreaInset(edge: .bottom) {
            if model.result == nil, model.canAssess {
                assessmentActions
                    .padding(.horizontal)
                    .padding(.vertical, 8)
                    .background(.bar)
            }
        }
    }

    private var activeSession: some View {
        ScrollView {
            VStack(spacing: 20) {
                VStack(spacing: 8) {
                    Text(directionKey)
                        .font(.headline)

                    Text(verbatim: remainingText)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .contentTransition(.numericText())

                    ProgressView(
                        value: Double(model.rememberedCount),
                        total: Double(max(model.session.initialCardCount, 1))
                    )
                    .accessibilityLabel(Text(verbatim: remainingText))
                }

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
        Button {
            try? model.forget()
        } label: {
            Label("study.forget", systemImage: "arrow.uturn.backward.circle.fill")
                .frame(maxWidth: .infinity, minHeight: 44)
        }
        .buttonStyle(.bordered)
        .tint(.orange)
        .accessibilityIdentifier("study.forget")
        .accessibilityHint("study.forget.hint")
    }

    private var rememberButton: some View {
        Button {
            try? model.remember()
        } label: {
            Label("study.remember", systemImage: "checkmark.circle.fill")
                .frame(maxWidth: .infinity, minHeight: 44)
        }
        .buttonStyle(.borderedProminent)
        .accessibilityIdentifier("study.remember")
        .accessibilityHint("study.remember.hint")
    }

    private var directionKey: LocalizedStringKey {
        switch model.session.direction {
        case .russianToEnglish: "study.russianToEnglish"
        case .englishToRussian: "study.englishToRussian"
        }
    }

    private var remainingText: String {
        String.localizedStringWithFormat(
            String(localized: "study.remaining"),
            model.session.remainingCount
        )
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
