import Core
import DesignSystem
import SwiftUI

public struct StudyUsageExamplesView: View {
    private let variants: [EnglishVariant]
    private let isExpanded: Bool
    private let onToggle: () -> Void
    private let onSpeak: (UUID, UUID) -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    public init(
        variants: [EnglishVariant],
        isExpanded: Bool,
        onToggle: @escaping () -> Void,
        onSpeak: @escaping (UUID, UUID) -> Void
    ) {
        self.variants = variants
        self.isExpanded = isExpanded
        self.onToggle = onToggle
        self.onSpeak = onSpeak
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HapticButton(action: onToggle) {
                HStack {
                    Label(
                        isExpanded ? "study.examples.hide" : "study.examples.show",
                        systemImage: isExpanded ? "chevron.up" : "chevron.down"
                    )

                    Spacer()

                    Text(verbatim: exampleCountText)
                        .foregroundStyle(.secondary)
                        .monospacedDigit()
                }
                .padding(.vertical, 4)
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
            .frame(minHeight: 44)
            .contentShape(Rectangle())
            .accessibilityIdentifier("study.examples.toggle")
            .accessibilityValue(
                isExpanded ? "study.examples.accessibility.expanded" : "study.examples.accessibility.collapsed"
            )

            if isExpanded {
                VStack(alignment: .leading, spacing: 16) {
                    ForEach(variants.filter { !$0.usageExamples.isEmpty }) { variant in
                        VStack(alignment: .leading, spacing: 8) {
                            Text(verbatim: variant.text)
                                .font(.headline)

                            ForEach(variant.usageExamples) { example in
                                VStack(alignment: .leading, spacing: 8) {
                                    Text(verbatim: example.partOfSpeech.localizedName())
                                        .font(.subheadline.weight(.medium))
                                        .foregroundStyle(.secondary)

                                    Text(verbatim: example.text)
                                        .font(.body)
                                        .accessibilityIdentifier("study.usageExample")

                                    HapticButton {
                                        onSpeak(variant.id, example.id)
                                    } label: {
                                        Label("card.speak", systemImage: "speaker.wave.2.fill")
                                            .padding(.vertical, 4)
                                    }
                                    .buttonStyle(.bordered)
                                    .frame(minHeight: 44)
                                    .contentShape(Rectangle())
                                    .accessibilityIdentifier("study.usageExample.speak")
                                    .accessibilityHint(Text(verbatim: example.text))
                                }
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(12)
                                .background(.quaternary.opacity(0.5), in: RoundedRectangle(cornerRadius: 12))
                            }
                        }
                    }
                }
                .accessibilityElement(children: .contain)
                .accessibilityIdentifier("study.examples.container")
                .transition(reduceMotion ? .opacity : .move(edge: .top).combined(with: .opacity))
            }
        }
        .animation(reduceMotion ? .easeInOut(duration: 0.18) : .snappy, value: isExpanded)
    }

    private var exampleCount: Int {
        variants.reduce(into: 0) { count, variant in
            count += variant.usageExamples.count
        }
    }

    private var exampleCountText: String {
        String.localizedStringWithFormat(
            String(localized: "study.examples.count"),
            exampleCount
        )
    }
}
