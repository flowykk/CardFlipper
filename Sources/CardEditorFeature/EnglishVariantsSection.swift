import Core
import SwiftUI

public struct EnglishVariantsSection: View {
    @Binding private var variants: [EnglishVariantInput]
    private let lookupState: [UUID: LookupState]
    private let showsValidationError: Bool
    private let onAdd: () -> Void
    private let onRemove: (UUID) -> Void
    private let onTextChanged: (UUID) -> Void
    private let onLookup: (UUID) -> Void
    private let onSpeak: (UUID) -> Void
    private let onTogglePartOfSpeech: (PartOfSpeech, UUID) -> Void
    private let accessibilityLabels = EditorAccessibilityLabels()

    public init(
        variants: Binding<[EnglishVariantInput]>,
        lookupState: [UUID: LookupState],
        showsValidationError: Bool,
        onAdd: @escaping () -> Void,
        onRemove: @escaping (UUID) -> Void,
        onTextChanged: @escaping (UUID) -> Void,
        onLookup: @escaping (UUID) -> Void,
        onSpeak: @escaping (UUID) -> Void,
        onTogglePartOfSpeech: @escaping (PartOfSpeech, UUID) -> Void
    ) {
        _variants = variants
        self.lookupState = lookupState
        self.showsValidationError = showsValidationError
        self.onAdd = onAdd
        self.onRemove = onRemove
        self.onTextChanged = onTextChanged
        self.onLookup = onLookup
        self.onSpeak = onSpeak
        self.onTogglePartOfSpeech = onTogglePartOfSpeech
    }

    public var body: some View {
        Section {
            ForEach($variants) { $variant in
                VStack(alignment: .leading, spacing: 12) {
                    HStack(alignment: .firstTextBaseline) {
                        TextField("editor.english.placeholder", text: $variant.text)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                            .accessibilityLabel("editor.english.value")
                            .accessibilityIdentifier("editor.english.\(position(of: variant.id) - 1)")
                            .onChange(of: variant.text) {
                                onTextChanged(variant.id)
                            }

                        Button {
                            onSpeak(variant.id)
                        } label: {
                            Image(systemName: "speaker.wave.2")
                                .frame(minWidth: 44, minHeight: 44)
                        }
                        .buttonStyle(.plain)
                        .disabled(variant.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                        .accessibilityLabel(Text(verbatim: accessibilityLabels.speakEnglishVariant(
                            position: position(of: variant.id)
                        )))

                        Button(role: .destructive) {
                            onRemove(variant.id)
                        } label: {
                            Image(systemName: "minus.circle")
                                .frame(minWidth: 44, minHeight: 44)
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel(Text(verbatim: accessibilityLabels.removeEnglishVariant(
                            position: position(of: variant.id)
                        )))
                    }

                    TextField("editor.ipa.placeholder", text: $variant.ipa)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .accessibilityLabel("editor.ipa.value")
                        .accessibilityIdentifier("editor.ipa.\(position(of: variant.id) - 1)")

                    ScrollView(.horizontal) {
                        HStack(spacing: 8) {
                            ForEach(PartOfSpeech.allCases, id: \.rawValue) { partOfSpeech in
                                partOfSpeechButton(
                                    partOfSpeech,
                                    isSelected: variant.partsOfSpeech.contains(partOfSpeech),
                                    variantID: variant.id
                                )
                            }
                        }
                    }
                    .scrollIndicators(.hidden)

                    HStack {
                        lookupStatus(for: variant.id)
                        Spacer()
                        Button {
                            onLookup(variant.id)
                        } label: {
                            Label("editor.lookup.action", systemImage: "text.magnifyingglass")
                        }
                        .disabled(variant.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    }
                }
                .padding(.vertical, 4)
            }

            Button(action: onAdd) {
                Label("editor.english.add", systemImage: "plus.circle")
            }
            .accessibilityIdentifier("editor.english.add")

            if showsValidationError {
                Label("editor.english.required", systemImage: "exclamationmark.circle")
                    .font(.footnote)
                    .foregroundStyle(.red)
                    .accessibilityLabel("editor.english.required")
            }
        } header: {
            Text("editor.english.title")
        }
    }

    private func partOfSpeechButton(
        _ partOfSpeech: PartOfSpeech,
        isSelected: Bool,
        variantID: UUID
    ) -> some View {
        Button {
            onTogglePartOfSpeech(partOfSpeech, variantID)
        } label: {
            HStack(spacing: 4) {
                if isSelected {
                    Image(systemName: "checkmark")
                }
                Text(verbatim: partOfSpeech.localizedName())
            }
            .font(.subheadline)
            .padding(.horizontal, 12)
            .frame(minHeight: 44)
            .background(
                isSelected ? Color.accentColor.opacity(0.18) : Color.secondary.opacity(0.1),
                in: Capsule()
            )
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier(
            "editor.english.\(position(of: variantID) - 1).partOfSpeech.\(partOfSpeech.rawValue)"
        )
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    @ViewBuilder
    private func lookupStatus(for variantID: UUID) -> some View {
        switch lookupState[variantID] {
        case .loading:
            ProgressView()
                .controlSize(.small)
                .accessibilityLabel("editor.lookup.loading")
        case .suggested:
            Label("editor.lookup.suggested", systemImage: "checkmark.circle")
                .font(.footnote)
                .foregroundStyle(.secondary)
        case .notFound:
            Label("editor.lookup.notFound", systemImage: "questionmark.circle")
                .font(.footnote)
                .foregroundStyle(.secondary)
        case .failed:
            Label("editor.lookup.failed", systemImage: "wifi.exclamationmark")
                .font(.footnote)
                .foregroundStyle(.orange)
        case nil:
            EmptyView()
        }
    }

    private func position(of id: UUID) -> Int {
        variants.firstIndex { $0.id == id }.map { $0 + 1 } ?? 1
    }
}
