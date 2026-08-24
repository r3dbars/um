# Building Um

You do not need to create an Xcode project by hand. This repo already has one.

## End users

Download the DMG from [Releases](https://github.com/r3dbars/um/releases) and drag Um into Applications. See the [README](README.md#install).

## Developers (Xcode)

1. macOS 13+ and Xcode 15+
2. `./scripts/download-model.sh` — fetches `models/ggml-tiny.en.bin` (~75 MB, gitignored)
3. `open Um.xcodeproj`
4. Select the **Um** scheme and press **⌘R**

The app appears only in the menu bar (no Dock icon). Grant microphone access when asked.

The Xcode target copies `models/ggml-tiny.en.bin` into the app bundle when that file exists. Without it, Um falls back to Apple Speech and may miss *um* / *uh*.

## Developers (SwiftPM)

```bash
./scripts/download-model.sh
swift build
swift test
.build/debug/Um
```

SwiftPM is the same sources. The packaged `.app` / DMG path is `scripts/package-app.sh` + `scripts/create-dmg.sh` (macOS only).

## Signing

Local and CI builds are **ad-hoc signed**. That is enough to run on your own Mac after right-click → Open. A Developer ID + notarization would be required for a Gatekeeper-clean download.

## Architecture

```
UmApp.swift                 @main, menu-bar-only SwiftUI app
AppDelegate.swift           NSStatusItem, popover, right-click menu
ListeningController.swift   Whisper first, Apple Speech fallback
WhisperManager.swift        Local whisper.cpp transcription
SpeechManager.swift         SFSpeechRecognizer fallback
WordMatcher.swift           Word-boundary counting (UmCore)
FillerWordCounter.swift     Session totals and rate
MenuBarView.swift           Popover: count, onboarding, controls
SettingsView.swift          Word list, alerts, launch at login
HistoryView.swift           Session list and trend
SessionStore.swift          ~/Library/Application Support/Um/sessions.json
Preferences.swift           UserDefaults
```
