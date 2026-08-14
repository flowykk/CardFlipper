import Core
import SwiftUI

struct BulkTagPickerView: View {
    let tags: [Tag]
    @Binding var selectedTagIDs: Set<UUID>
    let selectedCardCount: Int
    let onConfirm: () -> Void

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List(tags) { tag in
                Button {
                    toggle(tag.id)
                } label: {
                    HStack {
                        Text(verbatim: tag.name)
                        Spacer()
                        Image(systemName: selectedTagIDs.contains(tag.id) ? "checkmark.circle.fill" : "circle")
                            .foregroundStyle(selectedTagIDs.contains(tag.id) ? Color.accentColor : .secondary)
                    }
                }
                .buttonStyle(.plain)
                .accessibilityAddTraits(selectedTagIDs.contains(tag.id) ? .isSelected : [])
                .accessibilityIdentifier("library.bulk.tag.\(tag.id.uuidString)")
            }
            .navigationTitle("library.bulk.tags")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("common.cancel", action: dismiss.callAsFunction)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(action: onConfirm) {
                        Text("library.bulk.addTags \(selectedCardCount)")
                    }
                    .disabled(selectedTagIDs.isEmpty)
                    .accessibilityIdentifier("library.bulk.confirm")
                }
            }
        }
    }

    private func toggle(_ id: UUID) {
        if selectedTagIDs.contains(id) {
            selectedTagIDs.remove(id)
        } else {
            selectedTagIDs.insert(id)
        }
    }
}
