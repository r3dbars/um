import AppKit
import SwiftUI
import Combine

class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem!
    private var popover: NSPopover!
    private var cancellables = Set<AnyCancellable>()
    private let counter = FillerWordCounter.shared

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Hide dock icon — menu bar only
        NSApp.setActivationPolicy(.accessory)

        // Initialize preferences so word list is synced
        _ = Preferences.shared
        // Initialize notification manager
        _ = NotificationManager.shared

        setupStatusItem()
        setupPopover()
        subscribeToCounter()

        // Auto-start listening — fully on-device, no reason to wait
        WhisperManager.shared.startListening()
    }

    private func setupStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        guard let button = statusItem.button else { return }

        // Use SF Symbol speech bubble icon + count
        if let image = NSImage(systemSymbolName: "bubble.left.fill",
                               accessibilityDescription: "Um") {
            image.isTemplate = true
            let config = NSImage.SymbolConfiguration(pointSize: 13, weight: .medium)
            button.image = image.withSymbolConfiguration(config)
        }
        button.title = " 0"
        button.imagePosition = .imageLeading
        button.action = #selector(togglePopover(_:))
        button.target = self
    }

    private func setupPopover() {
        popover = NSPopover()
        popover.contentSize = NSSize(width: 280, height: 400)
        popover.behavior = .transient
        popover.animates = true
        popover.contentViewController = NSHostingController(rootView: MenuBarView())
    }

    private func subscribeToCounter() {
        counter.$totalCount
            .receive(on: RunLoop.main)
            .sink { [weak self] count in
                self?.statusItem.button?.title = " \(count)"
            }
            .store(in: &cancellables)

        // Pulse the button color when a new filler word is detected
        counter.$totalCount
            .dropFirst()
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                self?.pulseButton()
            }
            .store(in: &cancellables)
    }

    private func pulseButton() {
        guard let button = statusItem.button else { return }
        let original = button.contentTintColor
        button.contentTintColor = .systemOrange
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
            button.contentTintColor = original
        }
    }

    @objc func togglePopover(_ sender: NSStatusBarButton) {
        guard let button = statusItem.button else { return }
        if popover.isShown {
            popover.performClose(nil)
        } else {
            popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
            NSApp.activate(ignoringOtherApps: true)
        }
    }
}
