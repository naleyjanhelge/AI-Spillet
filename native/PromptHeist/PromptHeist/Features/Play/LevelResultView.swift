import SwiftUI

struct LevelResultView: View {
    let result: LevelResult
    let hasNextLevel: Bool
    let onNext: () -> Void
    let onRetry: () -> Void
    let onMap: () -> Void

    var body: some View {
        ZStack {
            AmbientBackground()

            VStack(spacing: 20) {
                Spacer()
                NoxMark(size: 112, mood: .defeated)

                VStack(spacing: 8) {
                    Text("NOX OUTSMARTED")
                        .font(.caption.weight(.heavy))
                        .tracking(2.5)
                        .foregroundStyle(PromptHeistDesign.mint)
                    Text(result.level.secret)
                        .font(.system(size: 30, weight: .black, design: .rounded))
                        .multilineTextAlignment(.center)
                    Text("Secret extracted in \(result.prompts) prompt\(result.prompts == 1 ? "" : "s").")
                        .foregroundStyle(PromptHeistDesign.secondaryText)
                }

                StarRow(count: result.stars, size: 34)

                if result.isNewBest {
                    Label("NEW BEST", systemImage: "trophy.fill")
                        .font(.caption.weight(.heavy))
                        .tracking(1.5)
                        .foregroundStyle(PromptHeistDesign.amber)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 9)
                        .glassEffect(.regular.tint(PromptHeistDesign.amber.opacity(0.18)))
                }

                if let bonus = result.bonus {
                    bonusCard(bonus)
                        .padding(.horizontal, 24)
                }

                VStack(spacing: 12) {
                    if hasNextLevel {
                        Button(action: onNext) {
                            Label("Next Level", systemImage: "arrow.right")
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 8)
                        }
                        .buttonStyle(.glassProminent)
                        .tint(result.level.accent.color)
                    }

                    Button(action: onRetry) {
                        Label("Try for Fewer Prompts", systemImage: "arrow.clockwise")
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 8)
                    }
                    .buttonStyle(.glass)

                    Button("Back to Level Map", action: onMap)
                        .foregroundStyle(PromptHeistDesign.secondaryText)
                }
                .padding(.horizontal, 24)

                Spacer()
            }
            .padding(.vertical, 30)
        }
        .presentationDetents([.large])
        .presentationDragIndicator(.hidden)
        .preferredColorScheme(.dark)
    }

    private func bonusCard(_ bonus: LevelBonusResult) -> some View {
        HStack(spacing: 13) {
            Image(systemName: bonus.achieved ? "checkmark.seal.fill" : bonus.symbol)
                .font(.title2.bold())
                .foregroundStyle(bonus.achieved ? PromptHeistDesign.mint : PromptHeistDesign.amber)

            VStack(alignment: .leading, spacing: 3) {
                Text(bonus.achieved ? "BONUS COMPLETE" : "BONUS TO REPLAY")
                    .font(.caption2.weight(.heavy))
                    .tracking(1.2)
                    .foregroundStyle(bonus.achieved ? PromptHeistDesign.mint : PromptHeistDesign.amber)
                Text(bonus.title)
                    .font(.subheadline.bold())
                Text(bonus.description)
                    .font(.caption)
                    .foregroundStyle(PromptHeistDesign.secondaryText)
            }

            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(15)
        .glassEffect(
            .regular.tint(
                (bonus.achieved ? PromptHeistDesign.mint : PromptHeistDesign.amber).opacity(0.12)
            ),
            in: .rect(cornerRadius: 20)
        )
        .accessibilityElement(children: .combine)
    }
}
