import AVFoundation
import Testing
@testable import Data

@MainActor
@Test func speakingConfiguresPlaybackThatIgnoresSilentMode() {
    let audioSession = SpeechAudioSessionSpy()
    let service = SystemSpeechService(audioSession: audioSession)

    service.speak("word")

    #expect(audioSession.categories == [.playback])
    #expect(audioSession.modes == [.spokenAudio])
    #expect(audioSession.options == [[.mixWithOthers]])
    #expect(audioSession.activeValues == [true])
}

@MainActor
private final class SpeechAudioSessionSpy: SpeechAudioSession {
    private(set) var categories: [AVAudioSession.Category] = []
    private(set) var modes: [AVAudioSession.Mode] = []
    private(set) var options: [AVAudioSession.CategoryOptions] = []
    private(set) var activeValues: [Bool] = []

    func configure(
        _ category: AVAudioSession.Category,
        mode: AVAudioSession.Mode,
        options: AVAudioSession.CategoryOptions
    ) throws {
        categories.append(category)
        modes.append(mode)
        self.options.append(options)
    }

    func activate() throws {
        activeValues.append(true)
    }
}
