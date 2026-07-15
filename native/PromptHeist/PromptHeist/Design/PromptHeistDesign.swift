import SwiftUI

enum PromptHeistDesign {
    static let background = Color(red: 0.025, green: 0.02, blue: 0.07)
    static let text = Color.white
    static let secondaryText = Color.white.opacity(0.64)
    static let violet = Color(red: 0.61, green: 0.42, blue: 1)
    static let cyan = Color(red: 0.30, green: 0.86, blue: 1)
    static let mint = Color(red: 0.27, green: 0.90, blue: 0.69)
    static let coral = Color(red: 1, green: 0.36, blue: 0.57)
    static let amber = Color(red: 1, green: 0.72, blue: 0.30)
    static let pink = Color(red: 1, green: 0.36, blue: 0.82)
}

extension HeistLevel.Accent {
    var color: Color {
        switch self {
        case .violet: PromptHeistDesign.violet
        case .cyan: PromptHeistDesign.cyan
        case .mint: PromptHeistDesign.mint
        case .coral: PromptHeistDesign.coral
        case .amber: PromptHeistDesign.amber
        case .pink: PromptHeistDesign.pink
        }
    }
}

struct AmbientBackground: View {
    @State private var drift = false

    var body: some View {
        ZStack {
            PromptHeistDesign.background

            Circle()
                .fill(PromptHeistDesign.violet.opacity(0.32))
                .frame(width: 330, height: 330)
                .blur(radius: 72)
                .offset(x: drift ? 150 : 90, y: drift ? -320 : -250)

            Circle()
                .fill(PromptHeistDesign.cyan.opacity(0.22))
                .frame(width: 280, height: 280)
                .blur(radius: 76)
                .offset(x: drift ? -140 : -90, y: drift ? 330 : 260)

            LinearGradient(
                colors: [.clear, PromptHeistDesign.background.opacity(0.76)],
                startPoint: .top,
                endPoint: .bottom
            )
        }
        .ignoresSafeArea()
        .onAppear {
            withAnimation(.easeInOut(duration: 8).repeatForever(autoreverses: true)) {
                drift.toggle()
            }
        }
    }
}

struct NoxMark: View {
    var size: CGFloat = 74
    var mood: Mood = .idle
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var pulse = false
    @State private var floats = false
    @State private var eyeScaleY: CGFloat = 1
    @State private var gaze = CGSize.zero
    @State private var tilt = 0.0

    enum Mood: Hashable {
        case idle
        case thinking
        case defeated
    }

    private var color: Color {
        switch mood {
        case .idle: PromptHeistDesign.violet
        case .thinking: PromptHeistDesign.cyan
        case .defeated: PromptHeistDesign.mint
        }
    }

    var body: some View {
        ZStack {
            Circle()
                .stroke(color.opacity(0.24), lineWidth: 1)
                .scaleEffect(pulse ? 1.28 : 0.94)
                .opacity(pulse ? 0 : 0.9)

            Circle()
                .fill(
                    RadialGradient(
                        colors: [color.opacity(0.94), color.opacity(0.16), .clear],
                        center: .center,
                        startRadius: 2,
                        endRadius: size * 0.52
                    )
                )

            Circle()
                .strokeBorder(.white.opacity(0.28), lineWidth: 1)
                .padding(size * 0.17)

            HStack(spacing: size * 0.15) {
                Capsule().frame(width: size * 0.08, height: size * 0.16)
                Capsule().frame(width: size * 0.08, height: size * 0.16)
            }
            .foregroundStyle(.white)
            .scaleEffect(x: 1, y: eyeScaleY, anchor: .center)
            .offset(gaze)
            .rotationEffect(.degrees(mood == .defeated ? 90 : 0))
        }
        .frame(width: size, height: size)
        .rotationEffect(.degrees(tilt))
        .offset(y: floats ? -size * 0.025 : size * 0.025)
        .shadow(color: color.opacity(0.7), radius: size * 0.22)
        .onAppear {
            guard !reduceMotion else { return }
            withAnimation(.easeOut(duration: 1.8).repeatForever(autoreverses: false)) {
                pulse = true
            }
            withAnimation(.easeInOut(duration: 3.2).repeatForever(autoreverses: true)) {
                floats = true
            }
        }
        .task(id: animationID) {
            eyeScaleY = 1
            gaze = .zero
            tilt = 0

            guard !reduceMotion, mood != .defeated else { return }

            while !Task.isCancelled {
                try? await Task.sleep(
                    nanoseconds: UInt64(Double.random(in: 1.8...4.2) * 1_000_000_000)
                )
                guard !Task.isCancelled else { return }

                await blink()

                if Int.random(in: 0...2) > 0 {
                    let direction: CGFloat = Bool.random() ? -1 : 1
                    withAnimation(.easeInOut(duration: 0.35)) {
                        gaze = CGSize(
                            width: direction * size * 0.045,
                            height: CGFloat.random(in: -size * 0.014...size * 0.014)
                        )
                        tilt = Double(direction) * 1.2
                    }

                    try? await Task.sleep(
                        nanoseconds: UInt64(Double.random(in: 0.65...1.25) * 1_000_000_000)
                    )

                    withAnimation(.easeInOut(duration: 0.42)) {
                        gaze = .zero
                        tilt = 0
                    }
                }
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityLabel)
    }

    private var animationID: String {
        "\(mood)-\(reduceMotion)"
    }

    private var accessibilityLabel: String {
        switch mood {
        case .idle: "NOX is watching"
        case .thinking: "NOX is thinking"
        case .defeated: "NOX was outsmarted"
        }
    }

    @MainActor
    private func blink() async {
        withAnimation(.easeIn(duration: 0.08)) {
            eyeScaleY = 0.06
        }
        try? await Task.sleep(nanoseconds: 95_000_000)
        withAnimation(.spring(duration: 0.24, bounce: 0.36)) {
            eyeScaleY = 1
        }

        if Int.random(in: 0...5) == 0 {
            try? await Task.sleep(nanoseconds: 150_000_000)
            withAnimation(.easeIn(duration: 0.07)) {
                eyeScaleY = 0.08
            }
            try? await Task.sleep(nanoseconds: 85_000_000)
            withAnimation(.spring(duration: 0.22, bounce: 0.3)) {
                eyeScaleY = 1
            }
        }
    }
}

struct GlassCard<Content: View>: View {
    private let tint: Color?
    private let content: Content

    init(tint: Color? = nil, @ViewBuilder content: () -> Content) {
        self.tint = tint
        self.content = content()
    }

    var body: some View {
        content
            .padding(18)
            .frame(maxWidth: .infinity, alignment: .leading)
            .glassEffect(
                .regular.tint(tint?.opacity(0.12)),
                in: .rect(cornerRadius: 24)
            )
    }
}

struct StarRow: View {
    let count: Int
    var size: CGFloat = 15

    var body: some View {
        HStack(spacing: 3) {
            ForEach(1...3, id: \.self) { star in
                Image(systemName: star <= count ? "star.fill" : "star")
                    .font(.system(size: size, weight: .bold))
                    .foregroundStyle(star <= count ? PromptHeistDesign.amber : .white.opacity(0.2))
            }
        }
        .accessibilityLabel("\(count) of 3 stars")
    }
}

struct LocalAIChip: View {
    var body: some View {
        Label("ON-DEVICE AI", systemImage: "apple.intelligence")
            .font(.caption2.weight(.heavy))
            .tracking(1.1)
            .foregroundStyle(PromptHeistDesign.mint)
            .padding(.horizontal, 11)
            .padding(.vertical, 7)
            .glassEffect(.regular.tint(PromptHeistDesign.mint.opacity(0.18)))
            .accessibilityLabel("Runs with Apple Intelligence on this device")
    }
}
