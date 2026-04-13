import SwiftUI
import SwiftData

// MARK: - CoachTabView (top-level Coach tab)

struct CoachTabView: View {
    @State private var selectedTab = 0

    private let bgColor    = Color(hex: 0x02161C)
    private let accentCyan = Color(hex: 0x22D3EE)

    var body: some View {
        AISummaryView(selectedTab: $selectedTab)
    }
}

// MARK: - AISummaryView (inner view — handles both Summaries and Chat tabs)

struct AISummaryView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(UserProfileStore.self) private var profileStore

    @Binding var selectedTab: Int

    @State private var shortTermDays = 14
    @State private var longTermDays  = 60
    @State private var state: CoachState = .idle
    @State private var showSettings = false
    @State private var showHistory  = false

    private let bgColor    = Color(hex: 0x02161C)
    private let cardBg     = Color(hex: 0x0A1A24)
    private let accentCyan = Color(hex: 0x22D3EE)

    // MARK: - View

    var body: some View {
        NavigationStack {
            ZStack(alignment: .top) {
                bgColor.ignoresSafeArea()

                VStack(spacing: 0) {
                    // Segmented picker pinned below nav bar
                    Picker("Coach Mode", selection: $selectedTab) {
                        Text("Summaries").tag(0)
                        Text("Chat").tag(1)
                    }
                    .pickerStyle(.segmented)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(bgColor)

                    Divider()
                        .background(Color.white.opacity(0.08))

                    if selectedTab == 0 {
                        summariesContent
                    } else {
                        CoachChatListView()
                    }
                }
            }
            .navigationTitle("AI Coach")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(bgColor, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                if selectedTab == 0 {
                    ToolbarItem(placement: .topBarLeading) {
                        Button { showHistory = true } label: {
                            Image(systemName: "clock.arrow.trianglehead.counterclockwise.rotate.90")
                                .foregroundStyle(accentCyan)
                        }
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button { showSettings = true } label: {
                        Image(systemName: "gearshape")
                            .foregroundStyle(accentCyan)
                    }
                }
            }
            .sheet(isPresented: $showSettings) { SettingsView() }
            .sheet(isPresented: $showHistory)  { SummaryHistoryView() }
        }
    }

    // MARK: - Summaries content

    private var summariesContent: some View {
        ScrollView {
            VStack(spacing: 20) {
                configCard
                generateButton
                resultArea
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 96)
        }
    }

    // MARK: - Config card

    private var configCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Analysis Windows")
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundStyle(.secondary)

            HStack {
                Text("Short-term")
                    .foregroundStyle(.white)
                Spacer()
                Stepper("\(shortTermDays) days", value: $shortTermDays, in: 7...30)
                    .fixedSize()
                    .foregroundStyle(accentCyan)
            }

            Divider().background(Color.white.opacity(0.1))

            HStack {
                Text("Long-term")
                    .foregroundStyle(.white)
                Spacer()
                Stepper("\(longTermDays) days", value: $longTermDays, in: 30...180, step: 5)
                    .fixedSize()
                    .foregroundStyle(accentCyan)
            }

            if longTermDays < shortTermDays {
                Text("Long-term window should be ≥ short-term.")
                    .font(.caption)
                    .foregroundStyle(.orange)
            }
        }
        .padding(16)
        .background(cardBg)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    // MARK: - Generate button

    private var generateButton: some View {
        Button {
            guard !state.isLoading else { return }
            Task { await generate() }
        } label: {
            HStack(spacing: 8) {
                if state.isLoading {
                    ProgressView()
                        .controlSize(.small)
                        .tint(.black)
                } else {
                    Image(systemName: "sparkles")
                }
                Text(state.isLoading ? state.loadingMessage : "Generate Summary")
                    .fontWeight(.semibold)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 50)
            .background(state.isLoading ? accentCyan.opacity(0.6) : accentCyan)
            .foregroundStyle(.black)
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
        .disabled(state.isLoading)
        .animation(.easeInOut(duration: 0.2), value: state.isLoading)
    }

    // MARK: - Result area

    @ViewBuilder
    private var resultArea: some View {
        switch state {
        case .idle:
            idlePlaceholder
        case .loading:
            EmptyView()
        case .success(let markdown):
            summaryCard(markdown)
        case .error(let msg):
            errorCard(msg)
        }
    }

    private var idlePlaceholder: some View {
        VStack(spacing: 12) {
            Image(systemName: "brain.head.profile")
                .font(.system(size: 44))
                .foregroundStyle(accentCyan.opacity(0.5))
            Text("Set your analysis windows above and tap **Generate Summary** to receive a personalised coaching report covering nutrition, training, and recovery.")
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
                .font(.subheadline)
        }
        .padding(.top, 40)
        .padding(.horizontal, 8)
    }

    private func summaryCard(_ markdown: String) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text("Summary")
                    .font(.headline)
                    .foregroundStyle(.white)
                Spacer()
                ShareLink(item: markdown) {
                    Image(systemName: "square.and.arrow.up")
                        .foregroundStyle(accentCyan)
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 16)
            .padding(.bottom, 12)

            Divider().background(Color.white.opacity(0.1))

            CoachMarkdownView(markdown: markdown)
                .padding(16)
        }
        .background(cardBg)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private func errorCard(_ message: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(.orange)
                .font(.title3)
            Text(message)
                .foregroundStyle(.white)
                .font(.subheadline)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.orange.opacity(0.12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.orange.opacity(0.4), lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    // MARK: - Generation logic

    private func generate() async {
        guard let apiKey = KeychainService.shared.retrieveAnthropicKey(), !apiKey.isEmpty else {
            state = .error("Anthropic API key not set. Go to Settings → AI Coach to add your key.")
            return
        }

        let effectiveLongTerm = max(longTermDays, shortTermDays)

        state = .loading("Building data snapshot…")

        let payload = await CoachSnapshotBuilder.build(
            shortTermDays: shortTermDays,
            longTermDays: effectiveLongTerm,
            modelContainer: modelContext.container,
            settings: profileStore.settings,
            preferences: profileStore.preferences
        )

        state = .loading("Generating summary…")

        do {
            let summary = try await AnthropicService.generateSummary(payload: payload, apiKey: apiKey)
            saveSummary(summary, shortTermDays: shortTermDays, longTermDays: effectiveLongTerm)
            state = .success(summary)
        } catch {
            state = .error(error.localizedDescription)
        }
    }

    private func saveSummary(_ markdown: String, shortTermDays: Int, longTermDays: Int) {
        let record = CoachSummary(
            generatedAt: Date(),
            shortTermDays: shortTermDays,
            longTermDays: longTermDays,
            markdownContent: markdown
        )
        modelContext.insert(record)
    }
}

// MARK: - Coach state

enum CoachState {
    case idle
    case loading(String)
    case success(String)
    case error(String)

    var isLoading: Bool {
        if case .loading = self { return true }
        return false
    }

    var loadingMessage: String {
        if case .loading(let msg) = self { return msg }
        return "Loading…"
    }
}

extension CoachState: Equatable {
    static func == (lhs: CoachState, rhs: CoachState) -> Bool {
        switch (lhs, rhs) {
        case (.idle, .idle): return true
        case (.loading(let a), .loading(let b)): return a == b
        case (.success(let a), .success(let b)): return a == b
        case (.error(let a), .error(let b)): return a == b
        default: return false
        }
    }
}
