import SwiftUI

struct SettingsView: View {
    @Environment(\.scenePhase) private var scenePhase
    @Bindable var settings: AppearanceSettings
    @Bindable var iconSettings: AppIconSettings
    let onExportCards: () -> Void
    let onImportCards: () -> Void

    init(
        settings: AppearanceSettings,
        iconSettings: AppIconSettings,
        onExportCards: @escaping () -> Void = {},
        onImportCards: @escaping () -> Void = {}
    ) {
        _settings = Bindable(wrappedValue: settings)
        _iconSettings = Bindable(wrappedValue: iconSettings)
        self.onExportCards = onExportCards
        self.onImportCards = onImportCards
    }

    var body: some View {
        Form {
            Section("settings.appearance") {
                ColorPicker(
                    "settings.interfaceColor",
                    selection: $settings.accentColor,
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
                            Button {
                                Task { await iconSettings.select(icon) }
                            } label: {
                                AppIconPreview(
                                    icon: icon,
                                    isSelected: icon == iconSettings.selectedIcon,
                                    isPending: icon == iconSettings.pendingIcon
                                )
                            }
                            .frame(width: 88)
                            .buttonStyle(.plain)
                            .disabled(iconSettings.isChanging || !iconSettings.supportsAlternateIcons)
                            .accessibilityLabel(Text(icon.titleKey))
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
                }
            }

            Section("settings.cards") {
                Button(action: onExportCards) {
                    Label("settings.cards.export", systemImage: "square.and.arrow.up")
                }
                Button(action: onImportCards) {
                    Label("settings.cards.import", systemImage: "square.and.arrow.down")
                }
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
            Button("common.close", role: .cancel) { iconSettings.errorMessage = nil }
        } message: {
            Text(iconSettings.errorMessage ?? "")
        }
    }
}

private struct AppIconPreview: View {
    let icon: AppIconSettings.AppIcon
    let isSelected: Bool
    let isPending: Bool

    var body: some View {
        VStack(spacing: 8) {
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
            Text(icon.titleKey)
                .font(.caption)
                .foregroundStyle(isSelected ? Color.accentColor : .primary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .contentShape(Rectangle())
        .accessibilityElement(children: .ignore)
    }
}
