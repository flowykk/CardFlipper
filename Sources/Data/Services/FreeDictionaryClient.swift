import Core
import Foundation

public final class FreeDictionaryClient: DictionaryService {
    private let session: URLSession
    private let timeout: TimeInterval
    private let decoder: JSONDecoder

    public init(
        session: URLSession = .shared,
        timeout: TimeInterval = 5,
        decoder: JSONDecoder = .init()
    ) {
        self.session = session
        self.timeout = timeout
        self.decoder = decoder
    }

    public func suggestion(for text: String) async throws -> DictionarySuggestion? {
        guard var components = URLComponents(
            string: "https://api.dictionaryapi.dev/api/v2/entries/en/"
        ) else {
            throw DictionaryServiceError.invalidRequest
        }
        components.path += text
        guard let url = components.url else {
            throw DictionaryServiceError.invalidRequest
        }

        var request = URLRequest(url: url)
        request.timeoutInterval = timeout
        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await session.data(for: request)
        } catch {
            try Task.checkCancellation()
            throw error
        }

        guard let httpResponse = response as? HTTPURLResponse else {
            throw DictionaryServiceError.invalidResponse
        }
        if httpResponse.statusCode == 404 {
            return nil
        }
        guard 200..<300 ~= httpResponse.statusCode else {
            throw DictionaryServiceError.server(httpResponse.statusCode)
        }

        return try decoder.decode([DictionaryEntryDTO].self, from: data).first?.suggestion
    }
}
