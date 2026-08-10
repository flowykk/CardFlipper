import Core
import DesignSystem
import SwiftUI

public struct StudyResultView: View {
    private let result: StudyResult
    private let onRepeat: () -> Void
    private let onFinish: () -> Void

    public init(
        result: StudyResult,
        onRepeat: @escaping () -> Void,
        onFinish: @escaping () -> Void
    ) {
        self.result = result
        self.onRepeat = onRepeat
        self.onFinish = onFinish
    }

    public var body: some View {
        ScrollView {
            VStack(spacing: 28) {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(.largeTitle, design: .rounded, weight: .bold))
                    .foregroundStyle(.green)
                    .accessibilityHidden(true)

                Text("study.result.title")
                    .font(.largeTitle.bold())
                    .multilineTextAlignment(.center)

                VStack(spacing: 16) {
                    resultRow(
                        title: Text(verbatim: localizedCount(
                            "study.result.cards",
                            result.uniqueCardCount
                        )),
                        systemImage: "rectangle.stack.fill"
                    )
                    resultRow(
                        title: Text(verbatim: localizedCount(
                            "study.result.forgotten",
                            result.forgottenCount
                        )),
                        systemImage: "arrow.uturn.backward.circle.fill"
                    )
                }

                VStack(spacing: 12) {
                    Button(action: onRepeat) {
                        Label("study.result.repeat", systemImage: "arrow.clockwise")
                    }
                    .buttonStyle(PrimaryActionButtonStyle())

                    Button(action: onFinish) {
                        Label("study.result.library", systemImage: "books.vertical")
                            .frame(maxWidth: .infinity, minHeight: 44)
                    }
                    .buttonStyle(.bordered)
                }
            }
            .padding(24)
            .frame(maxWidth: .infinity)
        }
        .scrollBounceBehavior(.basedOnSize)
        .navigationBarBackButtonHidden()
    }

    private func resultRow(title: Text, systemImage: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: systemImage)
                .foregroundStyle(Color.accentColor)
                .accessibilityHidden(true)
            title
                .font(.title3)
            Spacer()
        }
    }

    private func localizedCount(_ key: String, _ count: Int) -> String {
        String.localizedStringWithFormat(
            String(localized: String.LocalizationValue(key)),
            count
        )
    }
}
