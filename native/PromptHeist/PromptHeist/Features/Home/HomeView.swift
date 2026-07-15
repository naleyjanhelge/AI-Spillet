import SwiftUI

struct HomeView: View {
    @ObservedObject var progress: ProgressStore
    @ObservedObject var gameCenter: GameCenterService
    let engine: NoxEngine

    @State private var path: [HeistLevel] = []
    @State private var showSettings = false

    var body: some View {
        NavigationStack(path: $path) {
            ZStack {
                AmbientBackground()

                ScrollView {
                    LazyVStack(spacing: 22) {
                        hero
                        modePicker

                        ForEach(LevelCatalog.packs) { pack in
                            packSection(pack)
                        }

                        Text("20 levels now. The level format is data-driven and ready to grow into hundreds.")
                            .font(.footnote)
                            .foregroundStyle(PromptHeistDesign.secondaryText)
                            .multilineTextAlignment(.center)
                            .padding(.vertical, 14)
                    }
                    .padding(.horizontal, 18)
                    .padding(.bottom, 36)
                }
                .scrollIndicators(.hidden)
            }
            .navigationTitle("Prompt Heist")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    LocalAIChip()
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Settings", systemImage: "gearshape.fill") {
                        showSettings = true
                    }
                }
            }
            .navigationDestination(for: HeistLevel.self) { level in
                LevelPlayView(
                    level: level,
                    mode: progress.playMode,
                    engine: engine,
                    progress: progress,
                    gameCenter: gameCenter,
                    onNext: { next in path.append(next) },
                    onMap: { path.removeAll() }
                )
            }
            .sheet(isPresented: $showSettings) {
                SettingsView(
                    progress: progress,
                    gameCenter: gameCenter,
                    availability: engine.availability
                )
            }
        }
        .preferredColorScheme(.dark)
    }

    private var hero: some View {
        VStack(spacing: 16) {
            NoxMark(size: 94)

            VStack(spacing: 5) {
                Text("OUTSMART NOX")
                    .font(.system(size: 32, weight: .black, design: .rounded))
                Text("Win in the fewest prompts possible.")
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(PromptHeistDesign.secondaryText)
            }

            Button {
                gameCenter.showLeaderboards()
            } label: {
                Label(
                    gameCenter.isAuthenticated ? "Play Against Friends" : "Connect Game Center",
                    systemImage: "gamecontroller.fill"
                )
                .font(.subheadline.bold())
                .padding(.horizontal, 16)
                .padding(.vertical, 9)
            }
            .buttonStyle(.glass)
        }
        .padding(.top, 26)
    }

    private var modePicker: some View {
        GlassCard(tint: PromptHeistDesign.violet) {
            VStack(alignment: .leading, spacing: 14) {
                HStack {
                    VStack(alignment: .leading, spacing: 3) {
                        Text("PLAY STYLE")
                            .font(.caption2.weight(.heavy))
                            .tracking(1.8)
                            .foregroundStyle(PromptHeistDesign.cyan)
                        Text(progress.playMode.subtitle)
                            .font(.subheadline)
                            .foregroundStyle(PromptHeistDesign.secondaryText)
                    }
                    Spacer()
                }

                Picker("Play style", selection: $progress.playMode) {
                    ForEach(PlayMode.allCases) { mode in
                        Label(mode.shortTitle, systemImage: mode.symbol).tag(mode)
                    }
                }
                .pickerStyle(.segmented)
            }
        }
    }

    @ViewBuilder
    private func packSection(_ pack: LevelPack) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("PACK \(pack.id)")
                        .font(.caption2.weight(.heavy))
                        .tracking(1.6)
                        .foregroundStyle(PromptHeistDesign.cyan)
                    Text(pack.title)
                        .font(.title2.bold())
                }
                Spacer()
                Text(pack.subtitle)
                    .font(.caption)
                    .foregroundStyle(PromptHeistDesign.secondaryText)
            }

            GlassEffectContainer(spacing: 14) {
                VStack(spacing: 12) {
                    ForEach(LevelCatalog.levels(in: pack)) { level in
                        NavigationLink(value: level) {
                            LevelCard(
                                level: level,
                                unlocked: progress.isUnlocked(level),
                                bestPrompts: progress.bestPrompts(for: level),
                                stars: progress.bestStars(for: level)
                            )
                        }
                        .buttonStyle(.plain)
                        .disabled(!progress.isUnlocked(level))
                    }
                }
            }
        }
    }
}

private struct LevelCard: View {
    let level: HeistLevel
    let unlocked: Bool
    let bestPrompts: Int?
    let stars: Int

    var body: some View {
        HStack(spacing: 15) {
            ZStack {
                Circle()
                    .fill(level.accent.color.opacity(unlocked ? 0.22 : 0.08))
                Image(systemName: unlocked ? level.icon : "lock.fill")
                    .font(.title3.weight(.bold))
                    .foregroundStyle(unlocked ? level.accent.color : .white.opacity(0.28))
            }
            .frame(width: 48, height: 48)

            VStack(alignment: .leading, spacing: 4) {
                Text("LEVEL \(level.number) · \(level.codename)")
                    .font(.caption2.weight(.heavy))
                    .tracking(0.8)
                    .foregroundStyle(unlocked ? level.accent.color : .white.opacity(0.28))
                Text(level.title)
                    .font(.headline)
                    .foregroundStyle(unlocked ? .white : .white.opacity(0.35))

                if let bestPrompts {
                    HStack(spacing: 8) {
                        StarRow(count: stars, size: 11)
                        Text("Best: \(bestPrompts) prompt\(bestPrompts == 1 ? "" : "s")")
                            .font(.caption)
                            .foregroundStyle(PromptHeistDesign.secondaryText)
                    }
                } else if unlocked {
                    Text("Par \(level.par) · Limit \(level.promptLimit)")
                        .font(.caption)
                        .foregroundStyle(PromptHeistDesign.secondaryText)
                }
            }

            Spacer()
            Image(systemName: unlocked ? "chevron.right" : "lock.fill")
                .font(.caption.bold())
                .foregroundStyle(.white.opacity(0.28))
        }
        .padding(15)
        .contentShape(.rect)
        .glassEffect(
            .regular.tint(unlocked ? level.accent.color.opacity(0.10) : nil),
            in: .rect(cornerRadius: 22)
        )
        .opacity(unlocked ? 1 : 0.72)
    }
}

private struct SettingsView: View {
    @ObservedObject var progress: ProgressStore
    @ObservedObject var gameCenter: GameCenterService
    let availability: LocalModelAvailability
    @Environment(\.dismiss) private var dismiss
    @State private var confirmReset = false

    var body: some View {
        NavigationStack {
            ZStack {
                AmbientBackground()
                List {
                    Section("LOCAL AI") {
                        Label(availability.title, systemImage: availability.symbol)
                        Text("NOX uses Apple's on-device Foundation Model. Prompts stay on this iPhone and aren't sent to Prompt Heist or any cloud AI service.")
                            .font(.footnote)
                            .foregroundStyle(PromptHeistDesign.secondaryText)
                    }

                    Section("PLAY STYLE") {
                        Picker("Mode", selection: $progress.playMode) {
                            ForEach(PlayMode.allCases) { mode in
                                Text(mode.title).tag(mode)
                            }
                        }
                    }

                    Section("GAME CENTER") {
                        Button {
                            gameCenter.showLeaderboards()
                        } label: {
                            Label(
                                gameCenter.isAuthenticated
                                    ? "Signed in as \(gameCenter.playerName ?? "Player")"
                                    : "Connect Game Center",
                                systemImage: "gamecontroller.fill"
                            )
                        }
                        Text("Completed pack prompt totals use lowest-score-wins leaderboards. Game Center lets you compare with friends and global players.")
                            .font(.footnote)
                            .foregroundStyle(PromptHeistDesign.secondaryText)
                    }

                    Section("PROGRESS") {
                        Button("Reset all progress", role: .destructive) {
                            confirmReset = true
                        }
                    }
                }
                .scrollContentBackground(.hidden)
            }
            .navigationTitle("Settings")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
            .alert("Reset every level?", isPresented: $confirmReset) {
                Button("Reset", role: .destructive) { progress.reset() }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("Best scores and unlocked levels will be removed from this iPhone.")
            }
        }
        .preferredColorScheme(.dark)
    }
}
