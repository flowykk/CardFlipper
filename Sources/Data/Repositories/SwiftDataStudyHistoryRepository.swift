import Core
import Foundation
import SwiftData

public enum SwiftDataStudyHistoryRepositoryError: Error, Equatable, Sendable {
    case invalidMode(sessionID: UUID, rawValue: String)
    case invalidDirection(sessionID: UUID, rawValue: String)
    case invalidSelectedTagNames(sessionID: UUID)
    case invalidDifficultCardTitles(sessionID: UUID)
}

@MainActor
public final class SwiftDataStudyHistoryRepository: StudyHistoryRepository {
    private let retainedContainer: ModelContainer
    private let context: ModelContext
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    public init(container: ModelContainer) {
        retainedContainer = container
        context = container.mainContext
    }

    public func fetchHistory() throws -> [StudyHistoryEntry] {
        let descriptor = FetchDescriptor<StudyHistoryEntity>(
            sortBy: [SortDescriptor(\.completedAt, order: .reverse)]
        )
        return try context.fetch(descriptor).map(makeEntry)
    }

    @discardableResult
    public func insertIfNeeded(_ entry: StudyHistoryEntry) throws -> Bool {
        guard try fetchEntity(sessionID: entry.id) == nil else { return false }

        let entity = StudyHistoryEntity(
            sessionID: entry.id,
            startedAt: entry.startedAt,
            completedAt: entry.completedAt,
            modeRawValue: entry.mode.rawValue,
            directionRawValue: entry.direction.rawValue,
            selectedTagNamesData: try encoder.encode(entry.selectedTagNames),
            plannedCardCount: entry.plannedCardCount,
            completedCardCount: entry.completedCardCount,
            encounteredCardCount: entry.encounteredCardCount,
            repeatedCardCount: entry.repeatedCardCount,
            forgottenCount: entry.forgottenCount,
            totalAssessmentCount: entry.totalAssessmentCount,
            elapsedSeconds: entry.elapsedSeconds,
            difficultCardTitlesData: try encoder.encode(entry.difficultCardTitles)
        )
        context.insert(entity)

        do {
            try context.save()
            return true
        } catch {
            context.rollback()
            throw error
        }
    }

    private func fetchEntity(sessionID: UUID) throws -> StudyHistoryEntity? {
        let descriptor = FetchDescriptor<StudyHistoryEntity>(
            predicate: #Predicate { $0.sessionID == sessionID }
        )
        return try context.fetch(descriptor).first
    }

    private func makeEntry(from entity: StudyHistoryEntity) throws -> StudyHistoryEntry {
        guard let mode = StudyMode(rawValue: entity.modeRawValue) else {
            throw SwiftDataStudyHistoryRepositoryError.invalidMode(
                sessionID: entity.sessionID,
                rawValue: entity.modeRawValue
            )
        }
        guard let direction = StudyDirection(rawValue: entity.directionRawValue) else {
            throw SwiftDataStudyHistoryRepositoryError.invalidDirection(
                sessionID: entity.sessionID,
                rawValue: entity.directionRawValue
            )
        }

        let selectedTagNames: [String]
        do {
            selectedTagNames = try decoder.decode([String].self, from: entity.selectedTagNamesData)
        } catch {
            throw SwiftDataStudyHistoryRepositoryError.invalidSelectedTagNames(
                sessionID: entity.sessionID
            )
        }

        let difficultCardTitles: [String]
        do {
            difficultCardTitles = try decoder.decode(
                [String].self,
                from: entity.difficultCardTitlesData
            )
        } catch {
            throw SwiftDataStudyHistoryRepositoryError.invalidDifficultCardTitles(
                sessionID: entity.sessionID
            )
        }

        return StudyHistoryEntry(
            id: entity.sessionID,
            startedAt: entity.startedAt,
            completedAt: entity.completedAt,
            mode: mode,
            direction: direction,
            selectedTagNames: selectedTagNames,
            plannedCardCount: entity.plannedCardCount,
            completedCardCount: entity.completedCardCount,
            encounteredCardCount: entity.encounteredCardCount,
            repeatedCardCount: entity.repeatedCardCount,
            forgottenCount: entity.forgottenCount,
            totalAssessmentCount: entity.totalAssessmentCount,
            elapsedSeconds: entity.elapsedSeconds,
            difficultCardTitles: difficultCardTitles
        )
    }
}
