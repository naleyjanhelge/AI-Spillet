import FirebaseAnalytics
import FirebaseCore

enum GameAnalytics {
    static func levelStarted(level: HeistLevel, mode: PlayMode) {
        log(
            "level_start",
            parameters: [
                "level_name": "level_\(level.number)",
                "level_number": level.number,
                "play_mode": mode.rawValue,
                "difficulty": level.difficulty.rawValue,
            ]
        )
    }

    static func levelCompleted(
        level: HeistLevel,
        mode: PlayMode,
        promptCount: Int,
        stars: Int,
        bonusCompleted: Bool,
        isNewBest: Bool
    ) {
        log(
            "level_end",
            parameters: [
                "level_name": "level_\(level.number)",
                "level_number": level.number,
                "success": 1,
                "play_mode": mode.rawValue,
                "prompt_count": promptCount,
                "stars": stars,
                "bonus_completed": bonusCompleted ? 1 : 0,
                "new_best": isNewBest ? 1 : 0,
            ]
        )
    }

    static func levelLimitReached(level: HeistLevel, promptCount: Int) {
        log(
            "level_end",
            parameters: [
                "level_name": "level_\(level.number)",
                "level_number": level.number,
                "success": 0,
                "play_mode": PlayMode.challenge.rawValue,
                "prompt_count": promptCount,
            ]
        )
    }

    private static func log(_ name: String, parameters: [String: Any]) {
        guard FirebaseApp.app() != nil else { return }
        Analytics.logEvent(name, parameters: parameters)
    }
}
