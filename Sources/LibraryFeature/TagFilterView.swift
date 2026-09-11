import Core
import DesignSystem
import SwiftUI

public struct LibraryFiltersSheet: View {
    @Environment(\.dismiss) private var dismiss

    private let tags: [Tag]
    @Binding private var selectedTagIDs: Set<UUID>
    @Binding private var learningFilter: CardLearningFilter
    @Binding private var showsRussianMeanings: Bool
    private let onManageTags: () -> Void

    public init(
        tags: [Tag],
        selectedTagIDs: Binding<Set<UUID>>,
        learningFilter: Binding<CardLearningFilter>,
        showsRussianMeanings: Binding<Bool>,
        onManageTags: @escaping () -> Void
    ) {
        self.tags = tags
        _selectedTagIDs = selectedTagIDs
        _learningFilter = learningFilter
        _showsRussianMeanings = showsRussianMeanings
        self.onManageTags = onManageTags
    }

    public var body: some View {
        NavigationStack {
            Form {
                Section("library.learningFilter") {
                    Picker("library.learningFilter", selection: $learningFilter) {
                        Text("learningFilter.all").tag(CardLearningFilter.all)
                        Text("learningFilter.learned").tag(CardLearningFilter.learned)
                        Text("learningFilter.unlearned").tag(CardLearningFilter.unlearned)
                    }
                    .pickerStyle(.segmented)
                    .accessibilityIdentifier("library.learningFilter")
                }

                Section("library.filters.tags") {
                    ForEach(tags) { tag in
                        tagButton(tag)
                    }

                    Button {
                        dismiss()
                        onManageTags()
                    } label: {
                        Label("tag.manage", systemImage: AppSymbol.tags)
                    }
                    .accessibilityIdentifier("library.tags.manage")
                }

                Section("library.filters.display") {
                    Toggle(
                        "library.translations.show",
                        isOn: $showsRussianMeanings
                    )
                    .accessibilityIdentifier("library.translations.toggle")
                }
            }
            .navigationTitle("library.filters.title")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("library.filters.reset", action: reset)
                        .disabled(!canReset)
                        .accessibilityIdentifier("library.filters.reset")
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("common.done") { dismiss() }
                        .accessibilityIdentifier("library.filters.done")
                }
            }
            .accessibilityIdentifier("library.filters.sheet")
        }
    }

    private func tagButton(_ tag: Tag) -> some View {
        let isSelected = selectedTagIDs.contains(tag.id)

        return Button {
            if isSelected {
                selectedTagIDs.remove(tag.id)
            } else {
                selectedTagIDs.insert(tag.id)
            }
            FeedbackGenerator.shared.selection()
        } label: {
            HStack {
                Text(verbatim: tag.name)
                    .foregroundStyle(.primary)
                Spacer()
                if isSelected {
                    Image(systemName: "checkmark")
                        .font(.body.weight(.semibold))
                        .foregroundStyle(Color.accentColor)
                        .accessibilityHidden(true)
                }
            }
            .contentShape(Rectangle())
        }
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    private var canReset: Bool {
        !selectedTagIDs.isEmpty || learningFilter != .all || showsRussianMeanings
    }

    private func reset() {
        selectedTagIDs = []
        learningFilter = .all
        showsRussianMeanings = false
        FeedbackGenerator.shared.selection()
    }
}
