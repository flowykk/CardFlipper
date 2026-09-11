import SwiftUI
import Testing
@testable import DesignSystem

@Test func standardContentSizesKeepHorizontalControls() {
    #expect(!AdaptiveControlLayout.usesVerticalControls(
        dynamicTypeSize: .large,
        horizontalSizeClass: .compact
    ))
    #expect(!AdaptiveControlLayout.usesVerticalControls(
        dynamicTypeSize: .xxxLarge,
        horizontalSizeClass: .regular
    ))
}

@Test func accessibilityContentSizesUseVerticalControls() {
    for size in DynamicTypeSize.allCases where size.isAccessibilitySize {
        #expect(AdaptiveControlLayout.usesVerticalControls(
            dynamicTypeSize: size,
            horizontalSizeClass: .compact
        ))
    }
}
