import SwiftUI

struct SettingsView: View {
    @ObservedObject private var prefs = Preferences.shared
    @State private var newWord: String = ""
    @State private var showingResetAlert = false

    var body: some View {
        VStack(spacing: 0) {
            settingsHeader
            Divider()
            wordListSection
            Divider()
            notificationSection
            Divider()
            generalSection
            Divider()
            resetSection
        }
        .frame(width: 280)
    }

    // MARK: - Header

    private var settingsHeader: some View {
        HStack {
            Button {
                NotificationCenter.default.post(name: .navigateBack, object: nil)
            } label: {
                Image(systemName: "chevron.left")
                    .font(.system(size: 12, weight: .semibold))
            }
            .buttonStyle(.plain)
            Text("Settings")
                .font(.system(size: 16, weight: .bold))
            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
    }

    // MARK: - Word list

    private var wordListSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Tracked Words")
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(.secondary)
                .textCase(.uppercase)

            ScrollView {
                VStack(spacing: 2) {
                    ForEach(prefs.trackedWords, id: \.self) { word in
                        HStack {
                            Text(word)
                                .font(.system(size: 13))
                            Spacer()
                            Button {
                                withAnimation(.easeInOut(duration: 0.2)) {
                                    prefs.trackedWords.removeAll { $0 == word }
                                }
                            } label: {
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundColor(.secondary)
                                    .font(.system(size: 12))
                            }
                            .buttonStyle(.plain)
                        }
                        .padding(.vertical, 3)
                    }
                }
            }
            .frame(maxHeight: 120)

            HStack(spacing: 6) {
                TextField("Add word or phrase…", text: $newWord)
                    .textFieldStyle(.roundedBorder)
                    .font(.system(size: 12))
                    .onSubmit { addWord() }
                Button {
                    addWord()
                } label: {
                    Image(systemName: "plus.circle.fill")
                        .font(.system(size: 16))
                }
                .buttonStyle(.plain)
                .disabled(newWord.trimmingCharacters(in: .whitespaces).isEmpty)
            }

            Button("Restore Defaults") {
                prefs.trackedWords = Preferences.defaultWords
            }
            .font(.system(size: 11))
            .buttonStyle(.plain)
            .foregroundColor(.accentColor)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
    }

    // MARK: - Notifications

    private var notificationSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Notifications")
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(.secondary)
                .textCase(.uppercase)

            Toggle(isOn: $prefs.notificationsEnabled) {
                Text("Alert at threshold")
                    .font(.system(size: 13))
            }
            .toggleStyle(.switch)
            .onChange(of: prefs.notificationsEnabled) { enabled in
                if enabled {
                    NotificationManager.shared.requestPermission()
                }
            }

            if prefs.notificationsEnabled {
                HStack {
                    Text("Every")
                        .font(.system(size: 12))
                    TextField("", value: $prefs.notificationThreshold, format: .number)
                        .textFieldStyle(.roundedBorder)
                        .frame(width: 50)
                        .font(.system(size: 12))
                    Text("filler words")
                        .font(.system(size: 12))
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
    }

    // MARK: - General

    private var generalSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("General")
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(.secondary)
                .textCase(.uppercase)

            Toggle(isOn: $prefs.launchAtLogin) {
                Text("Launch at login")
                    .font(.system(size: 13))
            }
            .toggleStyle(.switch)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
    }

    // MARK: - Reset

    private var resetSection: some View {
        Button("Clear All History") {
            showingResetAlert = true
        }
        .font(.system(size: 11))
        .foregroundColor(.red)
        .buttonStyle(.plain)
        .padding(.vertical, 8)
        .alert("Clear All History?", isPresented: $showingResetAlert) {
            Button("Clear", role: .destructive) {
                SessionStore.shared.clearAll()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This will permanently delete all saved session data.")
        }
    }

    // MARK: - Helpers

    private func addWord() {
        let trimmed = newWord.trimmingCharacters(in: .whitespaces).lowercased()
        guard !trimmed.isEmpty, !prefs.trackedWords.contains(trimmed) else {
            newWord = ""
            return
        }
        withAnimation(.easeInOut(duration: 0.2)) {
            prefs.trackedWords.append(trimmed)
        }
        newWord = ""
    }
}

extension Notification.Name {
    static let navigateBack = Notification.Name("um.navigateBack")
}
