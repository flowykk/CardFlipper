import Foundation
import Testing
@testable import Core

@Test func updatingTagsPreservesEveryOtherCardValue() {
    let original = VocabularyCard.fixture(isLearned: true)
    let tag = Tag(id: TestFixtures.tagID, name: "Work")

    let updated = original.updating(tags: [tag])

    #expect(updated.id == original.id)
    #expect(updated.russianMeanings == original.russianMeanings)
    #expect(updated.englishVariants == original.englishVariants)
    #expect(updated.tags == [tag])
    #expect(updated.createdAt == original.createdAt)
    #expect(updated.updatedAt == original.updatedAt)
    #expect(updated.isLearned == true)
}

@Test func updatingLearningStateAndDatePreservesTagsAndCreationDate() {
    let tag = Tag(id: TestFixtures.tagID, name: "Work")
    let original = VocabularyCard.fixture(tag: tag)
    let newDate = Date(timeIntervalSince1970: 2)

    let updated = original.updating(isLearned: true, updatedAt: newDate)

    #expect(updated.tags == original.tags)
    #expect(updated.createdAt == original.createdAt)
    #expect(updated.updatedAt == newDate)
    #expect(updated.isLearned == true)
}
