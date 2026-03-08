# Um

**Um** is a lightweight, on-device Mac menu bar utility that counts your filler words in real time — *um, uh, like, you know, basically, literally* — so you can hear yourself the way others do.

No cloud. No subscription. No recordings stored. Just a number in your menu bar that goes up every time you say *um*.

---

## Why

Most people have no idea how many filler words they use. The moment you see the count tick up live during a Zoom call, it changes your behavior. That's the whole product.

Every alternative (Yoodli, etc.) is cloud-based and costs $25/mo. Um is free, open source, and never sends your audio anywhere.

---

## Features

- **Real-time detection** — counts as you speak, no delay
- **Per-session summary** — total counts per word with visual breakdown
- **Session history** — track improvement over time with rate trends
- **Custom word list** — add your own verbal tics via the Settings UI
- **Threshold notifications** — get alerted when you hit a filler word count
- **Launch at login** — always running, always counting
- **100% on-device** — audio never leaves your Mac (uses Apple's on-device speech recognition)
- **Zero dependencies** — purely Apple frameworks, no external packages

---

## How it works

Um uses Apple's on-device `SFSpeechRecognizer` running locally on your Mac. It listens for a configurable vocabulary of filler words using word-boundary regex matching — no full transcription stored, no audio saved, just pattern matching on streaming partial results. The audio engine stays running across the 60-second recognition segment restarts so no words are missed.

---

## Architecture

```
UmApp.swift              — @main entry point, SwiftUI lifecycle
AppDelegate.swift        — NSStatusItem (menu bar icon + count), popover management
SpeechManager.swift      — SFSpeechRecognizer wrapper, on-device recognition, seamless restart
FillerWordCounter.swift  — Word counting, session tracking, rate calculation
MenuBarView.swift        — Main SwiftUI popover UI with navigation
SettingsView.swift       — Custom word list editor, notifications, launch at login
HistoryView.swift        — Past session list with trend stats
SessionStore.swift       — JSON persistence to ~/Library/Application Support/Um/
Preferences.swift        — UserDefaults-backed settings
NotificationManager.swift — Threshold alerts via UserNotifications
LaunchAtLoginHelper.swift — SMAppService wrapper for macOS 13+
```

---

## Requirements

- macOS 13.0+
- Xcode 15+ (for building)

---

## Quick Start

See [SETUP.md](SETUP.md) for step-by-step Xcode project setup.

---

## Tech Stack

- Swift / SwiftUI
- Apple Speech framework (on-device SFSpeechRecognizer)
- AVFoundation (audio capture)
- UserNotifications (threshold alerts)
- ServiceManagement (launch at login)
- No external dependencies

---

## License

MIT — free forever, open source forever.

---

*Part of the [r3dbars](https://github.com/r3dbars) suite of on-device voice utilities for Mac.*
