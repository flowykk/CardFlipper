import Core
import SwiftUI

public struct EnglishVariantsSection: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Binding private var variants: [EnglishVariantInput]
    @Binding private var expandedMetadataVariantIDs: Set<UUID>
    @FocusState private var focusedVariantID: UUID?
    @State private var blurredVariantIDs: Set<UUID> = []
    @State private var partOfSpeechPickerVariantID: UUID?

    private let lookupState: [UUID: LookupState]
    private let showsValidationError: Bool
    private let onAdd: () -> Void
    private let onRemove: (UUID) -> Void
    private let onTextChanged: (UUID) -> Void
    private let onLookup: (UUID) -> Void
    private let onSpeak: (UUID) -> Void
    private let onIPAChanged: (UUID) -> Void
    private let onToggleMetadata: (UUID) -> Void
    private let onTogglePartOfSpeech: (PartOfSpeech, UUID) -> Void
    private let onAddUsageExample: (UUID) -> Void
    private let onRemoveUsageExample: (UUID, UUID) -> Void
    private let onSpeakUsageExample: (UUID, UUID) -> Void
    private let onChooseUsageExamplePart: (PartOfSpeech, UUID, UUID) -> Void
    private let onUseSuggestion: (UUID) -> Void
    private let accessibilityLabels = EditorAccessibilityLabels()

    public init(
        variants: Binding<[EnglishVariantInput]>,
        expandedMetadataVariantIDs: Binding<Set<UUID>>,
        lookupState: [UUID: LookupState],
        showsValidationError: Bool,
        onAdd: @escaping () -> Void,
        onRemove: @escaping (UUID) -> Void,
        onTextChanged: @escaping (UUID) -> Void,
        onLookup: @escaping (UUID) -> Void,
        onSpeak: @escaping (UUID) -> Void,
        onIPAChanged: @escaping (UUID) -> Void,
        onToggleMetadata: @escaping (UUID) -> Void,
        onTogglePartOfSpeech: @escaping (PartOfSpeech, UUID) -> Void,
        onAddUsageExample: @escaping (UUID) -> Void,
        onRemoveUsageExample: @escaping (UUID, UUID) -> Void,
        onSpeakUsageExample: @escaping (UUID, UUID) -> Void,
        onChooseUsageExamplePart: @escaping (PartOfSpeech, UUID, UUID) -> Void,
        onUseSuggestion: @escaping (UUID) -> Void
    ) {
        _variants = variants
        _expandedMetadataVariantIDs = expandedMetadataVariantIDs
        self.lookupState = lookupState
        self.showsValidationError = showsValidationError
        self.onAdd = onAdd
        self.onRemove = onRemove
        self.onTextChanged = onTextChanged
        self.onLookup = onLookup
        self.onSpeak = onSpeak
        self.onIPAChanged = onIPAChanged
        self.onToggleMetadata = onToggleMetadata
        self.onTogglePartOfSpeech = onTogglePartOfSpeech
        self.onAddUsageExample = onAddUsageExample
        self.onRemoveUsageExample = onRemoveUsageExample
        self.onSpeakUsageExample = onSpeakUsageExample
        self.onChooseUsageExamplePart = onChooseUsageExamplePart
        self.onUseSuggestion = onUseSuggestion
    }

    public var body: some View {
        Section {
            ForEach($variants) { $variant in
                let isExpanded = expandedMetadataVariantIDs.contains(variant.id)

                VStack(alignment: .leading, spacing: 12) {
                    adaptiveInputRow(variant: $variant)

                    Button {
                        toggleMetadata(for: variant.id)
                    } label: {
                        Label {
                            Text(isExpanded ? "editor.details.less" : "editor.details.more")
                        } icon: {
                            Image(
                                systemName: isExpanded
                                    ? "chevron.up.circle"
                                    : "slider.horizontal.3"
                            )
                            .contentTransition(
                                reduceMotion ? .opacity : .symbolEffect(.replace)
                            )
                        }
                        .frame(minHeight: 44)
                    }
                    .accessibilityIdentifier("editor.english.\(position(of: variant.id) - 1).details")
                }
                .padding(.vertical, 4)
                .buttonStyle(.borderless)

                if isExpanded {
                    VStack(alignment: .leading, spacing: 12) {
                        metadataEditor(variant: $variant)
                    }
                    .padding(.vertical, 4)
                    .buttonStyle(.borderless)
                    .transition(metadataTransition)
                }
            }

            Button(action: onAdd) {
                Label("editor.english.add", systemImage: "plus.circle")
            }
            .accessibilityIdentifier("editor.english.add")

            if shouldShowValidationError {
                Label("editor.english.required", systemImage: "exclamationmark.circle")
                    .font(.footnote)
                    .foregroundStyle(.red)
                    .accessibilityLabel("editor.english.required")
            }
        } header: {
            Text("editor.english.title")
        }
        .onChange(of: focusedVariantID) { oldValue, _ in
            if let oldValue {
                blurredVariantIDs.insert(oldValue)
            }
        }
        .sheet(isPresented: partOfSpeechPickerPresented) {
            if let variantID = partOfSpeechPickerVariantID,
               let variant = variants.first(where: { $0.id == variantID }) {
                NavigationStack {
                    PartOfSpeechPicker(
                        selected: variant.partsOfSpeech,
                        onToggle: { onTogglePartOfSpeech($0, variantID) },
                        identifierPrefix: "editor.english.\(position(of: variantID) - 1).partOfSpeech"
                    )
                    .toolbar {
                        ToolbarItem(placement: .confirmationAction) {
                            Button("common.done") {
                                partOfSpeechPickerVariantID = nil
                            }
                        }
                    }
                }
            }
        }
    }

    private func toggleMetadata(for variantID: UUID) {
        let isExpanding = !expandedMetadataVariantIDs.contains(variantID)
        let animation: Animation = reduceMotion
            ? .easeOut(duration: 0.15)
            : isExpanding
                ? .smooth(duration: 0.34)
                : .easeOut(duration: 0.24)

        withAnimation(animation) {
            onToggleMetadata(variantID)
        }
    }

    private var metadataTransition: AnyTransition {
        reduceMotion
            ? .opacity
            : .move(edge: .top).combined(with: .opacity)
    }

    @ViewBuilder
    private func adaptiveInputRow(variant: Binding<EnglishVariantInput>) -> some View {
        let id = variant.wrappedValue.id
        ViewThatFits(in: .horizontal) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                englishField(variant: variant)
                    .frame(minWidth: 200)
                actionButtons(for: id, text: variant.wrappedValue.text)
            }
            VStack(alignment: .leading, spacing: 4) {
                englishField(variant: variant)
                actionButtons(for: id, text: variant.wrappedValue.text)
                    .frame(maxWidth: .infinity, alignment: .trailing)
            }
        }
    }

    private func englishField(variant: Binding<EnglishVariantInput>) -> some View {
        let id = variant.wrappedValue.id
        return TextField("editor.english.placeholder", text: variant.text)
            .textInputAutocapitalization(.never)
            .autocorrectionDisabled()
            .focused($focusedVariantID, equals: id)
            .accessibilityLabel("editor.english.value")
            .accessibilityIdentifier("editor.english.\(position(of: id) - 1)")
            .onChange(of: variant.wrappedValue.text) {
                onTextChanged(id)
            }
    }

    private func actionButtons(for id: UUID, text: String) -> some View {
        HStack(spacing: 0) {
            Button {
                onSpeak(id)
            } label: {
                Image(systemName: "speaker.wave.2")
                    .frame(minWidth: 44, minHeight: 44)
            }
            .buttonStyle(.plain)
            .disabled(text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            .accessibilityLabel(Text(verbatim: accessibilityLabels.speakEnglishVariant(
                position: position(of: id)
            )))

            Button(role: .destructive) {
                onRemove(id)
            } label: {
                Image(systemName: "minus.circle")
                    .frame(minWidth: 44, minHeight: 44)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(Text(verbatim: accessibilityLabels.removeEnglishVariant(
                position: position(of: id)
            )))
        }
    }

    @ViewBuilder
    private func metadataEditor(variant: Binding<EnglishVariantInput>) -> some View {
        let id = variant.wrappedValue.id

        TextField(
            "editor.ipa.placeholder",
            text: Binding(
                get: { variant.wrappedValue.ipa },
                set: { value in
                    variant.wrappedValue.ipa = value
                    onIPAChanged(id)
                }
            )
        )
            .textInputAutocapitalization(.never)
            .autocorrectionDisabled()
            .accessibilityLabel("editor.ipa.value")
            .accessibilityIdentifier("editor.ipa.\(position(of: id) - 1)")

        if !variant.wrappedValue.partsOfSpeech.isEmpty {
            ViewThatFits(in: .horizontal) {
                HStack(spacing: 6) {
                    selectedPartLabels(for: variant.wrappedValue)
                }
                VStack(alignment: .leading, spacing: 6) {
                    selectedPartLabels(for: variant.wrappedValue)
                }
            }
        }

        Button {
            partOfSpeechPickerVariantID = id
        } label: {
            Label("editor.partOfSpeech.choose", systemImage: "textformat")
        }
        .accessibilityIdentifier("editor.english.\(position(of: id) - 1).partOfSpeechPicker")

        UsageExamplesEditor(
            variant: variant,
            variantPosition: position(of: id),
            onAdd: { onAddUsageExample(id) },
            onRemove: { onRemoveUsageExample($0, id) },
            onSpeak: { onSpeakUsageExample($0, id) },
            onChoosePartOfSpeech: {
                onChooseUsageExamplePart($0, $1, id)
            }
        )

        HStack {
            lookupStatus(for: id)
            Spacer()
            if lookupState[id] == .conflict {
                Button("editor.lookup.useSuggestion") {
                    onUseSuggestion(id)
                }
                .accessibilityIdentifier("editor.english.\(position(of: id) - 1).useSuggestion")
            } else if lookupState[id] == .failed {
                Button("common.retry") {
                    onLookup(id)
                }
            }
        }
    }

    @ViewBuilder
    private func selectedPartLabels(for variant: EnglishVariantInput) -> some View {
        ForEach(variant.partsOfSpeech, id: \.rawValue) { partOfSpeech in
            Label(partOfSpeech.localizedName(), systemImage: "checkmark.circle.fill")
                .font(.caption)
                .foregroundStyle(Color.accentColor)
                .accessibilityElement(children: .combine)
                .accessibilityIdentifier(
                    "editor.english.\(position(of: variant.id) - 1).partOfSpeech.\(partOfSpeech.rawValue)"
                )
        }
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
        case .conflict:
            Label("editor.lookup.conflict", systemImage: "person.crop.circle.badge.exclamationmark")
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

    private var shouldShowValidationError: Bool {
        showsValidationError || (
            !blurredVariantIDs.isEmpty
                && variants.allSatisfy { $0.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
        )
    }

    private var partOfSpeechPickerPresented: Binding<Bool> {
        Binding(
            get: { partOfSpeechPickerVariantID != nil },
            set: { isPresented in
                if !isPresented {
                    partOfSpeechPickerVariantID = nil
                }
            }
        )
    }

    private func position(of id: UUID) -> Int {
        variants.firstIndex { $0.id == id }.map { $0 + 1 } ?? 1
    }
}
