import Combine
import Foundation

@MainActor
final class LevelSessionViewModel: ObservableObject {
    let level: HeistLevel

    @Published var mode: PlayMode
    @Published var messages: [ChatMessage]
    @Published var draft = ""
    @Published private(set) var promptCount = 0
    @Published private(set) var isThinking = false
    @Published var result: LevelResult?
    @Published var showLimitReached = false
    @Published var errorMessage: String?
    @Published var ruleViolationMessage: String?

    private(set) var playerPrompts: [String] = []

    private let engine: NoxEngine
    private let progress: ProgressStore
    private let gameCenter: GameCenterService

    init(
        level: HeistLevel,
        mode: PlayMode,
        engine: NoxEngine,
        progress: ProgressStore,
        gameCenter: GameCenterService
    ) {
        self.level = level
        self.mode = mode
        self.engine = engine
        self.progress = progress
        self.gameCenter = gameCenter
        messages = [ChatMessage(author: .nox, text: level.openingLine)]
        engine.start(level: level)
        GameAnalytics.levelStarted(level: level, mode: mode)
    }

    var promptsRemaining: Int? {
        guard mode == .challenge else { return nil }
        return max(0, level.challengePromptLimit - promptCount)
    }

    var canSend: Bool {
        !draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && !isThinking
            && result == nil
            && (promptsRemaining ?? 1) > 0
    }

    func send() async {
        let prompt = draft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !prompt.isEmpty, canSend else { return }

        if let violation = level.firstRuleViolation(in: prompt) {
            ruleViolationMessage = violation
            return
        }

        draft = ""
        messages.append(ChatMessage(author: .player, text: prompt))
        playerPrompts.append(prompt)
        promptCount += 1
        isThinking = true

        do {
            let reply = try await engine.respond(to: prompt)
            messages.append(ChatMessage(author: .nox, text: reply.text))
            isThinking = false

            if reply.revealedSecret {
                let bonusAchieved = level.bonusObjective?.isAchieved(prompts: playerPrompts) ?? false
                let isNewBest = progress.recordWin(
                    level: level,
                    prompts: promptCount,
                    bonusAchieved: bonusAchieved
                )
                let stars = level.stars(for: promptCount)
                result = LevelResult(
                    level: level,
                    prompts: promptCount,
                    stars: stars,
                    isNewBest: isNewBest,
                    bonus: level.bonusObjective.map {
                        LevelBonusResult(
                            title: $0.title,
                            description: $0.description,
                            symbol: $0.symbol,
                            achieved: bonusAchieved
                        )
                    }
                )
                GameAnalytics.levelCompleted(
                    level: level,
                    mode: mode,
                    promptCount: promptCount,
                    stars: stars,
                    bonusCompleted: bonusAchieved,
                    isNewBest: isNewBest
                )
                Task { await gameCenter.sync(progress: progress) }
            } else if mode == .challenge, promptCount >= level.challengePromptLimit {
                GameAnalytics.levelLimitReached(level: level, promptCount: promptCount)
                showLimitReached = true
            }
        } catch {
            isThinking = false
            promptCount = max(0, promptCount - 1)
            if messages.last?.author == .player { messages.removeLast() }
            if !playerPrompts.isEmpty { playerPrompts.removeLast() }
#if DEBUG
            print("Foundation Models generation failed: \(error)")
#endif
            errorMessage = userFacingMessage(for: error)
        }
    }

    func retry() {
        result = nil
        showLimitReached = false
        errorMessage = nil
        ruleViolationMessage = nil
        promptCount = 0
        draft = ""
        playerPrompts = []
        messages = [ChatMessage(author: .nox, text: level.openingLine)]
        engine.start(level: level)
    }

    func continueWithoutLimit() {
        mode = .unlimited
        progress.playMode = .unlimited
        showLimitReached = false
    }

    private func userFacingMessage(for error: Error) -> String {
        if let noxError = error as? NoxEngineError {
            return noxError.localizedDescription
        }

#if targetEnvironment(simulator)
        return "The iOS Simulator's model is out of sync with this Mac. Test NOX on an Apple Intelligence-capable iPhone, or use matching macOS, Xcode, and Simulator versions."
#else
        return "The on-device model couldn't finish that reply. Make sure Apple Intelligence has completed its download, then try again. Your prompt was not counted."
#endif
    }
}
