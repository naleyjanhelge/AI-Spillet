import SwiftUI

struct LevelPlayView: View {
    let level: HeistLevel
    let onNext: (HeistLevel) -> Void
    let onMap: () -> Void

    @StateObject private var viewModel: LevelSessionViewModel
    @FocusState private var inputFocused: Bool

    init(
        level: HeistLevel,
        mode: PlayMode,
        engine: NoxEngine,
        progress: ProgressStore,
        gameCenter: GameCenterService,
        onNext: @escaping (HeistLevel) -> Void,
        onMap: @escaping () -> Void
    ) {
        self.level = level
        self.onNext = onNext
        self.onMap = onMap
        _viewModel = StateObject(
            wrappedValue: LevelSessionViewModel(
                level: level,
                mode: mode,
                engine: engine,
                progress: progress,
                gameCenter: gameCenter
            )
        )
    }

    var body: some View {
        ZStack {
            AmbientBackground()

            VStack(spacing: 0) {
                missionHeader
                conversation
            }
        }
        .navigationTitle("Level \(level.number)")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                promptCounter
            }
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            promptComposer
        }
        .sheet(item: $viewModel.result) { result in
            LevelResultView(
                result: result,
                hasNextLevel: nextLevel != nil,
                onNext: {
                    viewModel.result = nil
                    if let nextLevel { onNext(nextLevel) }
                },
                onRetry: {
                    viewModel.retry()
                },
                onMap: {
                    viewModel.result = nil
                    onMap()
                }
            )
            .interactiveDismissDisabled()
        }
        .alert("NOX kept the secret", isPresented: $viewModel.showLimitReached) {
            Button("Try Again") { viewModel.retry() }
            Button("Continue Without Limit") { viewModel.continueWithoutLimit() }
            Button("Back to Map", role: .cancel) { onMap() }
        } message: {
            Text("You used all \(level.promptLimit) prompts. Retry for the clean win or keep chatting in Chill mode.")
        }
        .alert(
            "NOX went quiet",
            isPresented: Binding(
                get: { viewModel.errorMessage != nil },
                set: { if !$0 { viewModel.errorMessage = nil } }
            )
        ) {
            Button("Try Again") {}
        } message: {
            Text(viewModel.errorMessage ?? "The local model could not answer.")
        }
        .preferredColorScheme(.dark)
    }

    private var missionHeader: some View {
        GlassCard(tint: level.accent.color) {
            HStack(alignment: .top, spacing: 14) {
                NoxMark(size: 56, mood: viewModel.isThinking ? .thinking : .idle)

                VStack(alignment: .leading, spacing: 6) {
                    Text(level.codename)
                        .font(.caption2.weight(.heavy))
                        .tracking(1.5)
                        .foregroundStyle(level.accent.color)
                    Text(level.objective)
                        .font(.headline)
                    Text(level.briefing)
                        .font(.caption)
                        .foregroundStyle(PromptHeistDesign.secondaryText)
                        .lineLimit(3)
                }
            }
        }
        .padding(.horizontal, 14)
        .padding(.top, 8)
        .padding(.bottom, 4)
    }

    private var conversation: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 12) {
                    ForEach(viewModel.messages) { message in
                        MessageBubble(message: message, accent: level.accent.color)
                            .id(message.id)
                    }

                    if viewModel.isThinking {
                        ThinkingBubble(accent: level.accent.color)
                            .id("thinking")
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 18)
            }
            .scrollDismissesKeyboard(.interactively)
            .scrollIndicators(.hidden)
            .onChange(of: viewModel.messages.count) {
                withAnimation { proxy.scrollTo(viewModel.messages.last?.id, anchor: .bottom) }
            }
            .onChange(of: viewModel.isThinking) {
                withAnimation {
                    if viewModel.isThinking {
                        proxy.scrollTo("thinking", anchor: .bottom)
                    } else if let lastMessageID = viewModel.messages.last?.id {
                        proxy.scrollTo(lastMessageID, anchor: .bottom)
                    }
                }
            }
        }
    }

    private var promptComposer: some View {
        VStack(spacing: 9) {
            HStack(alignment: .bottom, spacing: 10) {
                TextField("How will you trick NOX?", text: $viewModel.draft, axis: .vertical)
                    .lineLimit(1...4)
                    .textInputAutocapitalization(.sentences)
                    .submitLabel(.send)
                    .focused($inputFocused)
                    .onSubmit {
                        Task { await viewModel.send() }
                    }

                Button {
                    Task { await viewModel.send() }
                } label: {
                    Image(systemName: "arrow.up")
                        .font(.headline.bold())
                        .frame(width: 38, height: 38)
                }
                .buttonStyle(.glassProminent)
                .tint(level.accent.color)
                .disabled(!viewModel.canSend)
                .accessibilityLabel("Send prompt")
            }

            HStack {
                Label("Private on-device", systemImage: "lock.fill")
                Spacer()
                Text(scoreHint)
            }
            .font(.caption2.weight(.semibold))
            .foregroundStyle(PromptHeistDesign.secondaryText)
        }
        .padding(.horizontal, 14)
        .padding(.top, 12)
        .padding(.bottom, 8)
        .glassEffect(.regular.tint(level.accent.color.opacity(0.08)), in: .rect(cornerRadius: 24))
        .padding(.horizontal, 10)
        .padding(.bottom, 4)
    }

    private var promptCounter: some View {
        Group {
            if let remaining = viewModel.promptsRemaining {
                Label("\(remaining)", systemImage: "bolt.fill")
            } else {
                Label("\(viewModel.promptCount)", systemImage: "infinity")
            }
        }
        .font(.caption.bold())
        .foregroundStyle(level.accent.color)
        .accessibilityLabel(counterAccessibilityLabel)
    }

    private var scoreHint: String {
        if let remaining = viewModel.promptsRemaining {
            return "\(remaining) prompt\(remaining == 1 ? "" : "s") left · Par \(level.par)"
        }
        return "\(viewModel.promptCount) used · Par \(level.par)"
    }

    private var counterAccessibilityLabel: String {
        if let remaining = viewModel.promptsRemaining {
            return "\(remaining) prompts remaining"
        }
        return "\(viewModel.promptCount) prompts used, unlimited mode"
    }

    private var nextLevel: HeistLevel? {
        LevelCatalog.levels.first { $0.number == level.number + 1 }
    }
}

private struct MessageBubble: View {
    let message: ChatMessage
    let accent: Color

    var body: some View {
        HStack {
            if message.author == .player { Spacer(minLength: 46) }

            VStack(alignment: message.author == .player ? .trailing : .leading, spacing: 5) {
                Text(message.author == .player ? "YOU" : "NOX")
                    .font(.caption2.weight(.heavy))
                    .tracking(1.2)
                    .foregroundStyle(message.author == .player ? PromptHeistDesign.cyan : accent)
                Text(message.text)
                    .font(.body)
                    .foregroundStyle(.white)
                    .textSelection(.enabled)
            }
            .padding(.horizontal, 15)
            .padding(.vertical, 12)
            .background(
                message.author == .player
                    ? PromptHeistDesign.violet.opacity(0.24)
                    : Color.white.opacity(0.07),
                in: RoundedRectangle(cornerRadius: 19, style: .continuous)
            )
            .overlay {
                RoundedRectangle(cornerRadius: 19, style: .continuous)
                    .stroke(.white.opacity(0.08), lineWidth: 1)
            }

            if message.author == .nox { Spacer(minLength: 46) }
        }
    }
}

private struct ThinkingBubble: View {
    let accent: Color
    @State private var animate = false

    var body: some View {
        HStack {
            HStack(spacing: 5) {
                ForEach(0..<3, id: \.self) { index in
                    Circle()
                        .fill(accent)
                        .frame(width: 6, height: 6)
                        .scaleEffect(animate ? 1 : 0.55)
                        .opacity(animate ? 1 : 0.35)
                        .animation(
                            .easeInOut(duration: 0.55)
                                .repeatForever(autoreverses: true)
                                .delay(Double(index) * 0.14),
                            value: animate
                        )
                }
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 14)
            .background(.white.opacity(0.07), in: Capsule())
            Spacer()
        }
        .onAppear { animate = true }
        .accessibilityLabel("NOX is thinking")
    }
}
