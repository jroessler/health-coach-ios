import SwiftUI
import SwiftData

struct CoachChatListView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(UserProfileStore.self) private var profileStore

    @Query(sort: \ChatConversation.createdAt, order: .reverse)
    private var conversations: [ChatConversation]

    @State private var navigationPath = NavigationPath()
    @State private var newChatState: NewChatState = .idle
    @State private var shortTermDays = 14
    @State private var longTermDays  = 60

    private let bgColor    = Color(hex: 0x02161C)
    private let cardBg     = Color(hex: 0x0A1A24)
    private let accentCyan = Color(hex: 0x22D3EE)

    // MARK: - Body

    var body: some View {
        NavigationStack(path: $navigationPath) {
            ZStack {
                bgColor.ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 16) {
                        windowConfigCard
                        newChatButton
                        if case .error(let msg) = newChatState {
                            errorBanner(msg)
                        }
                        conversationsList
                    }
                    .padding(.horizontal, 16)
                    .padding(.bottom, 96)
                }
            }
            .navigationDestination(for: ChatConversation.self) { conversation in
                CoachChatView(conversation: conversation)
            }
        }
    }

    // MARK: - Window config card

    private var windowConfigCard: some View {
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
        }
        .padding(16)
        .background(cardBg)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    // MARK: - New chat button

    private var newChatButton: some View {
        Button {
            guard case .idle = newChatState else { return }
            Task { await startNewChat() }
        } label: {
            HStack(spacing: 8) {
                if case .building = newChatState {
                    ProgressView()
                        .controlSize(.small)
                        .tint(.black)
                    Text("Building snapshot…")
                        .fontWeight(.semibold)
                } else {
                    Image(systemName: "plus.bubble.fill")
                    Text("New Chat")
                        .fontWeight(.semibold)
                }
            }
            .frame(maxWidth: .infinity)
            .frame(height: 50)
            .background(newChatState.isBuilding ? accentCyan.opacity(0.6) : accentCyan)
            .foregroundStyle(.black)
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
        .disabled(newChatState.isBuilding)
        .animation(.easeInOut(duration: 0.2), value: newChatState.isBuilding)
    }

    // MARK: - Conversations list

    @ViewBuilder
    private var conversationsList: some View {
        if conversations.isEmpty {
            emptyState
        } else {
            VStack(alignment: .leading, spacing: 8) {
                Text("Recent Chats")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundStyle(.secondary)

                ForEach(conversations) { conversation in
                    Button {
                        navigationPath.append(conversation)
                    } label: {
                        conversationRow(conversation)
                    }
                    .buttonStyle(.plain)
                    .contextMenu {
                        Button(role: .destructive) {
                            delete(conversation)
                        } label: {
                            Label("Delete", systemImage: "trash")
                        }
                    }
                }
            }
        }
    }

    private func conversationRow(_ conversation: ChatConversation) -> some View {
        HStack(spacing: 12) {
            Image(systemName: "bubble.left.and.bubble.right.fill")
                .font(.title3)
                .foregroundStyle(accentCyan)
                .frame(width: 36)

            VStack(alignment: .leading, spacing: 4) {
                Text(conversation.title)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundStyle(.white)
                    .lineLimit(1)

                HStack(spacing: 6) {
                    Text(conversation.createdAt.formatted(date: .abbreviated, time: .shortened))
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    Text("·")
                        .foregroundStyle(.secondary)
                        .font(.caption)

                    Text("\(conversation.shortTermDays)d / \(conversation.longTermDays)d")
                        .font(.caption)
                        .foregroundStyle(accentCyan.opacity(0.8))

                    if !conversation.messages.isEmpty {
                        Text("·")
                            .foregroundStyle(.secondary)
                            .font(.caption)
                        Text("\(conversation.messages.count) msg\(conversation.messages.count == 1 ? "" : "s")")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(14)
        .background(cardBg)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "bubble.left.and.bubble.right")
                .font(.system(size: 44))
                .foregroundStyle(accentCyan.opacity(0.5))
            Text("No chats yet.\nTap **New Chat** to start a conversation with your AI coach.")
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
                .font(.subheadline)
        }
        .padding(.top, 40)
        .padding(.horizontal, 8)
    }

    private func errorBanner(_ message: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(.orange)
                .font(.title3)
            VStack(alignment: .leading, spacing: 4) {
                Text(message)
                    .foregroundStyle(.white)
                    .font(.subheadline)
                    .fixedSize(horizontal: false, vertical: true)
                Button("Dismiss") { newChatState = .idle }
                    .font(.caption)
                    .foregroundStyle(accentCyan)
            }
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

    // MARK: - Actions

    private func startNewChat() async {
        guard let apiKey = KeychainService.shared.retrieveAnthropicKey(), !apiKey.isEmpty else {
            newChatState = .error("Anthropic API key not set. Go to Settings → AI Coach to add your key.")
            return
        }

        let effectiveLongTerm = max(longTermDays, shortTermDays)
        newChatState = .building

        let payload = await CoachSnapshotBuilder.build(
            shortTermDays: shortTermDays,
            longTermDays: effectiveLongTerm,
            modelContainer: modelContext.container,
            settings: profileStore.settings,
            preferences: profileStore.preferences
        )

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let snapshotJSON: String
        if let data = try? encoder.encode(payload),
           let str = String(data: data, encoding: .utf8) {
            snapshotJSON = str
        } else {
            snapshotJSON = "{}"
        }

        let dateStr = Date.now.formatted(date: .abbreviated, time: .omitted)
        let conversation = ChatConversation(
            title: "Chat — \(dateStr)",
            shortTermDays: shortTermDays,
            longTermDays: effectiveLongTerm,
            snapshotJSON: snapshotJSON
        )
        modelContext.insert(conversation)

        newChatState = .idle
        navigationPath.append(conversation)
    }

    private func delete(_ conversation: ChatConversation) {
        modelContext.delete(conversation)
    }
}

// MARK: - New chat state

private enum NewChatState: Equatable {
    case idle
    case building
    case error(String)

    var isBuilding: Bool { self == .building }
}
