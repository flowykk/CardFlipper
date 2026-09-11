import Core
import SwiftUI

public struct VocabularyCardRow: View {
    private let card: VocabularyCard
    private let showRussianMeanings: Bool

    public init(card: VocabularyCard, showRussianMeanings: Bool) {
        self.card = card
        self.showRussianMeanings = showRussianMeanings
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            languageValues(
                label: "card.english",
                values: card.englishVariants.map(\.text),
                font: .headline
            )

            if showRussianMeanings {
                languageValues(
                    label: "card.russian",
                    values: card.russianMeanings.map(\.text),
                    font: .body
                )
            }

            Label(
                card.isLearned ? "learningFilter.learned" : "learningFilter.unlearned",
                systemImage: card.isLearned ? "checkmark.circle.fill" : "circle.dashed"
            )
            .font(.caption.weight(.semibold))
            .foregroundStyle(card.isLearned ? Color.accentColor : .secondary)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(
                card.isLearned ? Color.accentColor.opacity(0.12) : Color.secondary.opacity(0.10),
                in: Capsule()
            )
            .accessibilityIdentifier("library.card.learningStatus")

            if !card.tags.isEmpty {
                ViewThatFits(in: .horizontal) {
                    HStack(spacing: 6) {
                        tagLabels
                    }
                    VStack(alignment: .leading, spacing: 4) {
                        tagLabels
                    }
                }
            }
        }
        .padding(.vertical, 4)
        .frame(maxWidth: .infinity, alignment: .leading)
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
        .accessibilityValue(
            Text(card.isLearned ? "learningFilter.learned" : "learningFilter.unlearned")
        )
    }

    @ViewBuilder
    private func languageValues(
        label: LocalizedStringKey,
        values: [String],
        font: Font
    ) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(verbatim: values.joined(separator: " • "))
                .font(font)
                .foregroundStyle(.primary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    @ViewBuilder
    private var tagLabels: some View {
        ForEach(card.tags) { tag in
            Text(verbatim: tag.name)
                .font(.caption)
                .foregroundStyle(.secondary)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(.quaternary, in: Capsule())
        }
    }
}
