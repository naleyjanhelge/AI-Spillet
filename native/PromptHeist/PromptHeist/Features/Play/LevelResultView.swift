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

            VStack(spacing: 24) {
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
}
