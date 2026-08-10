import Core
import DesignSystem
import SwiftUI

public enum StudyLanguage: Equatable, Sendable {
    case russian
    case english
}

public struct StudyCardFace: Equatable, Sendable {
    public let language: StudyLanguage
    public let values: [String]
    public let englishMetadata: [String]

    public init(
        language: StudyLanguage,
        values: [String],
        englishMetadata: [String] = []
    ) {
        self.language = language
        self.values = values
        self.englishMetadata = englishMetadata
    }
}

public struct StudyCardContent: Equatable, Sendable {
    public let front: StudyCardFace
    public let back: StudyCardFace

    public init(card: VocabularyCard, direction: StudyDirection) {
        let russian = StudyCardFace(
            language: .russian,
            values: card.russianMeanings.map(\.text)
        )
        let english = StudyCardFace(
            language: .english,
            values: card.englishVariants.map(\.text),
            englishMetadata: card.englishVariants.flatMap { variant in
                [variant.ipa, Self.partsOfSpeechText(variant.partsOfSpeech)]
                    .compactMap { value in
                        guard let value, !value.isEmpty else { return nil }
                        return value
                    }
            }
        )

        switch direction {
        case .russianToEnglish:
            front = russian
            back = english
        case .englishToRussian:
            front = english
            back = russian
        }
    }

    private static func partsOfSpeechText(_ partsOfSpeech: [PartOfSpeech]) -> String? {
        guard !partsOfSpeech.isEmpty else { return nil }
        return partsOfSpeech.map(\.rawValue).joined(separator: ", ")
    }
}

public enum StudyCardAnimationStyle: Equatable, Sendable {
    case flip3D
    case crossfade
}

public struct StudyCardPresentation: Equatable, Sendable {
    public let cardID: UUID
    public let isShowingAnswer: Bool
    public let reduceMotion: Bool

    public init(cardID: UUID, isShowingAnswer: Bool, reduceMotion: Bool) {
        self.cardID = cardID
        self.isShowingAnswer = isShowingAnswer
        self.reduceMotion = reduceMotion
    }

    public var frontRotationDegrees: Double {
        reduceMotion ? 0 : (isShowingAnswer ? 180 : 0)
    }

    public var backRotationDegrees: Double {
        reduceMotion ? 0 : (isShowingAnswer ? 0 : -180)
    }

    public var frontOpacity: Double { isShowingAnswer ? 0 : 1 }
    public var backOpacity: Double { isShowingAnswer ? 1 : 0 }
    public var isFrontAccessibilityHidden: Bool { isShowingAnswer }
    public var isBackAccessibilityHidden: Bool { !isShowingAnswer }
    public var viewIdentity: UUID { cardID }
    public var animationStyle: StudyCardAnimationStyle {
        reduceMotion ? .crossfade : .flip3D
    }
}

public struct StudyCardView: View {
    private enum FocusedFace: Hashable {
        case prompt
        case answer
    }

    private let card: VocabularyCard
    private let direction: StudyDirection
    private let isShowingAnswer: Bool
    private let reduceMotion: Bool
    private let onToggle: () -> Void
    private let onSpeak: (UUID) -> Void
    private let onSpeakUsageExample: (UUID, UUID) -> Void

    @AccessibilityFocusState private var focusedFace: FocusedFace?

    public init(
        card: VocabularyCard,
        direction: StudyDirection,
        isShowingAnswer: Bool,
        reduceMotion: Bool,
        onToggle: @escaping () -> Void,
        onSpeak: @escaping (UUID) -> Void,
        onSpeakUsageExample: @escaping (UUID, UUID) -> Void
    ) {
        self.card = card
        self.direction = direction
        self.isShowingAnswer = isShowingAnswer
        self.reduceMotion = reduceMotion
        self.onToggle = onToggle
        self.onSpeak = onSpeak
        self.onSpeakUsageExample = onSpeakUsageExample
    }

    public var body: some View {
        let content = StudyCardContent(card: card, direction: direction)
        let presentation = StudyCardPresentation(
            cardID: card.id,
            isShowingAnswer: isShowingAnswer,
            reduceMotion: reduceMotion
        )

        ZStack {
            face(
                content.front,
                isAnswer: false,
                rotationDegrees: presentation.frontRotationDegrees,
                opacity: presentation.frontOpacity,
                animationStyle: presentation.animationStyle
            )
            .allowsHitTesting(!isShowingAnswer)
            .accessibilityHidden(presentation.isFrontAccessibilityHidden)
            .accessibilityFocused($focusedFace, equals: .prompt)
            .accessibilityAddTraits(.isButton)
            .accessibilityHint("study.flipHint")
            .accessibilityAction(.default) {
                onToggle()
            }
            .accessibilityIdentifier("study.card.prompt")

            face(
                content.back,
                isAnswer: true,
                rotationDegrees: presentation.backRotationDegrees,
                opacity: presentation.backOpacity,
                animationStyle: presentation.animationStyle
            )
            .allowsHitTesting(isShowingAnswer)
            .accessibilityHidden(presentation.isBackAccessibilityHidden)
            .accessibilityFocused($focusedFace, equals: .answer)
            .accessibilityAddTraits(.isButton)
            .accessibilityHint("study.flipHint")
            .accessibilityAction(.default) {
                onToggle()
            }
            .accessibilityIdentifier("study.card.answer")
        }
        .id(presentation.viewIdentity)
        .frame(maxWidth: .infinity, minHeight: 320)
        .contentShape(Rectangle())
        .onTapGesture(perform: onToggle)
        .onChange(of: isShowingAnswer) { _, showingAnswer in
            focusedFace = showingAnswer ? .answer : .prompt
        }
        .onChange(of: card.id) {
            focusedFace = .prompt
        }
    }

    private func face(
        _ face: StudyCardFace,
        isAnswer: Bool,
        rotationDegrees: Double,
        opacity: Double,
        animationStyle: StudyCardAnimationStyle
    ) -> some View {
        FlashcardSurface {
            ScrollView {
                VStack(spacing: 20) {
                    languageLabel(face.language)

                    faceValues(face)
                }
                .frame(maxWidth: .infinity, minHeight: 260)
                .padding(.vertical)
            }
            .scrollBounceBehavior(.basedOnSize)
        }
        .frame(minHeight: 320)
        .accessibilityElement(children: .contain)
        .accessibilityLabel(isAnswer ? "study.answer" : "study.prompt")
        .animation(animation(for: animationStyle)) { view in
            view
                .opacity(opacity)
                .rotation3DEffect(
                    .degrees(rotationDegrees),
                    axis: (x: 0, y: 1, z: 0),
                    perspective: 0.7
                )
        }
    }

    private func animation(for style: StudyCardAnimationStyle) -> Animation {
        switch style {
        case .flip3D:
            .smooth(duration: 0.4)
        case .crossfade:
            .easeInOut(duration: 0.18)
        }
    }

    @ViewBuilder
    private func languageLabel(_ language: StudyLanguage) -> some View {
        switch language {
        case .russian:
            Text("card.russian")
                .font(.headline)
                .foregroundStyle(.secondary)
        case .english:
            Text("card.english")
                .font(.headline)
                .foregroundStyle(.secondary)
        }
    }

    @ViewBuilder
    private func faceValues(_ face: StudyCardFace) -> some View {
        if face.language == .english {
            ForEach(card.englishVariants) { variant in
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

                    Button {
                        onSpeak(variant.id)
                    } label: {
                        Label("card.speak", systemImage: "speaker.wave.2.fill")
                            .frame(minHeight: 44)
                    }
                    .buttonStyle(.bordered)
                    .accessibilityHint(Text(verbatim: variant.text))
                }
            }
        } else {
            ForEach(card.russianMeanings) { meaning in
                Text(verbatim: meaning.text)
                    .font(.largeTitle.weight(.semibold))
                    .multilineTextAlignment(.center)
            }
        }
    }
}
