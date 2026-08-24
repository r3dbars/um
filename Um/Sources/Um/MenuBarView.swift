import SwiftUI

enum AppScreen {
    case main
    case settings
    case history
}

struct MenuBarView: View {
    @StateObject private var counter = FillerWordCounter.shared
    @StateObject private var listening = ListeningController.shared
    @StateObject private var store = SessionStore.shared
    @ObservedObject private var prefs = Preferences.shared
    @State private var currentScreen: AppScreen = .main

    var body: some View {
        Group {
            switch currentScreen {
            case .main:
                mainView
            case .settings:
                SettingsView()
            case .history:
                HistoryView()
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .navigateBack)) { _ in
            withAnimation(.easeInOut(duration: 0.15)) {
                currentScreen = .main
            }
        }
    }

    private var mainView: some View {
        VStack(spacing: 0) {
            headerSection
            Divider()
            if !prefs.hasCompletedOnboarding {
                onboardingSection
                Divider()
            } else if counter.totalCount > 0 {
                countsSection
                Divider()
                statsRow
                Divider()
            } else {
                emptyState
            }
            controlsSection
            Divider()
            bottomBar
        }
        .frame(width: 280)
    }

    private var headerSection: some View {
        HStack(alignment: .center, spacing: 12) {
            VStack(alignment: .leading, spacing: 3) {
                Text("Um")
                    .font(.system(size: 20, weight: .bold))
                statusLabel
            }
            Spacer()
            totalBadge
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }

    private var statusLabel: some View {
        Group {
            if let error = listening.errorMessage, !listening.isListening {
                Label(error, systemImage: "exclamationmark.triangle.fill")
                    .foregroundColor(.red)
                    .lineLimit(2)
            } else if listening.isListening {
                Label(listening.usesWhisper ? "Listening" : "Listening (Apple Speech)", systemImage: "mic.fill")
                    .foregroundColor(.green)
            } else {
                Label("Not listening", systemImage: "mic.slash")
                    .foregroundColor(.secondary)
            }
        }
        .font(.system(size: 11))
    }

    private var totalBadge: some View {
        Text("\(counter.totalCount)")
            .font(.system(size: 40, weight: .bold, design: .monospaced))
            .foregroundColor(badgeColor)
            .contentTransition(.numericText())
            .animation(.spring(response: 0.3), value: counter.totalCount)
    }

    private var badgeColor: Color {
        switch counter.totalCount {
        case 0: return .secondary
        case 1...10: return .primary
        case 11...25: return .orange
        default: return .red
        }
    }

    private var onboardingSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("A number in your menu bar.")
                .font(.system(size: 14, weight: .semibold))
            Text("Um listens on this Mac and counts filler words — um, uh, like, you know. Audio never leaves your computer.")
                .font(.system(size: 12))
                .foregroundColor(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            Button {
                finishOnboardingAndListen()
            } label: {
                Label(listening.isListening ? "Got it" : "Enable microphone & start", systemImage: "mic.circle.fill")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
        }
        .padding(16)
    }

    private var countsSection: some View {
        ScrollView {
            VStack(spacing: 0) {
                ForEach(counter.sortedCounts, id: \.word) { item in
                    HStack {
                        Text(item.word)
                            .font(.system(size: 13))
                        Spacer()
                        Text("\(item.count)")
                            .font(.system(size: 13, weight: .semibold, design: .monospaced))
                            .foregroundColor(.secondary)
                            .contentTransition(.numericText())
                            .animation(.spring(response: 0.25), value: item.count)
                        RoundedRectangle(cornerRadius: 2)
                            .fill(Color.accentColor.opacity(0.5))
                            .frame(width: CGFloat(item.count) / CGFloat(max(counter.totalCount, 1)) * 40, height: 6)
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 5)
                }
            }
            .padding(.vertical, 6)
        }
        .frame(maxHeight: 180)
    }

    private var statsRow: some View {
        HStack {
            Label(counter.formattedDuration, systemImage: "clock")
                .font(.system(size: 11))
                .foregroundColor(.secondary)
            Spacer()
            Text(String(format: "%.1f / min", counter.ratePerMinute))
                .font(.system(size: 11))
                .foregroundColor(.secondary)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 6)
    }

    private var emptyState: some View {
        VStack(spacing: 6) {
            Image(systemName: listening.isListening ? "ear" : "mic.badge.plus")
                .font(.system(size: 28))
                .foregroundColor(.secondary)
            Text(listening.isListening ? "Talk normally. Filler words show up here." : "Hit Start, then talk.")
                .font(.system(size: 12))
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
            if store.sessionCount > 0 {
                Button {
                    withAnimation(.easeInOut(duration: 0.15)) {
                        currentScreen = .history
                    }
                } label: {
                    Text("View \(store.sessionCount) past sessions →")
                        .font(.system(size: 11))
                        .foregroundColor(.accentColor)
                }
                .buttonStyle(.plain)
                .padding(.top, 4)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 24)
        .padding(.horizontal, 16)
    }

    private var controlsSection: some View {
        HStack(spacing: 8) {
            Button {
                if listening.isListening {
                    listening.stopListening()
                } else {
                    listening.startListening()
                }
            } label: {
                Label(
                    listening.isListening ? "Stop" : "Start",
                    systemImage: listening.isListening ? "stop.circle.fill" : "mic.circle.fill"
                )
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .tint(listening.isListening ? .red : .accentColor)
            .keyboardShortcut(.space, modifiers: [])

            Button {
                listening.stopListening()
                counter.resetCounts()
            } label: {
                Label("Reset", systemImage: "arrow.counterclockwise")
            }
            .buttonStyle(.bordered)
            .disabled(!listening.isListening && counter.totalCount == 0)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
    }

    private var bottomBar: some View {
        HStack {
            Button {
                withAnimation(.easeInOut(duration: 0.15)) {
                    currentScreen = .history
                }
            } label: {
                Image(systemName: "chart.bar")
                    .font(.system(size: 12))
            }
            .buttonStyle(.plain)
            .foregroundColor(.secondary)
            .help("Session History")

            Button {
                withAnimation(.easeInOut(duration: 0.15)) {
                    currentScreen = .settings
                }
            } label: {
                Image(systemName: "gear")
                    .font(.system(size: 12))
            }
            .buttonStyle(.plain)
            .foregroundColor(.secondary)
            .help("Settings")

            Spacer()

            Button("Quit Um") {
                NSApplication.shared.terminate(nil)
            }
            .buttonStyle(.plain)
            .foregroundColor(.secondary)
            .font(.system(size: 11))
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
    }

    private func finishOnboardingAndListen() {
        prefs.hasCompletedOnboarding = true
        if !listening.isListening {
            listening.startListening()
        }
    }
}

#Preview {
    MenuBarView()
        .frame(width: 280)
}
