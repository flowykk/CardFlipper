@MainActor
public protocol SpeechService: AnyObject {
    func speak(_ text: String)
}
