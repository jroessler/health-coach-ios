import Foundation
import SwiftData

@Model
final class ChatConversation {
    var title: String
    var createdAt: Date
    var shortTermDays: Int
    var longTermDays: Int
    /// JSON-encoded CoachPayload frozen at conversation creation time.
    var snapshotJSON: String

    @Relationship(deleteRule: .cascade, inverse: \ChatMessage.conversation)
    var messages: [ChatMessage] = []

    init(title: String, createdAt: Date = .now, shortTermDays: Int, longTermDays: Int, snapshotJSON: String) {
        self.title = title
        self.createdAt = createdAt
        self.shortTermDays = shortTermDays
        self.longTermDays = longTermDays
        self.snapshotJSON = snapshotJSON
    }

    var sortedMessages: [ChatMessage] {
        messages.sorted { $0.createdAt < $1.createdAt }
    }
}

@Model
final class ChatMessage {
    var role: String   // "user" or "assistant"
    var content: String
    var createdAt: Date
    var conversation: ChatConversation?

    init(role: String, content: String, createdAt: Date = .now, conversation: ChatConversation? = nil) {
        self.role = role
        self.content = content
        self.createdAt = createdAt
        self.conversation = conversation
    }
}
