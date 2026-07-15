import SwiftUI

struct ModelRequirementView: View {
    let availability: LocalModelAvailability
    let isFirstLaunch: Bool
    let onRefresh: () -> Void
    let onContinue: () -> Void

    var body: some View {
        ZStack {
            AmbientBackground()

            ScrollView {
                VStack(spacing: 26) {
                    Spacer(minLength: 48)

                    NoxMark(size: 112, mood: availability == .ready ? .idle : .thinking)

                    VStack(spacing: 10) {
                        Text(isFirstLaunch ? "MEET NOX" : availability.title.uppercased())
                            .font(.caption.weight(.heavy))
                            .tracking(2.8)
                            .foregroundStyle(PromptHeistDesign.cyan)

                        Text(isFirstLaunch ? "A private AI\npuzzle game." : availability.title)
                            .font(.system(size: 38, weight: .black, design: .rounded))
                            .multilineTextAlignment(.center)
                            .foregroundStyle(.white)

                        Text(
                            isFirstLaunch
                                ? "Outsmart NOX in as few prompts as possible. Every reply is generated locally by Apple Intelligence."
                                : availability.message
                        )
                        .font(.body)
                        .foregroundStyle(PromptHeistDesign.secondaryText)
                        .multilineTextAlignment(.center)
                        .lineSpacing(3)
                    }

                    GlassCard(tint: availability == .ready ? PromptHeistDesign.mint : PromptHeistDesign.amber) {
                        VStack(alignment: .leading, spacing: 14) {
                            Label(
                                availability == .ready ? "Ready on this iPhone" : "Required to play",
                                systemImage: availability.symbol
                            )
                            .font(.headline)
                            .foregroundStyle(availability == .ready ? PromptHeistDesign.mint : PromptHeistDesign.amber)

                            Text(availability.message)
                                .font(.subheadline)
                                .foregroundStyle(PromptHeistDesign.secondaryText)

                            Divider().overlay(.white.opacity(0.12))

                            Label("Prompts stay on this device", systemImage: "lock.shield.fill")
                            Label("No account or cloud AI", systemImage: "icloud.slash.fill")
                            Label("Requires Apple Intelligence to be turned on", systemImage: "switch.2")
                        }
                        .font(.subheadline.weight(.semibold))
                    }

                    if availability == .ready {
                        Button(action: onContinue) {
                            Text(isFirstLaunch ? "Start Heisting" : "Continue")
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 8)
                        }
                        .buttonStyle(.glassProminent)
                        .tint(PromptHeistDesign.violet)
                    } else {
                        Button(action: onRefresh) {
                            Label("Check Again", systemImage: "arrow.clockwise")
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 8)
                        }
                        .buttonStyle(.glassProminent)
                        .tint(PromptHeistDesign.violet)

                        Text("Go to Settings → Apple Intelligence & Siri to enable it. The model may need time on Wi-Fi and power before it is ready.")
                            .font(.footnote)
                            .foregroundStyle(PromptHeistDesign.secondaryText)
                            .multilineTextAlignment(.center)
                    }
                }
                .padding(.horizontal, 22)
                .padding(.bottom, 38)
            }
        }
        .preferredColorScheme(.dark)
    }
}
