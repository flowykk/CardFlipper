import Core
import DesignSystem
import SwiftUI

struct StudyEnglishVariantsView: View {
    let variants: [EnglishVariant]
    let speakAccessibilityIdentifier: String
    let onSpeak: (UUID) -> Void

    var body: some View {
        ForEach(variants) { variant in
            VStack(spacing: 8) {
                Text(verbatim: variant.text)
                    .font(.largeTitle.weight(.semibold))
                    .multilineTextAlignment(.center)

                if let ipa = variant.ipa, !ipa.isEmpty {
                    Text(verbatim: ipa)
                        .font(.title3)
                        .foregroundStyle(.secondary)
                        .accessibilityLabel("card.ipa")
                        .accessibilityValue(Text(verbatim: ipa))
                }

                if !variant.partsOfSpeech.isEmpty {
                    let partsOfSpeechText = variant.partsOfSpeech
                        .map { $0.localizedName() }
                        .joined(separator: ", ")

                    Text(verbatim: partsOfSpeechText)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .accessibilityLabel("card.partsOfSpeech")
                        .accessibilityValue(Text(verbatim: partsOfSpeechText))
                }

                StudySpeakButton(
                    accessibilityIdentifier: speakAccessibilityIdentifier,
                    accessibilityHint: variant.text,
                    action: { onSpeak(variant.id) }
                )
            }
        }
    }
}

struct StudySpeakButton: View {
    let accessibilityIdentifier: String
    var accessibilityHint: String? = nil
    let action: () -> Void

    var body: some View {
        HapticButton(action: action) {
            Label("card.speak", systemImage: "speaker.wave.2.fill")
                .padding(.vertical, 4)
        }
        .buttonStyle(.bordered)
        .frame(minHeight: 44)
        .contentShape(Rectangle())
        .accessibilityIdentifier(accessibilityIdentifier)
        .accessibilityHint(Text(verbatim: accessibilityHint ?? ""))
    }
}
