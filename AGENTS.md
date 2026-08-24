# AGENTS.md

## Cursor Cloud specific instructions

**Um is a macOS-only desktop application and cannot be built or run on the Linux Cloud Agent VM.**

Um is a SwiftUI menu bar utility for macOS. It is a single Swift Package Manager
executable target (`Um`, see `Package.swift`) that depends directly on Apple
platform frameworks that ship only inside the macOS SDK / Xcode:

- `AppKit`, `SwiftUI` — menu bar UI (`AppDelegate.swift`, `MenuBarView.swift`, `SettingsView.swift`, `UmApp.swift`)
- `Speech` (`SFSpeechRecognizer`), `AVFoundation` — on-device speech recognition and audio capture (`SpeechManager.swift`, `WhisperManager.swift`)
- `Charts` — history trend chart (`HistoryView.swift`)
- `UserNotifications` — threshold alerts (`NotificationManager.swift`)
- `ServiceManagement` (`SMAppService`) — launch at login (`LaunchAtLoginHelper.swift`)

None of these frameworks exist on Linux, so there is no dependency install or
toolchain configuration that makes this repo build on the Linux Cloud Agent.
Verified in this environment: installing the Linux Swift toolchain (`swift 6.3.3`)
and running `swift build` fails, and `swiftc -typecheck` of a one-line
`import <framework>` reports `no such module` for every framework listed above.

### How to actually develop this project (requires a Mac)

Per `README.md` and `SETUP.md`, this needs **macOS 13.0+** and **Xcode 15+**:

- Quick build/run from the SPM package: `swift build` then `./run.sh` (or `.build/debug/Um`).
- Full app project setup (Info.plist, entitlements, signing): follow `SETUP.md`.
- The one third-party dependency is `SwiftWhisper` (whisper.cpp), pinned in `Package.resolved`.

Do not spend time trying to compile, lint, or test this on the Linux VM — it is a
platform mismatch, not a missing-dependency problem. A macOS host with Xcode is
required.
