import SwiftUI
import Testing
@testable import DesignSystem

@Test func curatedAccentsMeetTextContrastInBothSchemes() {
    #expect(AccessibleAccent.all.count >= 5)

    for accent in AccessibleAccent.all {
        for scheme in [ColorScheme.light, .dark] {
            #expect(
                accent.preferredForegroundContrastRatio(for: scheme) >= 4.5,
                "\(accent.id) failed \(scheme) contrast"
            )
        }
    }
}

@Test func curatedAccentSelectionHasStableUniqueIdentifiers() {
    #expect(Set(AccessibleAccent.all.map(\.id)).count == AccessibleAccent.all.count)
    #expect(AccessibleAccent.all.first?.id == "system")
}
