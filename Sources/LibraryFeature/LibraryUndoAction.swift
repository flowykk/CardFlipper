import Core
import Foundation

public enum LibraryUndoAction: Equatable, Sendable {
    case learningStatus(cardID: UUID, previousValue: Bool)
    case deletedCard(VocabularyCard)
}
