import Foundation
import SwiftData
@testable import Core
@testable import Data

final class URLProtocolStub: URLProtocol, @unchecked Sendable {
    nonisolated(unsafe) static var statusCode = 200
    nonisolated(unsafe) static var responseData = Data("[]".utf8)
    nonisolated(unsafe) static var responseError: Error?
    nonisolated(unsafe) static var requestObserver: (@Sendable (URLRequest) -> Void)?
    nonisolated(unsafe) static var waitsForCancellation = false

    static func reset() {
        statusCode = 200
        responseData = Data("[]".utf8)
        responseError = nil
        requestObserver = nil
        waitsForCancellation = false
    }

    override class func canInit(with request: URLRequest) -> Bool {
        true
    }

    override class func canonicalRequest(for request: URLRequest) -> URLRequest {
        request
    }

    override func startLoading() {
        Self.requestObserver?(request)

        if Self.waitsForCancellation {
            return
        }

        if let error = Self.responseError {
            client?.urlProtocol(self, didFailWithError: error)
            return
        }

        let response = HTTPURLResponse(
            url: request.url!,
            statusCode: Self.statusCode,
            httpVersion: nil,
            headerFields: ["Content-Type": "application/json"]
        )!
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: Self.responseData)
        client?.urlProtocolDidFinishLoading(self)
    }

    override func stopLoading() {}
}

extension URLSession {
    static var stubbed: URLSession {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [URLProtocolStub.self]
        return URLSession(configuration: configuration)
    }
}

final class RequestRecorder: @unchecked Sendable {
    private let lock = NSLock()
    private var storedRequest: URLRequest?

    var request: URLRequest? {
        lock.withLock { storedRequest }
    }

    func record(_ request: URLRequest) {
        lock.withLock {
            storedRequest = request
        }
    }
}

enum TestIDs {
    static let card = UUID(uuidString: "00000000-0000-0000-0000-000000000101")!
    static let russianMeaningOne = UUID(uuidString: "00000000-0000-0000-0000-000000000102")!
    static let russianMeaningTwo = UUID(uuidString: "00000000-0000-0000-0000-000000000103")!
    static let englishVariantOne = UUID(uuidString: "00000000-0000-0000-0000-000000000104")!
    static let englishVariantTwo = UUID(uuidString: "00000000-0000-0000-0000-000000000105")!
    static let secondCard = UUID(uuidString: "00000000-0000-0000-0000-000000000108")!
    static let secondRussianMeaning = UUID(uuidString: "00000000-0000-0000-0000-000000000109")!
    static let secondEnglishVariant = UUID(uuidString: "00000000-0000-0000-0000-000000000110")!
}

enum TestDates {
    static let created = Date(timeIntervalSince1970: 1_000)
    static let updated = Date(timeIntervalSince1970: 2_000)
}

extension VocabularyCard {
    static func fixture(
        id: UUID = TestIDs.card,
        tag: Tag? = nil
    ) -> VocabularyCard {
        VocabularyCard(
            id: id,
            russianMeanings: [
                RussianMeaning(id: TestIDs.russianMeaningOne, text: "работа"),
                RussianMeaning(id: TestIDs.russianMeaningTwo, text: "труд"),
            ],
            englishVariants: [
                EnglishVariant(
                    id: TestIDs.englishVariantOne,
                    text: "work",
                    ipa: "wɜːk",
                    partsOfSpeech: [.noun, .verb]
                ),
                EnglishVariant(
                    id: TestIDs.englishVariantTwo,
                    text: "labour",
                    ipa: nil,
                    partsOfSpeech: [.noun]
                ),
            ],
            tags: tag.map { [$0] } ?? [],
            createdAt: TestDates.created,
            updatedAt: TestDates.updated
        )
    }

    static func singleValueFixture(
        id: UUID,
        russianMeaningID: UUID,
        englishVariantID: UUID,
        russian: String,
        english: String,
        updatedAt: Date
    ) -> VocabularyCard {
        VocabularyCard(
            id: id,
            russianMeanings: [RussianMeaning(id: russianMeaningID, text: russian)],
            englishVariants: [
                EnglishVariant(
                    id: englishVariantID,
                    text: english,
                    ipa: nil,
                    partsOfSpeech: []
                ),
            ],
            tags: [],
            createdAt: TestDates.created,
            updatedAt: updatedAt
        )
    }
}

@MainActor
struct TestRepositories {
    let cards: SwiftDataCardRepository
    let tags: SwiftDataTagRepository

    init(container: ModelContainer) {
        cards = SwiftDataCardRepository(container: container)
        tags = SwiftDataTagRepository(container: container)
    }
}
