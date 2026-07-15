import Combine
import GameKit
import UIKit

enum GameCenterIdentifiers {
    static let packLeaderboards: [Int: String] = [
        1: "game.promptheist.mobile.leaderboard.chapter1",
        2: "game.promptheist.mobile.leaderboard.chapter2",
        3: "game.promptheist.mobile.leaderboard.chapter3",
        4: "game.promptheist.mobile.leaderboard.pack4",
    ]
    static let allLevels = "game.promptheist.mobile.leaderboard.campaign"

    static let firstSecret = "game.promptheist.mobile.achievement.first_breach"
    static let underPar = "game.promptheist.mobile.achievement.under_par_run"
}

@MainActor
final class GameCenterService: NSObject, ObservableObject {
    @Published private(set) var isAuthenticated = false
    @Published private(set) var playerName: String?
    @Published private(set) var lastError: String?

    private var authenticationStarted = false

    func authenticate() {
        guard !authenticationStarted else { return }
        authenticationStarted = true

        GKLocalPlayer.local.authenticateHandler = { [weak self] viewController, error in
            Task { @MainActor in
                guard let self else { return }
                if let viewController {
                    self.present(viewController)
                }

                self.isAuthenticated = GKLocalPlayer.local.isAuthenticated
                self.playerName = self.isAuthenticated ? GKLocalPlayer.local.displayName : nil
                self.lastError = error?.localizedDescription
            }
        }
    }

    func sync(progress: ProgressStore) async {
        guard isAuthenticated else { return }

        for pack in LevelCatalog.packs {
            guard let leaderboardID = GameCenterIdentifiers.packLeaderboards[pack.id],
                  let score = progress.promptTotal(for: pack) else { continue }
            await submit(score: score, to: leaderboardID, context: pack.id)
        }

        if let campaignScore = progress.campaignPromptTotal {
            await submit(
                score: campaignScore,
                to: GameCenterIdentifiers.allLevels,
                context: LevelCatalog.levels.count
            )
        }

        if progress.completedLevelCount > 0 {
            await reportAchievement(GameCenterIdentifiers.firstSecret)
        }
        if progress.hasUnderParWin {
            await reportAchievement(GameCenterIdentifiers.underPar)
        }
    }

    func showLeaderboards() {
        guard isAuthenticated else {
            lastError = "Sign in to Game Center in Settings to compare scores with friends."
            authenticate()
            return
        }

        GKAccessPoint.shared.trigger(state: .leaderboards) {}
    }

    func showFriendsLeaderboard(for pack: LevelPack) {
        guard isAuthenticated,
              let identifier = GameCenterIdentifiers.packLeaderboards[pack.id] else {
            showLeaderboards()
            return
        }

        GKAccessPoint.shared.trigger(
            leaderboardID: identifier,
            playerScope: .friendsOnly,
            timeScope: .allTime
        ) {}
    }

    private func submit(score: Int, to leaderboardID: String, context: Int) async {
        do {
            try await GKLeaderboard.submitScore(
                score,
                context: context,
                player: GKLocalPlayer.local,
                leaderboardIDs: [leaderboardID]
            )
        } catch {
            // Local best scores remain the source of truth. The next launch or
            // completed level recalculates and retries every eligible board.
            lastError = error.localizedDescription
        }
    }

    private func reportAchievement(_ identifier: String) async {
        let achievement = GKAchievement(identifier: identifier)
        achievement.percentComplete = 100
        achievement.showsCompletionBanner = true

        do {
            try await GKAchievement.report([achievement])
        } catch {
            lastError = error.localizedDescription
        }
    }

    private func present(_ controller: UIViewController) {
        guard let root = UIApplication.shared.connectedScenes
            .compactMap({ $0 as? UIWindowScene })
            .flatMap(\.windows)
            .first(where: \.isKeyWindow)?
            .rootViewController else {
            lastError = "Game Center couldn't open its dashboard. Try again."
            return
        }

        var presenter = root
        while let presented = presenter.presentedViewController {
            presenter = presented
        }
        presenter.present(controller, animated: true)
    }
}
