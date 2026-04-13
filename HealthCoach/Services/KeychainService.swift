import Foundation
import Security

final class KeychainService {
    static let shared = KeychainService()
    private let hevyServiceKey = "com.jannik.healthcoach.hevy-api-key"
    private let anthropicServiceKey = "com.jannik.healthcoach.anthropic-api-key"

    private init() {}

    // MARK: - Generic helpers

    private func save(_ value: String, forService service: String) -> Bool {
        guard let data = value.data(using: .utf8) else { return false }
        delete(forService: service)
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlock,
        ]
        return SecItemAdd(query as CFDictionary, nil) == errSecSuccess
    }

    private func retrieve(forService service: String) -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne,
        ]
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        guard status == errSecSuccess, let data = result as? Data else { return nil }
        return String(data: data, encoding: .utf8)
    }

    @discardableResult
    private func delete(forService service: String) -> Bool {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
        ]
        return SecItemDelete(query as CFDictionary) == errSecSuccess
    }

    // MARK: - Hevy API Key

    func save(apiKey: String) -> Bool {
        save(apiKey, forService: hevyServiceKey)
    }

    func retrieve() -> String? {
        retrieve(forService: hevyServiceKey)
    }

    @discardableResult
    func delete() -> Bool {
        delete(forService: hevyServiceKey)
    }

    // MARK: - Anthropic API Key

    @discardableResult
    func saveAnthropicKey(_ key: String) -> Bool {
        save(key, forService: anthropicServiceKey)
    }

    func retrieveAnthropicKey() -> String? {
        retrieve(forService: anthropicServiceKey)
    }

    @discardableResult
    func deleteAnthropicKey() -> Bool {
        delete(forService: anthropicServiceKey)
    }
}
