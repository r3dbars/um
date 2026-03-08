import Foundation
import UserNotifications
import Combine

/// Sends threshold notifications when filler word count exceeds a user-set limit.
class NotificationManager: ObservableObject {
    static let shared = NotificationManager()

    private let center: UNUserNotificationCenter?
    private var cancellables = Set<AnyCancellable>()
    private var lastNotifiedCount: Int = 0
    private let prefs = Preferences.shared

    init() {
        // UNUserNotificationCenter requires a proper .app bundle.
        // When running via `swift build`, Bundle.main has no bundleIdentifier,
        // so we guard against the crash and degrade gracefully.
        if Bundle.main.bundleIdentifier != nil {
            center = UNUserNotificationCenter.current()
        } else {
            center = nil
        }
        subscribeToCounter()
    }

    func requestPermission() {
        center?.requestAuthorization(options: [.alert, .sound]) { granted, error in
            if let error {
                print("Notifications: \(error.localizedDescription)")
            }
        }
    }

    private func subscribeToCounter() {
        FillerWordCounter.shared.$totalCount
            .receive(on: RunLoop.main)
            .sink { [weak self] count in
                self?.checkThreshold(count)
            }
            .store(in: &cancellables)
    }

    private func checkThreshold(_ count: Int) {
        guard prefs.notificationsEnabled else { return }
        let threshold = prefs.notificationThreshold
        guard threshold > 0 else { return }

        // Notify at each multiple of the threshold (20, 40, 60, ...)
        let currentStep = count / threshold
        let lastStep = lastNotifiedCount / threshold

        if currentStep > lastStep && count > 0 {
            sendNotification(count: count)
        }
        lastNotifiedCount = count
    }

    private func sendNotification(count: Int) {
        let content = UNMutableNotificationContent()
        content.title = "Um"
        content.body = "You've hit \(count) filler words this session."
        content.sound = .default

        let request = UNNotificationRequest(
            identifier: "um-threshold-\(count)",
            content: content,
            trigger: nil
        )
        center?.add(request)
    }

    /// Reset tracking when a new session starts
    func resetTracking() {
        lastNotifiedCount = 0
    }
}
