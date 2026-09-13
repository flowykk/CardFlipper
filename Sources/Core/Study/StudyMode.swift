public enum StudyMode: String, Codable, Equatable, Sendable {
    case flashcards
    case writing
}

public enum WritingAnswerEvaluation: String, Codable, Equatable, Sendable {
    case unanswered
    case incorrect
    case correct
}
