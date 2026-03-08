import Foundation
import Combine

/// Centralized user preferences backed by UserDefaults.
class Preferences: ObservableObject {
    static let shared = Preferences()

    private let defaults = UserDefaults.standard

    private enum Keys {
        static let customWords = "um_trackedWords"
        static let notificationsEnabled = "um_notificationsEnabled"
        static let notificationThreshold = "um_notificationThreshold"
        static let launchAtLogin = "um_launchAtLogin"
    }

    // MARK: - Custom word list

    @Published var trackedWords: [String] {
        didSet {
            defaults.set(trackedWords, forKey: Keys.customWords)
            // Sync to the counter
            FillerWordCounter.shared.updateTrackedWords(trackedWords)
        }
    }

    static let defaultWords: [String] = [
        "um", "uh", "like", "you know", "basically",
        "literally", "sort of", "kind of", "right", "so"
    ]

    // MARK: - Notifications

    @Published var notificationsEnabled: Bool {
        didSet { defaults.set(notificationsEnabled, forKey: Keys.notificationsEnabled) }
    }

    @Published var notificationThreshold: Int {
        didSet { defaults.set(notificationThreshold, forKey: Keys.notificationThreshold) }
    }

    // MARK: - Launch at login

    @Published var launchAtLogin: Bool {
        didSet {
            defaults.set(launchAtLogin, forKey: Keys.launchAtLogin)
            LaunchAtLoginHelper.setEnabled(launchAtLogin)
        }
    }

    // MARK: - Init

    init() {
        if let saved = defaults.array(forKey: Keys.customWords) as? [String], !saved.isEmpty {
            trackedWords = saved
        } else {
            trackedWords = Self.defaultWords
        }
        notificationsEnabled = defaults.bool(forKey: Keys.notificationsEnabled)
        let threshold = defaults.integer(forKey: Keys.notificationThreshold)
        notificationThreshold = threshold > 0 ? threshold : 20
        launchAtLogin = defaults.bool(forKey: Keys.launchAtLogin)
    }
}
