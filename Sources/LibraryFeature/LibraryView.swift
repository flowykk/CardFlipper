import Core
import SwiftUI

public struct LibraryView: View {
    @State private var model: LibraryViewModel
    @State private var showingCardDeletion = false
    @State private var showingTagDeletion = false
    @State private var showsRussianMeanings = false
    @State private var showingBulkTagPicker = false
    @State private var selectedBulkTagIDs: Set<UUID> = []

    private let onAddCard: () -> Void
    private let onEditCard: (VocabularyCard) -> Void
    private let onStartStudy: () -> Void
    private let onDataChanged: @MainActor () async -> Void

    public init(
        model: LibraryViewModel,
        onAddCard: @escaping () -> Void,
        onEditCard: @escaping (VocabularyCard) -> Void,
        onStartStudy: @escaping () -> Void,
        onDataChanged: @escaping @MainActor () async -> Void = {}
    ) {
        _model = State(initialValue: model)
        self.onAddCard = onAddCard
        self.onEditCard = onEditCard
        self.onStartStudy = onStartStudy
        self.onDataChanged = onDataChanged
    }

    public var body: some View {
        @Bindable var model = model

        content
            .accessibilityIdentifier("library.root")
            .navigationTitle("library.title")
            .searchable(text: $model.searchText, prompt: "library.search")
            .toolbar {
                ToolbarItemGroup(placement: .topBarTrailing) {
                    if !model.isBulkTagSelectionActive {
                        Button(action: onStartStudy) {
                            Label("library.startStudy", systemImage: "rectangle.stack.fill")
                        }
                        .disabled(model.cards.isEmpty)
                        .accessibilityIdentifier("library.study")

                        Button {
                            model.beginBulkTagSelection()
                        } label: {
                            Label("library.bulk.select", systemImage: "checklist")
                        }
                        .disabled(model.cards.isEmpty)
                        .accessibilityIdentifier("library.bulk.select")

                        Button(action: onAddCard) {
                            Label("library.add", systemImage: "plus")
                        }
                        .accessibilityIdentifier("library.add")
                    }
                }
            }
            .confirmationDialog(
                "card.delete.title",
                isPresented: $showingCardDeletion,
                titleVisibility: .visible
            ) {
                Button("common.delete", role: .destructive) {
                    Task {
                        if await model.deletePendingCard() {
                            await onDataChanged()
                        }
                    }
                }
                Button("common.cancel", role: .cancel) {
                    model.pendingDeletion = nil
                }
            } message: {
                Text("card.delete.message")
            }
            .confirmationDialog(
                "tag.delete.title",
                isPresented: $showingTagDeletion,
                titleVisibility: .visible
            ) {
                Button("common.delete", role: .destructive) {
                    Task {
                        if await model.deletePendingTag() {
                            await onDataChanged()
                        }
                    }
                }
                Button("common.cancel", role: .cancel) {
                    model.pendingTagDeletion = nil
                }
            } message: {
                Text("tag.delete.message")
            }
            .alert(
                "data.delete.failed",
                isPresented: deletionFailureBinding
            ) {
                Button("common.retry") {
                    retryDeletion()
                }
                Button("common.cancel", role: .cancel) {
                    cancelFailedDeletion()
                }
            }
            .alert("data.save.failed", isPresented: bulkTagAssignmentFailureBinding) {
                Button("common.retry") {
                    addSelectedTags()
                }
                Button("common.cancel", role: .cancel) {
                    model.dismissBulkTagAssignmentFailure()
                }
            }
            .sheet(isPresented: $showingBulkTagPicker) {
                BulkTagPickerView(
                    tags: model.tags,
                    selectedTagIDs: $selectedBulkTagIDs,
                    selectedCardCount: model.selectedBulkCardIDs.count,
                    onConfirm: addSelectedTags
                )
            }
            .safeAreaInset(edge: .bottom) {
                if model.isBulkTagSelectionActive {
                    bulkSelectionBar
                }
            }
            .task {
                guard model.state == .idle else { return }
                await model.load()
            }
    }

    @ViewBuilder
    private var content: some View {
        switch model.state {
        case .idle, .loading:
            ProgressView("data.loading")
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        case .failed:
            ContentUnavailableView {
                Label("data.load.failed", systemImage: "exclamationmark.triangle")
            } actions: {
                Button("common.retry") {
                    Task { await model.load() }
                }
                .buttonStyle(.borderedProminent)
            }
        case .loaded:
            loadedContent
        }
    }

    @ViewBuilder
    private var loadedContent: some View {
        if model.cards.isEmpty {
            ContentUnavailableView {
                Label("library.empty.title", systemImage: "rectangle.stack")
                    .accessibilityIdentifier("library.empty")
            } description: {
                Text("library.empty.message")
            } actions: {
                Button("library.add", action: onAddCard)
                    .buttonStyle(.borderedProminent)
            }
        } else if model.visibleCards.isEmpty {
            ContentUnavailableView {
                Label("library.filteredEmpty", systemImage: "magnifyingglass")
            } description: {
                Text("library.filteredEmpty.message")
            } actions: {
                Button("library.clearFilters") {
                    model.searchText = ""
                    model.selectedTagIDs = []
                }
                .buttonStyle(.bordered)
            }
        } else {
            cardList
        }
    }

    private var cardList: some View {
        List {
            Section {
                Toggle(
                    "library.translations.show",
                    isOn: $showsRussianMeanings
                )
                .accessibilityIdentifier("library.translations.toggle")
            }

            if !model.tags.isEmpty {
                Section {
                    TagFilterView(
                        tags: model.tags,
                        selectedTagIDs: Binding(
                            get: { model.selectedTagIDs },
                            set: { model.selectedTagIDs = $0 }
                        ),
                        onRequestDeletion: requestTagDeletion
                    )
                    .listRowInsets(EdgeInsets())
                }
            }

            ForEach(model.visibleCards) { card in
                Button {
                    if model.isBulkTagSelectionActive {
                        model.toggleBulkCardSelection(id: card.id)
                    } else {
                        onEditCard(card)
                    }
                } label: {
                    HStack(spacing: 12) {
                        if model.isBulkTagSelectionActive {
                            Image(
                                systemName: model.selectedBulkCardIDs.contains(card.id)
                                    ? "checkmark.circle.fill"
                                    : "circle"
                            )
                            .foregroundStyle(
                                model.selectedBulkCardIDs.contains(card.id) ? Color.accentColor : .secondary
                            )
                            .accessibilityHidden(true)
                        }

                        VocabularyCardRow(
                            card: card,
                            showRussianMeanings: showsRussianMeanings
                        )
                    }
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("library.card")
                .accessibilityAddTraits(
                    model.selectedBulkCardIDs.contains(card.id) ? .isSelected : []
                )
                .swipeActions {
                    if !model.isBulkTagSelectionActive {
                        Button("common.delete") {
                            model.pendingDeletion = card
                            showingCardDeletion = true
                        }
                        .tint(.red)
                    }
                }
            }
        }
        .listStyle(.plain)
    }

    private var deletionFailureBinding: Binding<Bool> {
        Binding(
            get: { model.deletionFailure != nil },
            set: { isPresented in
                if !isPresented {
                    model.dismissDeletionFailure()
                }
            }
        )
    }

    private var bulkTagAssignmentFailureBinding: Binding<Bool> {
        Binding(
            get: { model.bulkTagAssignmentFailed },
            set: { isPresented in
                if !isPresented {
                    model.dismissBulkTagAssignmentFailure()
                }
            }
        )
    }

    private var bulkSelectionBar: some View {
        HStack {
            Text("library.bulk.selected \(model.selectedBulkCardIDs.count)")
                .font(.subheadline.weight(.medium))
            Spacer()
            Button("library.bulk.tags") {
                selectedBulkTagIDs = []
                showingBulkTagPicker = true
            }
            .buttonStyle(.borderedProminent)
            .disabled(model.selectedBulkCardIDs.isEmpty || model.tags.isEmpty)
            .accessibilityIdentifier("library.bulk.tags")
            Button("library.bulk.cancel") {
                model.cancelBulkTagSelection()
            }
            .buttonStyle(.bordered)
            .accessibilityIdentifier("library.bulk.cancel")
        }
        .padding(.horizontal)
        .padding(.vertical, 12)
        .background(.bar)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("library.bulk.bar")
    }

    private func addSelectedTags() {
        Task {
            if await model.addTagsToSelectedCards(ids: selectedBulkTagIDs) {
                showingBulkTagPicker = false
                selectedBulkTagIDs = []
                await onDataChanged()
            } else {
                showingBulkTagPicker = false
            }
        }
    }

    private func requestTagDeletion(_ tag: Tag) {
        model.pendingTagDeletion = tag
        showingTagDeletion = true
    }

    private func retryDeletion() {
        let failure = model.deletionFailure
        Task {
            switch failure {
            case .card:
                if await model.deletePendingCard() {
                    await onDataChanged()
                }
            case .tag:
                if await model.deletePendingTag() {
                    await onDataChanged()
                }
            case nil:
                break
            }
        }
    }

    private func cancelFailedDeletion() {
        switch model.deletionFailure {
        case .card:
            model.pendingDeletion = nil
        case .tag:
            model.pendingTagDeletion = nil
        case nil:
            break
        }
        model.dismissDeletionFailure()
    }
}
