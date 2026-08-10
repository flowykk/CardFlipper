import Core
import SwiftUI

public struct LibraryView: View {
    @State private var model: LibraryViewModel
    @State private var showingCardDeletion = false
    @State private var showingTagDeletion = false

    private let onAddCard: () -> Void
    private let onEditCard: (VocabularyCard) -> Void
    private let onStartStudy: () -> Void

    public init(
        model: LibraryViewModel,
        onAddCard: @escaping () -> Void,
        onEditCard: @escaping (VocabularyCard) -> Void,
        onStartStudy: @escaping () -> Void
    ) {
        _model = State(initialValue: model)
        self.onAddCard = onAddCard
        self.onEditCard = onEditCard
        self.onStartStudy = onStartStudy
    }

    public var body: some View {
        @Bindable var model = model

        content
            .navigationTitle("library.title")
            .searchable(text: $model.searchText, prompt: "library.search")
            .toolbar {
                ToolbarItemGroup(placement: .topBarTrailing) {
                    Button(action: onStartStudy) {
                        Label("library.startStudy", systemImage: "rectangle.stack.fill")
                    }
                    .disabled(model.cards.isEmpty)

                    Button(action: onAddCard) {
                        Label("library.add", systemImage: "plus")
                    }
                }
            }
            .confirmationDialog(
                "card.delete.title",
                isPresented: $showingCardDeletion,
                titleVisibility: .visible
            ) {
                Button("common.delete", role: .destructive) {
                    Task { await model.deletePendingCard() }
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
                    Task { await model.deletePendingTag() }
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
                    onEditCard(card)
                } label: {
                    VocabularyCardRow(card: card)
                }
                .buttonStyle(.plain)
                .swipeActions {
                    Button("common.delete", role: .destructive) {
                        model.pendingDeletion = card
                        showingCardDeletion = true
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

    private func requestTagDeletion(_ tag: Tag) {
        model.pendingTagDeletion = tag
        showingTagDeletion = true
    }

    private func retryDeletion() {
        let failure = model.deletionFailure
        Task {
            switch failure {
            case .card:
                await model.deletePendingCard()
            case .tag:
                await model.deletePendingTag()
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
