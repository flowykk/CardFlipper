import DesignSystem
import SwiftUI
import UIKit

struct SettingsView: View {
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Bindable var settings: AppearanceSettings
    @Bindable var iconSettings: AppIconSettings
    let isPreparingExport: Bool
    let onExportCards: () -> Void
    let onImportCards: () -> Void
    @State private var isShowingAIImportHelp = false

    init(
        settings: AppearanceSettings,
        iconSettings: AppIconSettings,
        isPreparingExport: Bool = false,
        onExportCards: @escaping () -> Void = {},
        onImportCards: @escaping () -> Void = {}
    ) {
        _settings = Bindable(wrappedValue: settings)
        _iconSettings = Bindable(wrappedValue: iconSettings)
        self.isPreparingExport = isPreparingExport
        self.onExportCards = onExportCards
        self.onImportCards = onImportCards
    }

    var body: some View {
        Form {
            Section("settings.appearance") {
                ColorPicker(
                    "settings.interfaceColor",
                    selection: $settings.accentColor.withSelectionFeedback(),
                    supportsOpacity: false
                )
                .accessibilityIdentifier("settings.colorPicker")

                Label("settings.preview", systemImage: "paintpalette.fill")
                    .foregroundStyle(Color.accentColor)
            }

            Section {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(alignment: .top, spacing: 16) {
                        ForEach(AppIconSettings.AppIcon.allCases) { icon in
                            HapticButton(feedback: .selection) {
                                Task { await iconSettings.select(icon) }
                            } label: {
                                AppIconPreview(
                                    icon: icon,
                                    isSelected: icon == iconSettings.selectedIcon,
                                    isPending: icon == iconSettings.pendingIcon
                                )
                            }
                            .frame(width: iconTileWidth)
                            .buttonStyle(.plain)
                            .disabled(iconSettings.isChanging || !iconSettings.supportsAlternateIcons)
                            .accessibilityLabel(Text(icon.titleKey))
                            .accessibilityValue(iconAccessibilityValue(icon))
                            .accessibilityIdentifier(icon.accessibilityIdentifier)
                            .accessibilityAddTraits(icon == iconSettings.selectedIcon ? .isSelected : [])
                        }
                    }
                }
                .contentMargins(.horizontal, 16, for: .scrollContent)
                .accessibilityIdentifier("settings.iconPicker")
                .padding(.vertical, 8)
                .listRowInsets(EdgeInsets(top: 8, leading: 0, bottom: 8, trailing: 0))
            } header: {
                Text("settings.appIcon")
            } footer: {
                if !iconSettings.supportsAlternateIcons {
                    Text("settings.icon.unsupported")
                } else if iconSettings.errorMessage != nil {
                    Label("settings.icon.error.message", systemImage: "exclamationmark.triangle.fill")
                        .foregroundStyle(.red)
                }
            }

            Section("settings.cards") {
                HapticButton(action: onExportCards) {
                    if isPreparingExport {
                        HStack {
                            ProgressView()
                            Text("settings.cards.export.preparing")
                        }
                    } else {
                        Label("settings.cards.export", systemImage: AppSymbol.exportCards)
                    }
                }
                .disabled(isPreparingExport)
                HapticButton(action: onImportCards) {
                    Label("settings.cards.import", systemImage: AppSymbol.importCards)
                }
                HapticButton {
                    isShowingAIImportHelp = true
                } label: {
                    Label("settings.cards.aiHelp", systemImage: "info.circle")
                }
                .accessibilityIdentifier("settings.cards.aiHelp")
            }
        }
        .navigationTitle("settings.title")
        .onChange(of: scenePhase, initial: true) { _, phase in
            if phase == .active { iconSettings.refreshSelection() }
        }
        .alert("settings.icon.error.title", isPresented: Binding(
            get: { iconSettings.errorMessage != nil },
            set: { if !$0 { iconSettings.errorMessage = nil } }
        )) {
            HapticButton("common.close", role: .cancel) { iconSettings.errorMessage = nil }
        } message: {
            Text(iconSettings.errorMessage ?? "")
        }
        .sheet(isPresented: $isShowingAIImportHelp) {
            AIImportHelpView()
                .presentationDetents([.large])
        }
    }

    private var iconTileWidth: CGFloat { dynamicTypeSize.isAccessibilitySize ? 240 : 88 }

    private func iconAccessibilityValue(_ icon: AppIconSettings.AppIcon) -> Text {
        if icon == iconSettings.pendingIcon { return Text("settings.icon.pending") }
        if icon == iconSettings.selectedIcon { return Text("settings.icon.selected") }
        return Text("")
    }
}

private struct AppIconPreview: View {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    let icon: AppIconSettings.AppIcon
    let isSelected: Bool
    let isPending: Bool

    var body: some View {
        Group {
            if dynamicTypeSize.isAccessibilitySize {
                HStack(spacing: 12) { previewImage; title }
            } else {
                VStack(spacing: 8) { previewImage; title }
            }
        }
        .frame(maxWidth: .infinity, alignment: dynamicTypeSize.isAccessibilitySize ? .leading : .center)
        .contentShape(Rectangle())
        .accessibilityElement(children: .ignore)
    }

    private var previewImage: some View {
            Image(icon.previewAssetName)
                .resizable()
                .scaledToFit()
                .frame(width: 76, height: 76)
                .clipShape(RoundedRectangle(cornerRadius: 17, style: .continuous))
                .padding(4)
                .overlay {
                    RoundedRectangle(cornerRadius: 21, style: .continuous)
                        .strokeBorder(isSelected ? Color.accentColor : .clear, lineWidth: 2)
                }
                .overlay(alignment: .bottomTrailing) {
                    if isPending {
                        ProgressView()
                            .padding(5)
                            .background(.regularMaterial, in: Circle())
                    } else if isSelected {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.title3)
                            .symbolRenderingMode(.palette)
                            .foregroundStyle(.white, Color.accentColor)
                            .background(.background, in: Circle())
                    }
                }
    }

    private var title: some View {
        Text(icon.titleKey)
            .font(.caption)
            .foregroundStyle(.primary)
            .multilineTextAlignment(dynamicTypeSize.isAccessibilitySize ? .leading : .center)
            .fixedSize(horizontal: false, vertical: true)
    }
}

enum CardImportAIPrompt {
    static let exampleJSON = #"""
    {
      "version": 1,
      "cards": [
        {
          "id": "F0A1B2C3-D4E5-4678-9ABC-DEF012345678",
          "russianMeanings": [
            {
              "id": "1A2B3C4D-5E6F-4789-ABCD-EF0123456789",
              "text": "пример"
            }
          ],
          "englishVariants": [
            {
              "id": "2B3C4D5E-6F70-489A-BCDE-F0123456789A",
              "text": "example",
              "ipa": "ɪɡˈzɑːmpəl",
              "partsOfSpeechRawValues": ["noun"],
              "usageExamples": [
                {
                  "id": "3C4D5E6F-7081-49AB-CDEF-0123456789AB",
                  "text": "This sentence is an example.",
                  "partOfSpeechRawValue": "noun"
                }
              ]
            }
          ],
          "tags": [
            {
              "id": "4D5E6F70-8192-4ABC-DEF0-123456789ABC",
              "name": "AI import"
            }
          ],
          "createdAt": 0,
          "updatedAt": 0,
          "isLearned": false
        }
      ]
    }
    """#

    static func text(bundle: Bundle = .main) -> String {
        let format = bundle.localizedString(
            forKey: "settings.cards.aiHelp.prompt",
            value: "settings.cards.aiHelp.prompt",
            table: nil
        )
        return String(format: format, exampleJSON)
    }
}

private struct AIImportHelpView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var didCopyPrompt = false

    private let prompt = CardImportAIPrompt.text()

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    Text("settings.cards.aiHelp.instructions")
                        .font(.body)

                    Text(prompt)
                        .font(.callout.monospaced())
                        .textSelection(.enabled)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding()
                        .background(.secondary.opacity(0.12), in: RoundedRectangle(cornerRadius: 12))
                        .accessibilityIdentifier("settings.cards.aiHelp.prompt")
                }
                .padding()
            }
            .safeAreaInset(edge: .bottom) {
                HapticButton {
                    UIPasteboard.general.string = prompt
                    didCopyPrompt = true
                } label: {
                    Label {
                        Text(didCopyPrompt
                             ? "settings.cards.aiHelp.copied"
                             : "settings.cards.aiHelp.copy")
                    } icon: {
                        Image(systemName: didCopyPrompt ? "checkmark" : "doc.on.doc")
                    }
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .accessibilityIdentifier("settings.cards.aiHelp.copy")
                .padding(.horizontal)
                .padding(.top, 28)
                .padding(.bottom)
                .background {
                    LinearGradient(
                        colors: [
                            .clear,
                            Color(uiColor: .systemBackground).opacity(0.9),
                            Color(uiColor: .systemBackground),
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                    .ignoresSafeArea(edges: .bottom)
                }
            }
            .navigationTitle("settings.cards.aiHelp.title")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    HapticButton("common.close") { dismiss() }
                }
            }
        }
    }
}
