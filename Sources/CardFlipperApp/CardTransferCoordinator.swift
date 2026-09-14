import Core
import DesignSystem
import LibraryFeature
import SwiftUI

struct PreparedCardExport {
    let document: CardTransferFileDocument
    let cardCount: Int
}

@MainActor
struct CardTransferCoordinator {
    private let cards: any CardRepository

    init(cards: any CardRepository) {
        self.cards = cards
    }

    func prepareExport() async throws -> PreparedCardExport {
        let cards = try await cards.fetchCards()
        return PreparedCardExport(
            document: CardTransferFileDocument(
                transfer: CardTransferDocument(cards: cards)
            ),
            cardCount: cards.count
        )
    }
}

enum CardImportError: Error, Equatable {
    case libraryChanged
}

struct CardImportPreviewView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var preview: CardImportPreview
    @State private var isWorking = false
    @State private var errorKey: String?
    private let onConfirm: (CardImportPreview) async throws -> Void
    private let onRefresh: (CardImportPreview) async throws -> CardImportPreview

    init(
        preview: CardImportPreview,
        onConfirm: @escaping (CardImportPreview) async throws -> Void,
        onRefresh: @escaping (CardImportPreview) async throws -> CardImportPreview
    ) {
        _preview = State(initialValue: preview)
        self.onConfirm = onConfirm
        self.onRefresh = onRefresh
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Label(preview.fileName, systemImage: "doc")
                        .font(.subheadline)
                } footer: {
                    Text("import.preview.explanation")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }

                if let errorKey {
                    Section {
                        Label(LocalizedStringKey(errorKey), systemImage: "exclamationmark.triangle")
                            .foregroundStyle(.red)
                        HapticButton("import.preview.refresh") {
                            Task { await refresh() }
                        }
                        .disabled(isWorking)
                    }
                }

                if preview.cardsToSave.isEmpty {
                    Section {
                        Label("import.preview.noChanges", systemImage: "checkmark.circle")
                    }
                }

                changeSection(.added, title: "import.preview.new", symbol: "plus.circle", color: .green)
                changeSection(.updated, title: "import.preview.updated", symbol: "pencil.circle", color: .orange)
                changeSection(.unchanged, title: "import.preview.unchanged", symbol: "equal.circle", color: .secondary)
            }
            .accessibilityIdentifier("import.preview")
            .navigationTitle("import.preview.title")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    HapticButton("common.cancel") { dismiss() }
                        .disabled(isWorking)
                        .accessibilityIdentifier("import.preview.cancel")
                }
            }
            .safeAreaInset(edge: .bottom, spacing: 0) {
                HapticButton {
                    Task { await confirm() }
                } label: {
                    HStack {
                        if isWorking { ProgressView().tint(.white) }
                        Text("import.preview.confirm")
                            .foregroundStyle(.white)
                    }
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(PrimaryActionButtonStyle())
                .disabled(isWorking || preview.cardsToSave.isEmpty || errorKey != nil)
                .accessibilityIdentifier("import.preview.confirm")
                .padding()
                .background(.bar)
            }
        }
        .interactiveDismissDisabled(isWorking)
    }

    @ViewBuilder
    private func changeSection(
        _ kind: CardImportChangeKind, title: LocalizedStringKey, symbol: String, color: Color
    ) -> some View {
        let changes = preview.changes.filter { $0.kind == kind }
        if !changes.isEmpty {
            Section {
                ForEach(changes) { change in
                    VStack(alignment: .leading, spacing: 10) {
                        VocabularyCardRow(card: change.card, showRussianMeanings: true)
                        if kind == .updated, let before = change.before {
                            DisclosureGroup("import.preview.before") {
                                VocabularyCardRow(card: before, showRussianMeanings: true)
                            }
                            .font(.subheadline)
                        }
                    }
                    .accessibilityIdentifier("import.preview.card.\(change.id)")
                }
            } header: {
                HStack {
                    Label(title, systemImage: symbol)
                        .foregroundStyle(color)
                    Spacer()
                    Text(verbatim: String(changes.count))
                }
            }
        }
    }

    private func confirm() async {
        guard !isWorking, !preview.cardsToSave.isEmpty, errorKey == nil else { return }
        isWorking = true
        defer { isWorking = false }
        do {
            try await onConfirm(preview)
            FeedbackGenerator.shared.successfulSave()
            dismiss()
        } catch {
            errorKey = error as? CardImportError == .libraryChanged
                ? "import.preview.libraryChanged" : "import.preview.failed"
        }
    }

    private func refresh() async {
        guard !isWorking else { return }
        isWorking = true
        defer { isWorking = false }
        do {
            preview = try await onRefresh(preview)
            errorKey = nil
        } catch {
            errorKey = "import.preview.failed"
        }
    }
}
