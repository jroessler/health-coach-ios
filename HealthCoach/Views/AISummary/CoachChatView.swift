import SwiftUI
import SwiftData
import UIKit

struct CoachChatView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(UserProfileStore.self) private var profileStore

    let conversation: ChatConversation

    @State private var inputText = ""
    @State private var isSending = false
    @State private var errorMessage: String?
    @State private var scrollProxy: ScrollViewProxy?
    @State private var dotPhase = false

    private let bgColor    = Color(hex: 0x02161C)
    private let cardBg     = Color(hex: 0x0A1A24)
    private let accentCyan = Color(hex: 0x22D3EE)
    private let userBubbleBg = Color(hex: 0x0E2D3D)

    private var canSend: Bool {
        !inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !isSending
    }

    // MARK: - Body

    var body: some View {
        ZStack(alignment: .bottom) {
            bgColor.ignoresSafeArea()

            VStack(spacing: 0) {
                messageList
                inputBar
            }
        }
        .navigationTitle(conversation.title)
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(bgColor, for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
        .toolbarColorScheme(.dark, for: .navigationBar)
    }

    // MARK: - Message list

    private var messageList: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 12) {
                    contextBanner
                        .id("top")

                    ForEach(conversation.sortedMessages) { message in
                        MessageBubble(
                            message: message,
                            accentCyan: accentCyan,
                            userBubbleBg: userBubbleBg
                        )
                        .id(message.persistentModelID)
                    }

                    if isSending {
                        typingIndicator
                    }

                    if let errorMessage {
                        errorBanner(errorMessage)
                    }

                    Color.clear.frame(height: 8).id("bottom")
                }
                .padding(.horizontal, 16)
                .padding(.top, 12)
                .padding(.bottom, 12)
            }
            .scrollDismissesKeyboard(.interactively)
            .onAppear {
                scrollProxy = proxy
                scrollToBottom(proxy: proxy, animated: false)
            }
            .onChange(of: conversation.messages.count) {
                scrollToBottom(proxy: proxy, animated: true)
            }
            .onChange(of: isSending) {
                scrollToBottom(proxy: proxy, animated: true)
            }
        }
    }

    private var contextBanner: some View {
        HStack(spacing: 8) {
            Image(systemName: "lock.fill")
                .font(.caption2)
                .foregroundStyle(.secondary)
            Text("Health snapshot frozen at \(conversation.createdAt.formatted(date: .abbreviated, time: .shortened)) · \(conversation.shortTermDays)d / \(conversation.longTermDays)d windows")
                .font(.caption2)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(Color.white.opacity(0.05))
        .clipShape(Capsule())
    }

    private var typingIndicator: some View {
        HStack(alignment: .bottom, spacing: 8) {
            Image(systemName: "brain.head.profile")
                .font(.caption)
                .foregroundStyle(accentCyan)
                .frame(width: 28, height: 28)
                .background(cardBg)
                .clipShape(Circle())

            HStack(spacing: 5) {
                ForEach(0..<3, id: \.self) { i in
                    Circle()
                        .fill(accentCyan)
                        .frame(width: 7, height: 7)
                        .scaleEffect(dotPhase ? 1.0 : 0.4)
                        .opacity(dotPhase ? 1.0 : 0.3)
                        .animation(
                            .easeInOut(duration: 0.5)
                                .repeatForever(autoreverses: true)
                                .delay(Double(i) * 0.18),
                            value: dotPhase
                        )
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .background(cardBg)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .onAppear { dotPhase = true }
            .onDisappear { dotPhase = false }

            Spacer()
        }
    }

    private func errorBanner(_ message: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(.orange)
            VStack(alignment: .leading, spacing: 4) {
                Text(message)
                    .font(.caption)
                    .foregroundStyle(.white)
                    .fixedSize(horizontal: false, vertical: true)
                Button("Dismiss") { errorMessage = nil }
                    .font(.caption)
                    .foregroundStyle(accentCyan)
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.orange.opacity(0.12))
        .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.orange.opacity(0.4), lineWidth: 1))
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }

    // MARK: - Input bar

    private var inputBar: some View {
        VStack(spacing: 0) {
            Divider()
                .background(Color.white.opacity(0.08))

            HStack(alignment: .bottom, spacing: 10) {
                ChatTextView(
                    text: $inputText,
                    placeholder: "Ask your coach…",
                    isEnabled: !isSending,
                    accentColor: accentCyan
                )
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(Color.white.opacity(0.06))
                .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))

                Button {
                    Task { await send() }
                } label: {
                    Image(systemName: "arrow.up.circle.fill")
                        .font(.system(size: 32))
                        .foregroundStyle(canSend ? accentCyan : Color.white.opacity(0.2))
                }
                .disabled(!canSend)
                .frame(width: 44, height: 44)
                .animation(.easeInOut(duration: 0.15), value: canSend)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(bgColor)
        }
    }

    // MARK: - Actions

    private func send() async {
        let text = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty, !isSending else { return }
        guard let apiKey = KeychainService.shared.retrieveAnthropicKey(), !apiKey.isEmpty else {
            errorMessage = "Anthropic API key not set. Go to Settings → AI Coach to add your key."
            return
        }

        inputText = ""
        errorMessage = nil

        let userMsg = ChatMessage(role: "user", content: text, conversation: conversation)
        modelContext.insert(userMsg)
        conversation.messages.append(userMsg)

        isSending = true

        let priorHistory = conversation.sortedMessages.filter { $0.persistentModelID != userMsg.persistentModelID }
        let (profile, targets) = CoachSnapshotBuilder.buildProfileAndTargets(
            settings: profileStore.settings,
            preferences: profileStore.preferences
        )

        do {
            let reply = try await AnthropicService.sendChatTurn(
                targets: targets,
                profile: profile,
                snapshotJSON: conversation.snapshotJSON,
                history: priorHistory,
                userMessage: text,
                apiKey: apiKey
            )

            let assistantMsg = ChatMessage(role: "assistant", content: reply, conversation: conversation)
            modelContext.insert(assistantMsg)
            conversation.messages.append(assistantMsg)
        } catch {
            // Restore the message to the input field so the user doesn't have to retype
            inputText = text
            errorMessage = friendlyErrorMessage(error)
            // Roll back the optimistically-appended user message
            if let idx = conversation.messages.firstIndex(where: { $0.persistentModelID == userMsg.persistentModelID }) {
                conversation.messages.remove(at: idx)
                modelContext.delete(userMsg)
            }
        }

        isSending = false
    }

    private func friendlyErrorMessage(_ error: Error) -> String {
        if let anthropicError = error as? AnthropicError,
           case .httpError(let code, _) = anthropicError, code == 529 {
            return "The AI service is temporarily overloaded. Your message has been restored — please try again in a moment."
        }
        return error.localizedDescription
    }

    private func scrollToBottom(proxy: ScrollViewProxy, animated: Bool) {
        if animated {
            withAnimation(.easeOut(duration: 0.3)) {
                proxy.scrollTo("bottom", anchor: .bottom)
            }
        } else {
            proxy.scrollTo("bottom", anchor: .bottom)
        }
    }
}

// MARK: - Message bubble

private struct MessageBubble: View {
    let message: ChatMessage
    let accentCyan: Color
    let userBubbleBg: Color

    private let cardBg = Color(hex: 0x0A1A24)

    var isUser: Bool { message.role == "user" }

    var body: some View {
        HStack(alignment: .bottom, spacing: 8) {
            if isUser {
                Spacer(minLength: 48)
                userBubble
            } else {
                assistantIcon
                assistantBubble
                Spacer(minLength: 48)
            }
        }
    }

    private var userBubble: some View {
        Text(message.content)
            .font(.callout)
            .foregroundStyle(.white)
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(userBubbleBg)
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(accentCyan.opacity(0.3), lineWidth: 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
    }

    private var assistantIcon: some View {
        Image(systemName: "brain.head.profile")
            .font(.caption)
            .foregroundStyle(accentCyan)
            .frame(width: 28, height: 28)
            .background(cardBg)
            .clipShape(Circle())
            .overlay(Circle().stroke(accentCyan.opacity(0.3), lineWidth: 1))
    }

    private var assistantBubble: some View {
        VStack(alignment: .leading, spacing: 0) {
            CoachMarkdownView(markdown: message.content)
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
        }
        .background(cardBg)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
    }
}

// MARK: - UITextView wrapper

private struct ChatTextView: UIViewRepresentable {
    @Binding var text: String
    let placeholder: String
    let isEnabled: Bool
    let accentColor: Color

    private static let maxHeight: CGFloat = 120

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    func makeUIView(context: Context) -> UITextView {
        let tv = UITextView()
        tv.delegate = context.coordinator
        tv.backgroundColor = .clear
        tv.font = UIFont.preferredFont(forTextStyle: .callout)
        tv.adjustsFontForContentSizeCategory = true
        tv.textColor = .white
        tv.tintColor = UIColor(accentColor)
        // Keep scrolling off — SwiftUI sizes the view via sizeThatFits.
        // We only enable scroll once content exceeds maxHeight.
        tv.isScrollEnabled = false
        tv.textContainerInset = .zero
        tv.textContainer.lineFragmentPadding = 0
        // Allows the view to shrink horizontally inside HStack
        tv.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        context.coordinator.addPlaceholder(to: tv, text: placeholder)
        return tv
    }

    func updateUIView(_ tv: UITextView, context: Context) {
        // Only mutate when text differs to avoid re-triggering layout
        if tv.text != text {
            tv.text = text
            context.coordinator.placeholderLabel?.isHidden = !text.isEmpty
        }
        tv.isEditable = isEnabled
        tv.alpha = isEnabled ? 1.0 : 0.5
    }

    /// Tells SwiftUI how tall this view should be given the available width.
    /// This is what makes the input expand as the user types.
    func sizeThatFits(_ proposal: ProposedViewSize, uiView: UITextView, context: Context) -> CGSize? {
        let width = proposal.width ?? UIScreen.main.bounds.width
        let fitting = uiView.sizeThatFits(CGSize(width: width, height: .greatestFiniteMagnitude))
        let height = min(fitting.height, Self.maxHeight)
        // Switch to scrollable once content exceeds the cap
        let shouldScroll = fitting.height > Self.maxHeight
        if uiView.isScrollEnabled != shouldScroll {
            uiView.isScrollEnabled = shouldScroll
        }
        return CGSize(width: width, height: max(height, 36))
    }

    final class Coordinator: NSObject, UITextViewDelegate {
        var parent: ChatTextView
        var placeholderLabel: UILabel?

        init(_ parent: ChatTextView) { self.parent = parent }

        func addPlaceholder(to textView: UITextView, text: String) {
            let label = UILabel()
            label.text = text
            label.font = UIFont.preferredFont(forTextStyle: .callout)
            label.textColor = UIColor.white.withAlphaComponent(0.35)
            label.translatesAutoresizingMaskIntoConstraints = false
            textView.addSubview(label)
            NSLayoutConstraint.activate([
                label.topAnchor.constraint(equalTo: textView.topAnchor),
                label.leadingAnchor.constraint(equalTo: textView.leadingAnchor),
            ])
            placeholderLabel = label
        }

        func textViewDidChange(_ textView: UITextView) {
            parent.text = textView.text
            placeholderLabel?.isHidden = !textView.text.isEmpty
            // Invalidate so SwiftUI calls sizeThatFits again
            textView.invalidateIntrinsicContentSize()
        }
    }
}
