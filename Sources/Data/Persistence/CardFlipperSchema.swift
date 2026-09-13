import SwiftData

enum CardFlipperSchemaV1: VersionedSchema {
    static let versionIdentifier = Schema.Version(1, 0, 0)
    static let models: [any PersistentModel.Type] = [
        CardEntity.self,
        RussianMeaningEntity.self,
        EnglishVariantEntity.self,
        UsageExampleEntity.self,
        TagEntity.self,
    ]
}

enum CardFlipperSchemaV2: VersionedSchema {
    static let versionIdentifier = Schema.Version(2, 0, 0)
    static let models: [any PersistentModel.Type] = [
        CardEntity.self,
        RussianMeaningEntity.self,
        EnglishVariantEntity.self,
        UsageExampleEntity.self,
        TagEntity.self,
        StudyHistoryEntity.self,
    ]
}

enum CardFlipperMigrationPlan: SchemaMigrationPlan {
    static let schemas: [any VersionedSchema.Type] = [
        CardFlipperSchemaV1.self,
        CardFlipperSchemaV2.self,
    ]

    static let stages: [MigrationStage] = [
        .lightweight(
            fromVersion: CardFlipperSchemaV1.self,
            toVersion: CardFlipperSchemaV2.self
        ),
    ]
}

enum CardFlipperSchema {
    static let schema = Schema(versionedSchema: CardFlipperSchemaV2.self)
}
