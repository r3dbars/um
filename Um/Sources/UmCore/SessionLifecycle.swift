import Foundation

/// Start/stop rules for a listening session.
///
/// History is written only when a session is active and lasts at least
/// ``minimumPersistDuration``. Stopping capture (an engine switch) does not
/// end the session, so a second `stopSession` cannot invent another row.
public struct SessionLifecycle: Equatable, Sendable {
    public static let minimumPersistDuration: TimeInterval = 5

    public private(set) var isActive: Bool
    public private(set) var persistedCount: Int

    public init(isActive: Bool = false) {
        self.isActive = isActive
        self.persistedCount = 0
    }

    public static func shouldPersist(duration: TimeInterval) -> Bool {
        duration >= minimumPersistDuration
    }

    public mutating func startSession() {
        guard !isActive else { return }
        isActive = true
    }

    /// Ends the session if it is active. Returns whether history should be written.
    @discardableResult
    public mutating func stopSession(duration: TimeInterval) -> Bool {
        guard isActive else { return false }
        isActive = false
        guard Self.shouldPersist(duration: duration) else { return false }
        persistedCount += 1
        return true
    }

    /// Tears down audio only. Does not end the session.
    public mutating func stopCapture() {}
}
