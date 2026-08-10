import Foundation
import Testing
@testable import Core
@testable import Data

@Suite(.serialized)
struct FreeDictionaryClientTests {
    init() {
        URLProtocolStub.reset()
    }

    @Test
    func mapsFirstNonEmptyIPAAndFirstPartOfSpeech() async throws {
        URLProtocolStub.responseData = Data(
            #"[{"word":"hello","phonetic":"həˈləʊ","phonetics":[{"text":"ignored"}],"meanings":[{"partOfSpeech":"exclamation","definitions":[]},{"partOfSpeech":"noun","definitions":[]}]}]"#.utf8
        )

        let suggestion = try await FreeDictionaryClient(
            session: .stubbed,
            timeout: 2
        ).suggestion(for: "hello")

        #expect(suggestion == .init(ipa: "həˈləʊ", partOfSpeech: .interjection))
    }

    @Test
    func fallsBackToFirstNonEmptyPhoneticsIPA() async throws {
        URLProtocolStub.responseData = Data(
            #"[{"word":"hello","phonetic":"  ","phonetics":[{}, {"text":""}, {"text":"həˈləʊ"}, {"text":"ignored"}],"meanings":[]}]"#.utf8
        )

        let suggestion = try await FreeDictionaryClient(session: .stubbed)
            .suggestion(for: "hello")

        #expect(suggestion == .init(ipa: "həˈləʊ", partOfSpeech: nil))
    }

    @Test
    func notFoundReturnsNil() async throws {
        URLProtocolStub.statusCode = 404

        let suggestion = try await FreeDictionaryClient(session: .stubbed)
            .suggestion(for: "missing")

        #expect(suggestion == nil)
    }

    @Test
    func emptyEntriesReturnNil() async throws {
        let suggestion = try await FreeDictionaryClient(session: .stubbed)
            .suggestion(for: "missing")

        #expect(suggestion == nil)
    }

    @Test
    func invalidJSONRemainsADecodingError() async {
        URLProtocolStub.responseData = Data(#"{"unexpected":true}"#.utf8)

        await #expect(throws: DecodingError.self) {
            try await FreeDictionaryClient(session: .stubbed).suggestion(for: "hello")
        }
    }

    @Test
    func serverFailureIncludesStatusCode() async {
        URLProtocolStub.statusCode = 503

        await #expect(throws: DictionaryServiceError.server(503)) {
            try await FreeDictionaryClient(session: .stubbed).suggestion(for: "hello")
        }
    }

    @Test
    func transportTimeoutRemainsAURLError() async {
        URLProtocolStub.responseError = URLError(.timedOut)

        do {
            _ = try await FreeDictionaryClient(session: .stubbed).suggestion(for: "hello")
            Issue.record("Expected the transport timeout to be thrown")
        } catch let error as URLError {
            #expect(error.code == .timedOut)
        } catch {
            Issue.record("Expected URLError.timedOut, got \(error)")
        }
    }

    @Test
    func appliesConfiguredTimeoutAndEncodesTheLookupPath() async throws {
        let recorder = RequestRecorder()
        URLProtocolStub.requestObserver = { recorder.record($0) }

        _ = try await FreeDictionaryClient(session: .stubbed, timeout: 2)
            .suggestion(for: "ice café")

        #expect(recorder.request?.timeoutInterval == 2)
        #expect(
            recorder.request?.url?.absoluteString
                == "https://api.dictionaryapi.dev/api/v2/entries/en/ice%20caf%C3%A9"
        )
    }

    @Test
    func encodesReservedDelimiterWithinTheLookupPathSegment() async throws {
        let recorder = RequestRecorder()
        URLProtocolStub.requestObserver = { recorder.record($0) }

        _ = try await FreeDictionaryClient(session: .stubbed)
            .suggestion(for: "and/or")

        #expect(
            recorder.request?.url?.absoluteString
                == "https://api.dictionaryapi.dev/api/v2/entries/en/and%2For"
        )
    }

    @Test
    func cancellationRemainsCancellation() async throws {
        let recorder = RequestRecorder()
        URLProtocolStub.requestObserver = { recorder.record($0) }
        URLProtocolStub.waitsForCancellation = true
        let task = Task {
            try await FreeDictionaryClient(session: .stubbed).suggestion(for: "hello")
        }
        defer { task.cancel() }

        for _ in 0..<1_000 where recorder.request == nil {
            await Task.yield()
        }
        try #require(recorder.request != nil)
        task.cancel()

        await #expect(throws: CancellationError.self) {
            try await task.value
        }
    }
}
