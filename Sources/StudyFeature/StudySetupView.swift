import Core
import DesignSystem
import SwiftUI

public struct StudySetupView: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var model: StudySetupViewModel
    private let onStart: (StudyConfiguration) -> Void

    public init(
        model: StudySetupViewModel,
        onStart: @escaping (StudyConfiguration) -> Void
    ) {
        _model = State(initialValue: model)
        self.onStart = onStart
    }

    public var body: some View {
        Form {
            Section("study.mode") {
                Picker("study.mode", selection: modeSelection.withSelectionFeedback()) {
                    Text("study.mode.flashcards")
                        .tag(StudyMode.flashcards)
                        .accessibilityIdentifier("study.mode.flashcards")
                    Text("study.mode.writing")
                        .tag(StudyMode.writing)
                        .accessibilityIdentifier("study.mode.writing")
                }
                .pickerStyle(.segmented)
                .accessibilityIdentifier("study.mode")

                if model.mode == .writing {
                    Label("study.writing.directionHint", systemImage: "character.cursor.ibeam")
                        .foregroundStyle(.secondary)
                        .transition(.opacity)
                }
            }

            if model.mode == .flashcards {
                Section("study.direction") {
                    Picker(
                        "study.direction",
                        selection: directionSelection.withSelectionFeedback()
                    ) {
                        Text(verbatim: "🇷🇺 → 🇬🇧")
                            .tag(0)
                            .accessibilityLabel("study.russianToEnglish")
                            .accessibilityIdentifier("study.direction.russianToEnglish")
                        Text(verbatim: "🇬🇧 → 🇷🇺")
                            .tag(1)
                            .accessibilityLabel("study.englishToRussian")
                            .accessibilityIdentifier("study.direction.englishToRussian")
                    }
                    .pickerStyle(.segmented)
                    .accessibilityHint("study.direction.hint")
                }
                .transition(directionTransition)
            }

            Section("study.learningFilter") {
                Picker(
                    "study.learningFilter",
                    selection: $model.learningFilter.withSelectionFeedback()
                ) {
                    Text("learningFilter.all").tag(CardLearningFilter.all)
                    Text("learningFilter.learned").tag(CardLearningFilter.learned)
                    Text("learningFilter.unlearned").tag(CardLearningFilter.unlearned)
                }
                .pickerStyle(.segmented)
                .accessibilityIdentifier("study.learningFilter")
            }

            Section {
                if model.tags.isEmpty {
                    Label("study.allCards", systemImage: AppSymbol.library)
                } else {
                    ForEach(model.tags) { tag in
                        tagButton(tag)
                    }
                }
            } header: {
                Text("library.filter")
            } footer: {
                if model.selectedTagIDs.isEmpty {
                    Text("study.allCards")
                }
            }

            Section {
                if model.matchingCards.isEmpty {
                    Label("library.filteredEmpty", systemImage: "rectangle.stack.badge.minus")
                        .foregroundStyle(.secondary)
                }

                Text(verbatim: localizedCount("study.matchingCount", model.matchingCards.count))
                    .contentTransition(.numericText())
            }
        }
        .animation(modeTransitionAnimation, value: model.mode)
        .accessibilityIdentifier("study.setup")
        .navigationTitle("study.setup.title")
        .safeAreaInset(edge: .bottom, spacing: 0) {
            startButton
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background {
                    Color(uiColor: .systemGroupedBackground)
                        .ignoresSafeArea(edges: .bottom)
                }
                .overlay(alignment: .top) {
                    LinearGradient(
                        colors: [
                            .clear,
                            Color(uiColor: .systemGroupedBackground)
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                    .frame(height: 16)
                    .offset(y: -16)
                    .allowsHitTesting(false)
                }
        }
    }

    private var startButton: some View {
        HapticButton {
            guard let configuration = model.configuration else { return }
            onStart(configuration)
        } label: {
            Label("study.start", systemImage: "play.fill")
                .foregroundStyle(.white)
        }
        .buttonStyle(PrimaryActionButtonStyle())
        .disabled(!model.canStart)
        .accessibilityIdentifier("study.start")
    }

    private var modeTransitionAnimation: Animation {
        reduceMotion ? .easeInOut(duration: 0.15) : .smooth(duration: 0.25)
    }

    private var directionTransition: AnyTransition {
        reduceMotion ? .opacity : .move(edge: .top).combined(with: .opacity)
    }

    private func localizedCount(_ key: String, _ count: Int) -> String {
        String.localizedStringWithFormat(
            String(localized: String.LocalizationValue(key)),
            count
        )
    }

    private var directionSelection: Binding<Int> {
        Binding(
            get: {
                switch model.direction {
                case .russianToEnglish: 0
                case .englishToRussian: 1
                case nil: -1
                }
            },
            set: { value in
                model.chooseDirection(value == 0 ? .russianToEnglish : .englishToRussian)
            }
        )
    }

    private var modeSelection: Binding<StudyMode> {
        Binding(
            get: { model.mode },
            set: { model.chooseMode($0) }
        )
    }

    private func tagButton(_ tag: Tag) -> some View {
        let isSelected = model.selectedTagIDs.contains(tag.id)

        return HapticButton(feedback: .selection) {
            model.toggleTag(tag.id)
        } label: {
            HStack {
                Text(verbatim: tag.name)
                Spacer()
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(
                        isSelected ? AnyShapeStyle(.tint) : AnyShapeStyle(.secondary)
                    )
                    .contentTransition(.symbolEffect(.replace))
                    .animation(.snappy(duration: 0.2), value: isSelected)
                    .accessibilityHidden(true)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}
