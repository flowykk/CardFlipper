import SwiftUI

public enum AdaptiveControlLayout {
    public static func usesVerticalControls(
        dynamicTypeSize: DynamicTypeSize,
        horizontalSizeClass: UserInterfaceSizeClass?
    ) -> Bool {
        dynamicTypeSize.isAccessibilitySize
            || (horizontalSizeClass == .compact && dynamicTypeSize >= .xxxLarge)
    }
}
