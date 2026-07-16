import Foundation

enum PlayMode: String, CaseIterable, Identifiable {
    case challenge
    case unlimited

    var id: Self { self }

    var title: String {
        switch self {
        case .challenge: "Prompt Limit"
        case .unlimited: "No Limit"
        }
    }

    var shortTitle: String {
        switch self {
        case .challenge: "Limit"
        case .unlimited: "Chill"
        }
    }

    var subtitle: String {
        switch self {
        case .challenge: "Beat NOX before your prompts run out."
        case .unlimited: "Take your time. Your best score still counts."
        }
    }

    var symbol: String {
        switch self {
        case .challenge: "bolt.fill"
        case .unlimited: "infinity"
        }
    }
}

struct ChatMessage: Identifiable, Equatable {
    enum Author {
        case player
        case nox
    }

    let id = UUID()
    let author: Author
    let text: String
}

struct LevelResult: Identifiable, Equatable {
    let id = UUID()
    let level: HeistLevel
    let prompts: Int
    let stars: Int
    let isNewBest: Bool
    let bonus: LevelBonusResult?
}

struct LevelBonusResult: Equatable {
    let title: String
    let description: String
    let symbol: String
    let achieved: Bool
}
