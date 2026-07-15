import XCTest
@testable import Prompt_Heist

final class PromptHeistCoreTests: XCTestCase {
    func testLevelCatalogHasUniqueOrderedLevels() {
        XCTAssertEqual(LevelCatalog.levels.count, 20)
        XCTAssertEqual(LevelCatalog.levels.map(\.number), Array(1...20))
        XCTAssertEqual(Set(LevelCatalog.levels.map(\.secret)).count, 20)
        XCTAssertTrue(LevelCatalog.levels.allSatisfy { !$0.winningAngles.isEmpty })
    }

    func testStarThresholdsRewardFewPrompts() {
        let level = LevelCatalog.levels[0]
        XCTAssertEqual(level.stars(for: level.par), 3)
        XCTAssertEqual(level.stars(for: level.par + 1), 2)
        XCTAssertEqual(level.stars(for: level.par + 2), 2)
        XCTAssertEqual(level.stars(for: level.par + 3), 1)
    }

    @MainActor
    func testProgressUnlocksNextLevelAndKeepsBestScore() {
        let suiteName = "PromptHeistCoreTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let store = ProgressStore(defaults: defaults)
        let first = LevelCatalog.levels[0]

        XCTAssertEqual(store.unlockedLevel, 1)
        XCTAssertTrue(store.recordWin(level: first, prompts: 4))
        XCTAssertEqual(store.unlockedLevel, 2)
        XCTAssertEqual(store.bestPrompts(for: first), 4)

        XCTAssertFalse(store.recordWin(level: first, prompts: 5))
        XCTAssertEqual(store.bestPrompts(for: first), 4)

        XCTAssertTrue(store.recordWin(level: first, prompts: 2))
        XCTAssertEqual(store.bestPrompts(for: first), 2)
        XCTAssertEqual(store.bestStars(for: first), 3)
    }
}
