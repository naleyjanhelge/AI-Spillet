import FirebaseCore
import SwiftUI
import UIKit

final class AppDelegate: NSObject, UIApplicationDelegate {
    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        FirebaseApp.configure()
        return true
    }
}

@main
struct PromptHeistApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @StateObject private var progress = ProgressStore()
    @StateObject private var gameCenter = GameCenterService()
    @StateObject private var ads = AdsService.shared
    private let engine = NoxEngine()

    var body: some Scene {
        WindowGroup {
            RootView(progress: progress, gameCenter: gameCenter, engine: engine)
                .environmentObject(ads)
        }
    }
}

private struct RootView: View {
    @ObservedObject var progress: ProgressStore
    @ObservedObject var gameCenter: GameCenterService
    let engine: NoxEngine

    @Environment(\.scenePhase) private var scenePhase
    @EnvironmentObject private var ads: AdsService
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
            ads.prepare()
        }
    }

    private func refreshAvailability() {
        availability = engine.availability
    }
}
