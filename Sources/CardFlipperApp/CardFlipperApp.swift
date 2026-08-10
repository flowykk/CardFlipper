import SwiftUI

@main
struct CardFlipperApp: App {
    @State private var startup = AppStartupState()

    var body: some Scene {
        WindowGroup {
            AppStartupView(startup: startup)
        }
    }
}
