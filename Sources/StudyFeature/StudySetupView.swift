import Core
import DesignSystem
import SwiftUI

public struct StudySetupView: View {
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
            Section("study.direction") {
                Picker("study.direction", selection: directionSelection) {
                    Text("study.russianToEnglish")
                        .tag(0)
                        .accessibilityIdentifier("study.direction.russianToEnglish")
                    Text("study.englishToRussian")
                        .tag(1)
                        .accessibilityIdentifier("study.direction.englishToRussian")
                }
                .pickerStyle(.segmented)
                .accessibilityHint("study.direction.hint")
            }

            Section("study.learningFilter") {
                Picker("study.learningFilter", selection: $model.learningFilter) {
                    Text("learningFilter.all").tag(CardLearningFilter.all)
                    Text("learningFilter.learned").tag(CardLearningFilter.learned)
                    Text("learningFilter.unlearned").tag(CardLearningFilter.unlearned)
                }
                .pickerStyle(.segmented)
                .accessibilityIdentifier("study.learningFilter")
            }

            Section {
                if model.tags.isEmpty {
                    Label("study.allCards", systemImage: "rectangle.stack")
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

                Button {
                    guard let configuration = model.configuration else { return }
                    onStart(configuration)
                } label: {
                    Label("study.start", systemImage: "play.fill")
                }
                .buttonStyle(PrimaryActionButtonStyle())
                .disabled(!model.canStart)
                .accessibilityIdentifier("study.start")
            }
        }
        .accessibilityIdentifier("study.setup")
        .navigationTitle("study.setup.title")
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

    private func tagButton(_ tag: Tag) -> some View {
        let isSelected = model.selectedTagIDs.contains(tag.id)

        return Button {
            model.toggleTag(tag.id)
        } label: {
            HStack {
                Text(verbatim: tag.name)
                Spacer()
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(isSelected ? Color.accentColor : .secondary)
                    .accessibilityHidden(true)
            }
            .frame(minHeight: 44)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}
