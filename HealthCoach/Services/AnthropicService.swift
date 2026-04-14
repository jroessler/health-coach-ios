import Foundation

// REST client for the Anthropic Messages API.
// Uses URLSession directly — no third-party SDK.

enum AnthropicError: LocalizedError {
    case missingAPIKey
    case missingSystemPrompt
    case httpError(statusCode: Int, body: String)
    case decodingError(String)
    case networkError(Error)

    var errorDescription: String? {
        switch self {
        case .missingAPIKey:
            return "Anthropic API key not set. Add it in Settings → AI Coach."
        case .missingSystemPrompt:
            return "System prompt file (coach_system_prompt.md) not found in app bundle."
        case .httpError(let code, let body):
            return "API error \(code): \(body)"
        case .decodingError(let msg):
            return "Failed to parse API response: \(msg)"
        case .networkError(let err):
            return "Network error: \(err.localizedDescription)"
        }
    }
}

struct AnthropicService {

    private static let endpoint = URL(string: "https://api.anthropic.com/v1/messages")!
    private static let model = "claude-sonnet-4-5"
    private static let maxTokens = 16384
    private static let chatMaxTokens = 4096
    private static let apiVersion = "2023-06-01"

    // MARK: - Public API

    /// Builds and sends the coaching summary request.
    static func generateSummary(payload: CoachPayload, apiKey: String) async throws -> String {
        let systemPrompt = try buildSystemPrompt(targets: payload.targets, profile: payload.userProfile)
        let userMessage  = buildUserMessage(payload: payload)

        return try await callAPI(system: systemPrompt, userMessage: userMessage, apiKey: apiKey)
    }

    /// Sends one turn in an interactive chat session.
    /// - Parameters:
    ///   - targets: Current user targets (used for the system prompt).
    ///   - profile: Current user profile (used for the system prompt).
    ///   - snapshotJSON: The JSON-encoded CoachPayload frozen when the conversation was created.
    ///   - history: All prior messages for this conversation, ordered oldest → newest.
    ///   - userMessage: The new message the user just typed.
    ///   - apiKey: Anthropic API key.
    /// - Returns: The assistant's reply as a plain string.
    static func sendChatTurn(
        targets: CoachTargets,
        profile: CoachUserProfile,
        snapshotJSON: String,
        history: [ChatMessage],
        userMessage: String,
        apiKey: String
    ) async throws -> String {
        let systemPrompt = try buildChatSystemPrompt(targets: targets, profile: profile)
        let messages = buildChatMessages(snapshotJSON: snapshotJSON, history: history, userMessage: userMessage)

        return try await callChatAPI(system: systemPrompt, messages: messages, apiKey: apiKey)
    }

    // MARK: - Prompt construction

    private static func buildSystemPrompt(targets: CoachTargets, profile: CoachUserProfile) throws -> String {
        guard let url = Bundle.main.url(forResource: "coach_system_prompt", withExtension: "md"),
              let base = try? String(contentsOf: url, encoding: .utf8) else {
            throw AnthropicError.missingSystemPrompt
        }

        let targetsTable = """
        <targets>
        | Parameter | Target |
        |---|---|
        | Macro split | Protein \(targets.proteinPct)% · Carbs \(targets.carbsPct)% · Fat \(targets.fatPct)% |
        | Protein per meal | ≥\(targets.proteinMealTargetG, format: "%.0f") g |
        | Post-workout protein | ≥\(targets.proteinPostWorkoutTargetG, format: "%.0f") g within 1–2 h |
        | Weekly weight loss | \(targets.weeklyWeightLossTargetKg) kg/wk |
        | Weekly body fat loss | \(targets.weeklyBodyfatLossTargetPct) %/wk |
        | VO2 Max goal | ≥\(targets.vo2LongevityGoal, format: "%.0f") ml/kg/min |
        | Daily steps | ≥\(Int(targets.stepsGoal)) |
        | Daily standing | ≥\(Int(targets.standGoalMin)) min |
        | Daily active kcal | ≥\(Int(targets.activeKcalTarget)) kcal |
        </targets>

        <user_profile>
        \(profile.age)-year-old \(profile.gender), \(profile.heightCm, format: "%.0f") cm tall
        Training experience: \(profile.trainingExperience)
        Current phase: \(profile.dietPhase)
        </user_profile>
        """

        return base + "\n\n" + targetsTable
    }

    private static func buildChatSystemPrompt(targets: CoachTargets, profile: CoachUserProfile) throws -> String {
        guard let url = Bundle.main.url(forResource: "coach_chat_system_prompt", withExtension: "md"),
              let base = try? String(contentsOf: url, encoding: .utf8) else {
            throw AnthropicError.missingSystemPrompt
        }

        let targetsTable = """
        <targets>
        | Parameter | Target |
        |---|---|
        | Macro split | Protein \(targets.proteinPct)% · Carbs \(targets.carbsPct)% · Fat \(targets.fatPct)% |
        | Protein per meal | ≥\(targets.proteinMealTargetG, format: "%.0f") g |
        | Post-workout protein | ≥\(targets.proteinPostWorkoutTargetG, format: "%.0f") g within 1–2 h |
        | Weekly weight loss | \(targets.weeklyWeightLossTargetKg) kg/wk |
        | Weekly body fat loss | \(targets.weeklyBodyfatLossTargetPct) %/wk |
        | VO2 Max goal | ≥\(targets.vo2LongevityGoal, format: "%.0f") ml/kg/min |
        | Daily steps | ≥\(Int(targets.stepsGoal)) |
        | Daily standing | ≥\(Int(targets.standGoalMin)) min |
        | Daily active kcal | ≥\(Int(targets.activeKcalTarget)) kcal |
        </targets>

        <user_profile>
        \(profile.age)-year-old \(profile.gender), \(profile.heightCm, format: "%.0f") cm tall
        Training experience: \(profile.trainingExperience)
        Current phase: \(profile.dietPhase)
        </user_profile>
        """

        return base + "\n\n" + targetsTable
    }

    /// Builds the messages array for the chat API call.
    /// Uses a synthetic context prefix: first user message contains the frozen snapshot JSON,
    /// followed by a fixed assistant acknowledgment, then the real conversation history,
    /// and finally the new user message appended at the end.
    private static func buildChatMessages(
        snapshotJSON: String,
        history: [ChatMessage],
        userMessage: String
    ) -> [[String: String]] {
        let contextMessage = "<health_data>\n\(snapshotJSON)\n</health_data>\n\nAbove is my latest health data snapshot. Use it to answer my questions."
        let acknowledgment = "Understood — I've ingested your health data snapshot and I'm ready to help. What would you like to know?"

        var messages: [[String: String]] = [
            ["role": "user",      "content": contextMessage],
            ["role": "assistant", "content": acknowledgment],
        ]

        for msg in history {
            messages.append(["role": msg.role, "content": msg.content])
        }

        messages.append(["role": "user", "content": userMessage])
        return messages
    }

    private static func buildUserMessage(payload: CoachPayload) -> String {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let json: String
        if let data = try? encoder.encode(payload),
           let str = String(data: data, encoding: .utf8) {
            json = str
        } else {
            json = "{}"
        }
        return "<health_data>\n\(json)\n</health_data>\n\nGenerate the Weekly Summary report for the period shown in the data above."
    }

    // MARK: - API call

    private static func callChatAPI(system: String, messages: [[String: String]], apiKey: String) async throws -> String {
        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.setValue(apiKey, forHTTPHeaderField: "x-api-key")
        request.setValue(apiVersion, forHTTPHeaderField: "anthropic-version")
        request.setValue("application/json", forHTTPHeaderField: "content-type")
        request.timeoutInterval = 120

        let body: [String: Any] = [
            "model": model,
            "max_tokens": chatMaxTokens,
            "system": system,
            "messages": messages
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response): (Data, URLResponse)
        do {
            (data, response) = try await URLSession.shared.data(for: request)
        } catch {
            throw AnthropicError.networkError(error)
        }

        if let http = response as? HTTPURLResponse, http.statusCode != 200 {
            let bodyStr = String(data: data, encoding: .utf8) ?? "<no body>"
            throw AnthropicError.httpError(statusCode: http.statusCode, body: bodyStr)
        }

        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let content = (json["content"] as? [[String: Any]])?.first,
              let text = content["text"] as? String else {
            let raw = String(data: data, encoding: .utf8) ?? "<empty>"
            throw AnthropicError.decodingError(raw)
        }

        return text
    }

    private static func callAPI(system: String, userMessage: String, apiKey: String) async throws -> String {
        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.setValue(apiKey, forHTTPHeaderField: "x-api-key")
        request.setValue(apiVersion, forHTTPHeaderField: "anthropic-version")
        request.setValue("application/json", forHTTPHeaderField: "content-type")
        request.timeoutInterval = 120

        let body: [String: Any] = [
            "model": model,
            "max_tokens": maxTokens,
            "system": system,
            "messages": [
                ["role": "user", "content": userMessage]
            ]
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response): (Data, URLResponse)
        do {
            (data, response) = try await URLSession.shared.data(for: request)
        } catch {
            throw AnthropicError.networkError(error)
        }

        if let http = response as? HTTPURLResponse, http.statusCode != 200 {
            let bodyStr = String(data: data, encoding: .utf8) ?? "<no body>"
            throw AnthropicError.httpError(statusCode: http.statusCode, body: bodyStr)
        }

        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let content = (json["content"] as? [[String: Any]])?.first,
              let text = content["text"] as? String else {
            let raw = String(data: data, encoding: .utf8) ?? "<empty>"
            throw AnthropicError.decodingError(raw)
        }

        return text
    }
}

// MARK: - Formatting helper

private extension Double {
    func formatted(format: String) -> String {
        String(format: format, self)
    }
}

private extension DefaultStringInterpolation {
    mutating func appendInterpolation(_ value: Double, format: String) {
        appendInterpolation(String(format: format, value))
    }
}
