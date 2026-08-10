import SwiftUI

struct SettingsView: View {
    @Bindable var settings: AppearanceSettings

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
        }
        .navigationTitle("settings.title")
    }
}
