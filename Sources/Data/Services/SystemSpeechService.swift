import AVFoundation
import Core

@MainActor
protocol SpeechAudioSession: AnyObject {
    func configure(
        _ category: AVAudioSession.Category,
        mode: AVAudioSession.Mode,
        options: AVAudioSession.CategoryOptions
    ) throws
    func activate() throws
}

extension AVAudioSession: SpeechAudioSession {
    func configure(
        _ category: AVAudioSession.Category,
        mode: AVAudioSession.Mode,
        options: AVAudioSession.CategoryOptions
    ) throws {
        try setCategory(category, mode: mode, options: options)
    }

    func activate() throws {
        try setActive(true, options: [])
    }
}

@MainActor
public final class SystemSpeechService: SpeechService {
    private let synthesizer = AVSpeechSynthesizer()
    private let audioSession: any SpeechAudioSession

    public convenience init() {
        self.init(audioSession: AVAudioSession.sharedInstance())
    }

    init(audioSession: any SpeechAudioSession) {
        self.audioSession = audioSession
    }

    public func speak(_ text: String) {
        try? audioSession.configure(
            .playback,
            mode: .spokenAudio,
            options: [.mixWithOthers]
        )
        try? audioSession.activate()
        synthesizer.stopSpeaking(at: .immediate)
        let utterance = AVSpeechUtterance(string: text)
        utterance.voice = AVSpeechSynthesisVoice(language: "en-GB")
        synthesizer.speak(utterance)
    }
}
