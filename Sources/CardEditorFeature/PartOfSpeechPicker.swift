import Core
import DesignSystem
import SwiftUI

struct PartOfSpeechPicker: View {
    @State private var searchText = ""

    let selected: [PartOfSpeech]
    let onToggle: (PartOfSpeech) -> Void
    let identifierPrefix: String

    private let commonParts: [PartOfSpeech] = [.noun, .verb, .adj, .adv]

    var body: some View {
        List {
            if searchText.isEmpty {
                Section("editor.partOfSpeech.common") {
                    ForEach(commonParts, id: \.rawValue, content: row)
                }
            }

            Section(searchText.isEmpty ? "editor.partOfSpeech.all" : "editor.partOfSpeech.results") {
                ForEach(filteredParts, id: \.rawValue, content: row)
            }
        }
        .environment(\.defaultMinListRowHeight, 44)
        .navigationTitle("editor.partOfSpeech.title")
        .navigationBarTitleDisplayMode(.inline)
        .searchable(text: $searchText, prompt: "editor.partOfSpeech.search")
    }

    private var filteredParts: [PartOfSpeech] {
        let candidates = searchText.isEmpty
            ? PartOfSpeech.allCases.filter { !commonParts.contains($0) }
            : PartOfSpeech.allCases
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return candidates }
        return candidates.filter {
            $0.localizedName().localizedCaseInsensitiveContains(query)
        }
    }

    private func row(_ partOfSpeech: PartOfSpeech) -> some View {
        HapticButton(feedback: .selection) {
            onToggle(partOfSpeech)
        } label: {
            HStack {
                Text(verbatim: partOfSpeech.localizedName())
                    .foregroundStyle(.primary)
                Spacer()
                if selected.contains(partOfSpeech) {
                    Image(systemName: "checkmark")
                        .foregroundStyle(Color.accentColor)
                        .accessibilityHidden(true)
                }
            }
            .frame(minHeight: 44)
        }
        .listRowInsets(EdgeInsets(top: 0, leading: 20, bottom: 0, trailing: 20))
        .accessibilityIdentifier("\(identifierPrefix).\(partOfSpeech.rawValue)")
        .accessibilityAddTraits(selected.contains(partOfSpeech) ? .isSelected : [])
    }
}
