import SwiftUI

@main
struct PromptHeistApp: App {
    @StateObject private var progress = ProgressStore()
    @StateObject private var gameCenter = GameCenterService()
    private let engine = NoxEngine()

    var body: some Scene {
        WindowGroup {
            RootView(progress: progress, gameCenter: gameCenter, engine: engine)
        }
    }
}

private struct RootView: View {
    @ObservedObject var progress: ProgressStore
    @ObservedObject var gameCenter: GameCenterService
    let engine: NoxEngine

    @Environment(\.scenePhase) private var scenePhase
    @AppStorage("native.appleIntelligenceRequirementSeen") private var requirementSeen = false
    @State private var availability: LocalModelAvailability

    init(progress: ProgressStore, gameCenter: GameCenterService, engine: NoxEngine) {
        self.progress = progress
        self.gameCenter = gameCenter
        self.engine = engine
        _availability = State(initialValue: engine.availability)
    }

    var body: some View {
        Group {
            if !requirementSeen {
                ModelRequirementView(
                    availability: availability,
                    isFirstLaunch: true,
                    onRefresh: refreshAvailability,
                    onContinue: { requirementSeen = true }
                )
            } else if availability == .ready {
                HomeView(progress: progress, gameCenter: gameCenter, engine: engine)
            } else {
                ModelRequirementView(
                    availability: availability,
                    isFirstLaunch: false,
                    onRefresh: refreshAvailability,
                    onContinue: {}
                )
            }
        }
        .onChange(of: scenePhase) {
            if scenePhase == .active { refreshAvailability() }
        }
        .onChange(of: gameCenter.isAuthenticated) {
            if gameCenter.isAuthenticated {
                Task { await gameCenter.sync(progress: progress) }
            }
        }
        .task {
            gameCenter.authenticate()
        }
    }

    private func refreshAvailability() {
        availability = engine.availability
    }
}
