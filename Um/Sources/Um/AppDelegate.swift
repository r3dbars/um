import AppKit
import Combine
import SwiftUI

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem!
    private var popover: NSPopover!
    private var cancellables = Set<AnyCancellable>()
    private let counter = FillerWordCounter.shared
    private let listening = ListeningController.shared

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)

        _ = Preferences.shared
        _ = NotificationManager.shared

        setupStatusItem()
        setupPopover()
        subscribe()
        updateStatusItem()

        if !Preferences.shared.hasCompletedOnboarding {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) { [weak self] in
                self?.showPopover()
            }
        }

        listening.startListening()
    }

    func applicationWillTerminate(_ notification: Notification) {
        listening.stopListening()
    }

    private func setupStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        guard let button = statusItem.button else { return }

        if let image = NSImage(systemSymbolName: "bubble.left.fill", accessibilityDescription: "Um") {
            image.isTemplate = true
            button.image = image.withSymbolConfiguration(NSImage.SymbolConfiguration(pointSize: 13, weight: .medium))
        }
        button.imagePosition = .imageLeading
        button.sendAction(on: [.leftMouseUp, .rightMouseUp])
        button.action = #selector(handleStatusItemClick(_:))
        button.target = self
    }

    private func setupPopover() {
        popover = NSPopover()
        popover.contentSize = NSSize(width: 280, height: 420)
        popover.behavior = .transient
        popover.animates = true
        popover.contentViewController = NSHostingController(rootView: MenuBarView())
    }

    private func subscribe() {
        counter.$totalCount
            .combineLatest(listening.$isListening)
            .receive(on: RunLoop.main)
            .sink { [weak self] _, _ in
                self?.updateStatusItem()
            }
            .store(in: &cancellables)

        counter.$totalCount
            .dropFirst()
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                self?.pulseButton()
            }
            .store(in: &cancellables)

        NotificationCenter.default.publisher(for: .showPopover)
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                self?.showPopover()
            }
            .store(in: &cancellables)
    }

    private func updateStatusItem() {
        guard let button = statusItem.button else { return }
        let count = counter.totalCount
        button.title = " \(count)"
        button.contentTintColor = listening.isListening ? nil : .secondaryLabelColor
        button.toolTip = listening.isListening
            ? "Um is listening — \(count) filler \(count == 1 ? "word" : "words")"
            : "Um is paused — \(count) filler \(count == 1 ? "word" : "words")"
        button.setAccessibilityLabel("Um, \(count) filler words")
    }

    private func pulseButton() {
        guard let button = statusItem.button else { return }
        let original = button.contentTintColor
        button.contentTintColor = .systemOrange
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.18) {
            button.contentTintColor = original
        }
    }

    @objc private func handleStatusItemClick(_ sender: NSStatusBarButton) {
        guard let event = NSApp.currentEvent else {
            togglePopover()
            return
        }
        if event.type == .rightMouseUp {
            showStatusMenu()
        } else {
            togglePopover()
        }
    }

    private func togglePopover() {
        if popover.isShown {
            popover.performClose(nil)
        } else {
            showPopover()
        }
    }

    private func showPopover() {
        guard let button = statusItem.button else { return }
        popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
        NSApp.activate(ignoringOtherApps: true)
    }

    private func showStatusMenu() {
        let menu = NSMenu()
        let toggle = NSMenuItem(
            title: listening.isListening ? "Stop Listening" : "Start Listening",
            action: #selector(toggleListening),
            keyEquivalent: ""
        )
        toggle.target = self
        menu.addItem(toggle)

        let reset = NSMenuItem(title: "Reset Count", action: #selector(resetCount), keyEquivalent: "")
        reset.target = self
        menu.addItem(reset)
        menu.addItem(.separator())

        let quit = NSMenuItem(title: "Quit Um", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        menu.addItem(quit)

        statusItem.menu = menu
        statusItem.button?.performClick(nil)
        statusItem.menu = nil
    }

    @objc private func toggleListening() {
        if listening.isListening {
            listening.stopListening()
        } else {
            listening.startListening()
        }
    }

    @objc private func resetCount() {
        listening.stopListening()
        counter.resetCounts()
    }
}
