import SwiftData

public enum ModelContainerFactory {
    public static func makeDefault() throws -> ModelContainer {
        try makeContainer(isStoredInMemoryOnly: false)
    }

    public static func makeInMemory() throws -> ModelContainer {
        try makeContainer(isStoredInMemoryOnly: true)
    }

    private static func makeContainer(isStoredInMemoryOnly: Bool) throws -> ModelContainer {
        let configuration = ModelConfiguration(
            schema: CardFlipperSchema.schema,
            isStoredInMemoryOnly: isStoredInMemoryOnly
        )
        return try ModelContainer(
            for: CardFlipperSchema.schema,
            configurations: [configuration]
        )
    }
}
