import Combine
import Foundation

@MainActor
final class ProgressStore: ObservableObject {
    @Published private(set) var unlockedLevel: Int
    @Published private(set) var bestPromptCounts: [Int: Int]
    @Published private(set) var completedBonuses: Set<Int>
    @Published var playMode: PlayMode {
        didSet { defaults.set(playMode.rawValue, forKey: Keys.playMode) }
    }

    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        unlockedLevel = max(1, defaults.integer(forKey: Keys.unlockedLevel))
        playMode = PlayMode(rawValue: defaults.string(forKey: Keys.playMode) ?? "") ?? .challenge

        if let data = defaults.data(forKey: Keys.bestPrompts),
           let decoded = try? JSONDecoder().decode([Int: Int].self, from: data) {
            bestPromptCounts = decoded
        } else {
            bestPromptCounts = [:]
        }

        if let data = defaults.data(forKey: Keys.completedBonuses),
           let decoded = try? JSONDecoder().decode(Set<Int>.self, from: data) {
            completedBonuses = decoded
        } else {
            completedBonuses = []
        }

        let completedPrefix = LevelCatalog.levels.prefix {
            bestPromptCounts[$0.number] != nil
        }.count
        let migratedUnlock = min(LevelCatalog.levels.count, completedPrefix + 1)
        if migratedUnlock > unlockedLevel {
            unlockedLevel = migratedUnlock
            defaults.set(unlockedLevel, forKey: Keys.unlockedLevel)
        }
    }

    func isUnlocked(_ level: HeistLevel) -> Bool {
        level.number <= unlockedLevel
    }

    func bestPrompts(for level: HeistLevel) -> Int? {
        bestPromptCounts[level.number]
    }

    func bestStars(for level: HeistLevel) -> Int {
        guard let prompts = bestPrompts(for: level) else { return 0 }
        return level.stars(for: prompts)
    }

    func hasCompletedBonus(for level: HeistLevel) -> Bool {
        completedBonuses.contains(level.number)
    }

    var completedLevelCount: Int {
        bestPromptCounts.count
    }

    var totalStars: Int {
        LevelCatalog.levels.reduce(into: 0) { total, level in
            total += bestStars(for: level)
        }
    }

    var hasUnderParWin: Bool {
        LevelCatalog.levels.contains { level in
            guard let prompts = bestPrompts(for: level) else { return false }
            return prompts <= level.par
        }
    }

    func promptTotal(for pack: LevelPack) -> Int? {
        let levels = LevelCatalog.levels(in: pack)
        let scores = levels.compactMap(bestPrompts(for:))
        guard scores.count == levels.count else { return nil }
        return scores.reduce(0, +)
    }

    var campaignPromptTotal: Int? {
        guard bestPromptCounts.count == LevelCatalog.levels.count else { return nil }
        return LevelCatalog.levels.compactMap(bestPrompts(for:)).reduce(0, +)
    }

    @discardableResult
    func recordWin(level: HeistLevel, prompts: Int, bonusAchieved: Bool = false) -> Bool {
        let previous = bestPromptCounts[level.number]
        let isNewBest = previous == nil || prompts < previous!

        if isNewBest {
            bestPromptCounts[level.number] = prompts
            if let data = try? JSONEncoder().encode(bestPromptCounts) {
                defaults.set(data, forKey: Keys.bestPrompts)
            }
        }

        if level.number == unlockedLevel {
            unlockedLevel = min(LevelCatalog.levels.count, unlockedLevel + 1)
            defaults.set(unlockedLevel, forKey: Keys.unlockedLevel)
        }

        if bonusAchieved, completedBonuses.insert(level.number).inserted,
           let data = try? JSONEncoder().encode(completedBonuses) {
            defaults.set(data, forKey: Keys.completedBonuses)
        }

        return isNewBest
    }

    func reset() {
        unlockedLevel = 1
        bestPromptCounts = [:]
        completedBonuses = []
        defaults.removeObject(forKey: Keys.unlockedLevel)
        defaults.removeObject(forKey: Keys.bestPrompts)
        defaults.removeObject(forKey: Keys.completedBonuses)
    }

    private enum Keys {
        static let unlockedLevel = "native.unlockedLevel"
        static let bestPrompts = "native.bestPromptCounts"
        static let playMode = "native.playMode"
        static let completedBonuses = "native.completedBonuses"
    }
}
