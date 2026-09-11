import Core
import SwiftUI

struct UsageExamplesEditor: View {
    @Binding var variant: EnglishVariantInput
    let variantPosition: Int
    let onAdd: () -> Void
    let onRemove: (UUID) -> Void
    let onSpeak: (UUID) -> Void
    let onChoosePartOfSpeech: (PartOfSpeech, UUID) -> Void

    private let accessibilityLabels = EditorAccessibilityLabels()

    private var canAddExample: Bool {
        !variant.partsOfSpeech.isEmpty
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("editor.examples.title", systemImage: "text.quote")
                .font(.subheadline.weight(.semibold))

            ForEach($variant.usageExamples) { $example in
                VStack(alignment: .leading, spacing: 8) {
                    TextField(
                        "editor.example.placeholder",
                        text: $example.text,
                        axis: .vertical
                    )
                    .lineLimit(2...5)
                    .textInputAutocapitalization(.sentences)
                    .accessibilityIdentifier(identifier(for: example.id, suffix: "text"))

                    ViewThatFits(in: .horizontal) {
                        HStack {
                            partOfSpeechMenu(example: example)
                            Spacer()
                            exampleActions(example: example)
                        }
                        VStack(alignment: .leading, spacing: 4) {
                            partOfSpeechMenu(example: example)
                            exampleActions(example: example)
                                .frame(maxWidth: .infinity, alignment: .trailing)
                        }
                    }

                    if requiresPartOfSpeech(example) {
                        Label(
                            "editor.example.partOfSpeech.required",
                            systemImage: "exclamationmark.circle"
                        )
                        .font(.footnote)
                        .foregroundStyle(.red)
                    }
                }
                .padding(12)
                .background(.quaternary.opacity(0.5), in: RoundedRectangle(cornerRadius: 12))
            }

            Button(action: onAdd) {
                Label("editor.example.add", systemImage: "plus.circle")
            }
            .foregroundStyle(canAddExample ? Color.accentColor : Color.secondary)
            .opacity(canAddExample ? 1 : 0.55)
            .disabled(!canAddExample)
            .animation(.easeOut(duration: 0.18), value: canAddExample)
            .accessibilityIdentifier("editor.english.\(variantPosition - 1).example.add")

            if variant.partsOfSpeech.isEmpty {
                Text("editor.example.partOfSpeech.first")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private func exampleActions(example: UsageExampleInput) -> some View {
        HStack(spacing: 0) {
            Button {
                onSpeak(example.id)
            } label: {
                Image(systemName: "speaker.wave.2")
                    .frame(minWidth: 44, minHeight: 44)
            }
            .buttonStyle(.plain)
            .disabled(example.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            .accessibilityIdentifier(identifier(for: example.id, suffix: "speak"))
            .accessibilityLabel(Text(verbatim: accessibilityLabels.speakUsageExample(
                variantPosition: variantPosition,
                examplePosition: position(of: example.id)
            )))

            Button(role: .destructive) {
                onRemove(example.id)
            } label: {
                Image(systemName: "minus.circle")
                    .frame(minWidth: 44, minHeight: 44)
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier(identifier(for: example.id, suffix: "remove"))
            .accessibilityLabel(Text(verbatim: accessibilityLabels.removeUsageExample(
                variantPosition: variantPosition,
                examplePosition: position(of: example.id)
            )))
        }
    }

    private func partOfSpeechMenu(example: UsageExampleInput) -> some View {
        Menu {
            ForEach(variant.partsOfSpeech, id: \.rawValue) { partOfSpeech in
                Button {
                    onChoosePartOfSpeech(partOfSpeech, example.id)
                } label: {
                    if example.partOfSpeech == partOfSpeech {
                        Label(partOfSpeech.localizedName(), systemImage: "checkmark")
                    } else {
                        Text(partOfSpeech.localizedName())
                    }
                }
            }
        } label: {
            Label {
                if let partOfSpeech = example.partOfSpeech {
                    Text(verbatim: partOfSpeech.localizedName())
                } else {
                    Text("editor.example.partOfSpeech.choose")
                }
            } icon: {
                Image(systemName: "textformat")
            }
            .frame(minHeight: 44)
        }
        .accessibilityIdentifier(identifier(for: example.id, suffix: "partOfSpeech"))
    }

    private func requiresPartOfSpeech(_ example: UsageExampleInput) -> Bool {
        !example.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && example.partOfSpeech == nil
    }

    private func position(of id: UUID) -> Int {
        variant.usageExamples.firstIndex { $0.id == id }.map { $0 + 1 } ?? 1
    }

    private func identifier(for id: UUID, suffix: String) -> String {
        "editor.english.\(variantPosition - 1).example.\(position(of: id) - 1).\(suffix)"
    }
}
