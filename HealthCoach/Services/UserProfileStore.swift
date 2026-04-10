import Foundation
import Observation

@Observable
final class UserProfileStore {
    private let defaults: UserDefaults

    private(set) var settings: UserSettings
    private(set) var preferences: UserPreferences

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        let rawSettings = Self.loadSettings(from: defaults)
        let rawPrefs = Self.loadPreferences(from: defaults)
        self.settings = UserSettings.mergedFromStorage(rawSettings)
        self.preferences = UserPreferences.mergedFromStorage(rawPrefs)
        Self.ensurePersistedDefaults(settings: self.settings, preferences: self.preferences, defaults: defaults)
    }

    func replaceSettings(_ newValue: UserSettings) {
        settings = UserSettings.mergedFromStorage(newValue)
    }

    func replacePreferences(_ newValue: UserPreferences) {
        preferences = UserPreferences.mergedFromStorage(newValue)
    }

    /// Persists profile settings (personal info). Applies Streamlit-aligned normalization.
    func saveSettings(_ draft: UserSettings) throws {
        let normalized = UserProfileValidation.normalizedSettingsForSave(draft)
        settings = normalized
        try Self.encode(settings, forKey: Self.settingsKey, defaults: defaults)
    }

    /// Persists nutrition/training preferences. Validates macro sum and ranges; applies Python cast-style rounding.
    func savePreferences(_ draft: UserPreferences) throws {
        let normalized = UserProfileValidation.normalizedPreferencesForSave(draft)
        if let err = UserProfileValidation.validatePreferencesForSave(normalized) {
            throw UserProfileSaveError.validation(err)
        }
        preferences = normalized
        try Self.encode(preferences, forKey: Self.preferencesKey, defaults: defaults)
    }

    // MARK: - Keys (do not remove in clear local data)

    static let settingsKey = "com.jannik.healthcoach.userSettings.v1"
    static let preferencesKey = "com.jannik.healthcoach.userPreferences.v1"

    private static let encoder: JSONEncoder = {
        let e = JSONEncoder()
        return e
    }()

    private static let decoder: JSONDecoder = {
        let d = JSONDecoder()
        return d
    }()

    private static func loadSettings(from defaults: UserDefaults) -> UserSettings? {
        guard let data = defaults.data(forKey: settingsKey) else { return nil }
        return try? decoder.decode(UserSettings.self, from: data)
    }

    private static func loadPreferences(from defaults: UserDefaults) -> UserPreferences? {
        guard let data = defaults.data(forKey: preferencesKey) else { return nil }
        return try? decoder.decode(UserPreferences.self, from: data)
    }

    private static func encode<T: Encodable>(_ value: T, forKey key: String, defaults: UserDefaults) throws {
        let data = try encoder.encode(value)
        defaults.set(data, forKey: key)
    }

    /// Matches Python `ensure_*_table` inserting defaults when missing.
    private static func ensurePersistedDefaults(
        settings: UserSettings,
        preferences: UserPreferences,
        defaults: UserDefaults
    ) {
        if defaults.data(forKey: settingsKey) == nil {
            try? encode(settings, forKey: settingsKey, defaults: defaults)
        }
        if defaults.data(forKey: preferencesKey) == nil {
            try? encode(preferences, forKey: preferencesKey, defaults: defaults)
        }
    }
}

enum UserProfileSaveError: Error, LocalizedError {
    case validation(String)

    var errorDescription: String? {
        switch self {
        case .validation(let s): return s
        }
    }
}
