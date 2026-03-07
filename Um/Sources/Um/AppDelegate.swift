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

        setupStatusItem()
        setupPopover()
        subscribeToCounter()
    }

    private func setupStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        guard let button = statusItem.button else { return }
        button.title = "um: 0"
        button.action = #selector(togglePopover(_:))
        button.target = self
    }

    private func setupPopover() {
        popover = NSPopover()
        popover.contentSize = NSSize(width: 280, height: 380)
        popover.behavior = .transient
        popover.animates = true
        popover.contentViewController = NSHostingController(rootView: MenuBarView())
    }

    private func subscribeToCounter() {
        counter.$totalCount
            .receive(on: RunLoop.main)
            .sink { [weak self] count in
                self?.statusItem.button?.title = "um: \(count)"
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
