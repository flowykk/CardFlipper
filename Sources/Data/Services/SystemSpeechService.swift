import AVFoundation
import Core

@MainActor
public final class SystemSpeechService: SpeechService {
    private let synthesizer = AVSpeechSynthesizer()

    public init() {}

    public func speak(_ text: String) {
        synthesizer.stopSpeaking(at: .immediate)
        let utterance = AVSpeechUtterance(string: text)
        utterance.voice = AVSpeechSynthesisVoice(language: "en-GB")
        synthesizer.speak(utterance)
    }
}
