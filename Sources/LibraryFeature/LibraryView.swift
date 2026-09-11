import Core
import DesignSystem
import SwiftUI

public struct LibraryView: View {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @State private var model: LibraryViewModel
    @State private var showingCardDeletion = false
    @State private var showingTagDeletion = false
    @State private var showsRussianMeanings = false
    @State private var showingFilters = false
    @State private var showingBulkTagPicker = false
    @State private var selectedBulkTagIDs: Set<UUID> = []

    private let onAddCard: () -> Void
    private let onEditCard: (VocabularyCard) -> Void
    private let onStartStudy: () -> Void
    private let onImportCards: () -> Void
    private let onManageTags: () -> Void
    private let onDataChanged: @MainActor () async -> Void

    public init(
        model: LibraryViewModel,
        onAddCard: @escaping () -> Void,
        onEditCard: @escaping (VocabularyCard) -> Void,
        onStartStudy: @escaping () -> Void,
        onImportCards: @escaping () -> Void = {},
        onManageTags: @escaping () -> Void = {},
        onDataChanged: @escaping @MainActor () async -> Void = {}
    ) {
        _model = State(initialValue: model)
        self.onAddCard = onAddCard
        self.onEditCard = onEditCard
        self.onStartStudy = onStartStudy
        self.onImportCards = onImportCards
        self.onManageTags = onManageTags
        self.onDataChanged = onDataChanged
    }

    public var body: some View {
        @Bindable var model = model

        content
            .accessibilityIdentifier("library.root")
            .navigationTitle("library.title")
            .modifier(LibrarySearchModifier(
                isEnabled: !model.cards.isEmpty,
                searchText: $model.searchText
            ))
            .toolbar {
                ToolbarItemGroup(placement: .topBarTrailing) {
                    if model.isBulkTagSelectionActive {
                        Button("library.bulk.cancel") { model.cancelBulkTagSelection() }
                            .accessibilityIdentifier("library.bulk.cancel")
                    } else if !model.cards.isEmpty {
                        Button {
                            model.beginBulkTagSelection()
                        } label: {
                            Label("library.bulk.select", systemImage: "checklist")
                        }
                        .accessibilityIdentifier("library.bulk.select")
                    }
                }

                if !model.cards.isEmpty {
                    if #available(iOS 26.0, *) {
                        DefaultToolbarItem(kind: .search, placement: .bottomBar)
                        ToolbarSpacer(.fixed, placement: .bottomBar)
                    }

                    ToolbarItem(placement: .bottomBar) {
                        filterToolbarButton
                    }

                    ToolbarItem(placement: .bottomBar) {
                        studyToolbarButton
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
            .sheet(isPresented: $showingFilters) {
                LibraryFiltersSheet(
                    tags: model.tags,
                    selectedTagIDs: $model.selectedTagIDs,
                    learningFilter: $model.learningFilter,
                    showsRussianMeanings: $showsRussianMeanings,
                    onManageTags: {
                        showingFilters = false
                        onManageTags()
                    }
                )
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
            }
            .safeAreaInset(edge: .bottom) {
                if model.isBulkTagSelectionActive {
                    bulkSelectionBar
                } else if model.undoAction != nil {
                    undoBanner
                }
            }
            .alert(
                "data.save.failed",
                isPresented: learningStatusFailureBinding
            ) {
                Button("common.retry") {
                    retryLearningStatusChange()
                }
                Button("common.cancel", role: .cancel) {
                    model.dismissLearningStatusFailure()
                }
            }
            .alert("library.undo.failed", isPresented: undoFailureBinding) {
                Button("common.retry") {
                    performUndo()
                }
                Button("common.cancel", role: .cancel) {
                    model.dismissUndo()
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
            ScrollView {
                VStack(spacing: 16) {
                    Image(systemName: AppSymbol.library)
                        .font(.system(size: 44, weight: .semibold))
                        .foregroundStyle(.secondary)
                        .accessibilityHidden(true)

                    Text("library.empty.title")
                        .font(.title2.bold())
                        .multilineTextAlignment(.center)
                        .accessibilityIdentifier("library.empty")

                    Text("library.empty.message")
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)

                    Button(action: onAddCard) {
                        Label("library.add", systemImage: "plus")
                            .frame(maxWidth: .infinity, minHeight: 44)
                    }
                    .buttonStyle(.borderedProminent)
                    .accessibilityIdentifier("library.add")

                    Button(action: onImportCards) {
                        Label("settings.cards.import", systemImage: AppSymbol.importCards)
                            .frame(maxWidth: .infinity, minHeight: 44)
                    }
                    .buttonStyle(.bordered)
                    .accessibilityIdentifier("library.import")
                }
                .frame(maxWidth: 360)
                .padding(.horizontal)
                .padding(.top, dynamicTypeSize.isAccessibilitySize ? 24 : 80)
                .padding(.bottom, 24)
                .frame(maxWidth: .infinity)
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
                    model.learningFilter = .all
                }
                .buttonStyle(.bordered)
            }
        } else {
            cardList
        }
    }

    private var cardList: some View {
        List {
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
                .swipeActions(edge: .leading) {
                    learningStatusButton(for: card)
                        .tint(.green)
                }
                .contextMenu {
                    learningStatusButton(for: card)
                    Button("common.delete", role: .destructive) {
                        model.pendingDeletion = card
                        showingCardDeletion = true
                    }
                }
            }
        }
        .listStyle(.plain)
    }

    private var filterToolbarButton: some View {
        Button {
            showingFilters = true
        } label: {
            Image(systemName: activeFilterCount == 0
                ? "line.3.horizontal.decrease"
                : "line.3.horizontal.decrease.circle.fill")
        }
        .accessibilityLabel("library.filters.title")
        .accessibilityValue(Text(verbatim: activeFilterAccessibilityValue))
        .accessibilityIdentifier("library.filters")
    }

    private var activeFilterCount: Int {
        model.selectedTagIDs.count + (model.learningFilter == .all ? 0 : 1)
    }

    private var activeFilterAccessibilityValue: String {
        String.localizedStringWithFormat(
            String(localized: "library.filters.active", bundle: .main),
            activeFilterCount
        )
    }

    private var studyToolbarButton: some View {
        LibraryStudyToolbarButton(
            cardCount: model.cards.count,
            onStartStudy: onStartStudy
        )
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

    private var learningStatusFailureBinding: Binding<Bool> {
        Binding(
            get: { model.learningStatusFailure != nil },
            set: { isPresented in
                if !isPresented {
                    model.dismissLearningStatusFailure()
                }
            }
        )
    }

    private var undoFailureBinding: Binding<Bool> {
        Binding(
            get: { model.undoFailed },
            set: { isPresented in
                if !isPresented, model.undoFailed {
                    model.dismissUndo()
                }
            }
        )
    }

    @ViewBuilder
    private func learningStatusButton(for card: VocabularyCard) -> some View {
        Button(card.isLearned ? "library.markUnlearned" : "library.markLearned") {
            Task {
                await model.toggleLearningStatus(for: card)
            }
        }
        .accessibilityIdentifier(
            card.isLearned ? "library.markUnlearned" : "library.markLearned"
        )
    }

    private var undoBanner: some View {
        HStack(spacing: 12) {
            Image(systemName: "arrow.uturn.backward.circle.fill")
                .foregroundStyle(Color.accentColor)
                .accessibilityHidden(true)
            Text(undoMessageKey)
                .font(.subheadline)
                .lineLimit(2)
            Spacer(minLength: 8)
            Button("library.undo", action: performUndo)
                .fontWeight(.semibold)
                .accessibilityIdentifier("library.undo")
            Button {
                model.dismissUndo()
            } label: {
                Image(systemName: "xmark")
            }
            .accessibilityLabel("common.close")
        }
        .padding(.horizontal)
        .padding(.vertical, 12)
        .background(.bar)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("library.undoBanner")
    }

    private var undoMessageKey: LocalizedStringKey {
        switch model.undoAction {
        case .learningStatus:
            "library.undo.learningStatus"
        case .deletedCard:
            "library.undo.deletedCard"
        case nil:
            ""
        }
    }

    private func performUndo() {
        Task {
            if await model.performUndo() {
                await onDataChanged()
            }
        }
    }

    private var bulkSelectionBar: some View {
        HStack {
            Text(
                String(
                    format: String(localized: "library.bulk.selected", bundle: .main),
                    model.selectedBulkCardIDs.count
                )
            )
                .font(.subheadline.weight(.medium))
            Spacer()
            Button("library.bulk.tags") {
                selectedBulkTagIDs = []
                showingBulkTagPicker = true
            }
            .buttonStyle(.borderedProminent)
            .disabled(model.selectedBulkCardIDs.isEmpty || model.tags.isEmpty)
            .accessibilityIdentifier("library.bulk.tags")
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

    private func retryLearningStatusChange() {
        guard let card = model.learningStatusFailure else { return }
        Task {
            await model.toggleLearningStatus(for: card)
        }
    }
}

private struct LibrarySearchModifier: ViewModifier {
    let isEnabled: Bool
    @Binding var searchText: String

    @ViewBuilder
    func body(content: Content) -> some View {
        if isEnabled {
            content.searchable(text: $searchText, prompt: "library.search")
        } else {
            content
        }
    }
}
