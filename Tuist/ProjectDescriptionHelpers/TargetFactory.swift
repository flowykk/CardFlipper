import ProjectDescription

public extension Target {
    static func framework(
        name: String,
        dependencies: [TargetDependency] = []
    ) -> Target {
        .target(
            name: name,
            destinations: .iOS,
            product: .staticFramework,
            bundleId: "com.danilarahmanov.CardFlipper.\(name)",
            deploymentTargets: .iOS("18.0"),
            infoPlist: .default,
            sources: ["Sources/\(name)/**"],
            dependencies: dependencies
        )
    }

    static func app(
        name: String,
        bundleId: String,
        dependencies: [String]
    ) -> Target {
        .target(
            name: name,
            destinations: .iOS,
            product: .app,
            bundleId: bundleId,
            deploymentTargets: .iOS("18.0"),
            infoPlist: .extendingDefault(with: [
                "NSSupportsLiveActivities": true,
                "UILaunchScreen": [:],
                "UISupportedInterfaceOrientations": ["UIInterfaceOrientationPortrait"],
            ]),
            sources: ["Sources/CardFlipperApp/**"],
            resources: [
                .glob(
                    pattern: "Resources/**",
                    excluding: [
                        "Resources/StatisticsFeature/**",
                        "Resources/StudyTimerWidget/**",
                    ]
                ),
            ],
            dependencies: dependencies.map { .target(name: $0) },
            settings: .settings(base: [
                "ASSETCATALOG_COMPILER_APPICON_NAME": "AppIcon",
                "ASSETCATALOG_COMPILER_ALTERNATE_APPICON_NAMES": "IconViolet3D IconOrange3D IconMint3D IconMidnight3D IconOrigami IconPixel IconOwl IconMonogram IconOrbit",
            ])
        )
    }

    static func tests(
        name: String,
        host: String,
        dependencies: [String] = []
    ) -> Target {
        .target(
            name: name,
            destinations: .iOS,
            product: .unitTests,
            bundleId: "com.danilarahmanov.CardFlipper.\(name)",
            deploymentTargets: .iOS("18.0"),
            infoPlist: .default,
            sources: ["Tests/\(name)/**"],
            dependencies: [.target(name: host)] + dependencies.map { .target(name: $0) }
        )
    }

    static func uiTests(
        name: String,
        host: String
    ) -> Target {
        .target(
            name: name,
            destinations: .iOS,
            product: .uiTests,
            bundleId: "com.danilarahmanov.CardFlipper.\(name)",
            deploymentTargets: .iOS("18.0"),
            infoPlist: .default,
            sources: ["Tests/\(name)/**"],
            dependencies: [.target(name: host)]
        )
    }
}
