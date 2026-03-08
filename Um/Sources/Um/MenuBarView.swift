import SwiftUI

enum AppScreen {
    case main
    case settings
    case history
}

struct MenuBarView: View {
    @StateObject private var counter = FillerWordCounter.shared
    @StateObject private var speech = SpeechManager.shared
    @StateObject private var store = SessionStore.shared
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
            if counter.totalCount > 0 {
                countsSection
                Divider()
                statsRow
                Divider()
            } else if !speech.isListening {
                emptyState
            }
            controlsSection
            Divider()
            bottomBar
        }
        .frame(width: 280)
    }

    // MARK: - Header

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
            if let error = speech.errorMessage {
                Label(error, systemImage: "exclamationmark.triangle.fill")
                    .foregroundColor(.red)
            } else if speech.isListening {
                Label("Listening", systemImage: "mic.fill")
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

    // MARK: - Counts breakdown

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
                        // Visual proportion bar
                        RoundedRectangle(cornerRadius: 2)
                            .fill(Color.accentColor.opacity(0.5))
                            .frame(width: CGFloat(item.count) / CGFloat(max(counter.totalCount, 1)) * 40,
                                   height: 6)
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 5)
                }
            }
            .padding(.vertical, 6)
        }
        .frame(maxHeight: 180)
    }

    // MARK: - Stats row

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

    // MARK: - Empty state

    private var emptyState: some View {
        VStack(spacing: 6) {
            Image(systemName: "mic.badge.plus")
                .font(.system(size: 28))
                .foregroundColor(.secondary)
            Text("Hit Start, then talk.")
                .font(.system(size: 12))
                .foregroundColor(.secondary)
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
    }

    // MARK: - Controls

    private var controlsSection: some View {
        HStack(spacing: 8) {
            Button {
                if speech.isListening {
                    speech.stopListening()
                } else {
                    speech.startListening()
                }
            } label: {
                Label(
                    speech.isListening ? "Stop" : "Start",
                    systemImage: speech.isListening ? "stop.circle.fill" : "mic.circle.fill"
                )
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .tint(speech.isListening ? .red : .accentColor)
            .keyboardShortcut(.space, modifiers: [])

            Button {
                speech.stopListening()
                counter.resetCounts()
            } label: {
                Label("Reset", systemImage: "arrow.counterclockwise")
            }
            .buttonStyle(.bordered)
            .disabled(!speech.isListening && counter.totalCount == 0)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
    }

    // MARK: - Bottom bar (History, Settings, Quit)

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
}

#Preview {
    MenuBarView()
        .frame(width: 280)
}
