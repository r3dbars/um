# Setting Up Um in Xcode

All source code is written and ready. This guide walks you through creating the Xcode project and wiring it up. Takes ~5 minutes.

## Requirements

- macOS 13.0+
- Xcode 15+

---

## Step 1 — Create the Xcode Project

1. Open Xcode → **File > New > Project**
2. Select **macOS → App**
3. Configure:
   - **Product Name:** `Um`
   - **Bundle Identifier:** `com.r3dbars.um`
   - **Interface:** `SwiftUI`
   - **Life Cycle:** `SwiftUI App`
   - **Language:** `Swift`
4. Save into this repo directory (so the `Um/` folder sits next to `README.md`)

---

## Step 2 — Replace Generated Files

Delete these Xcode-generated files from the project navigator:
- `ContentView.swift`
- `UmApp.swift` (the generated one — you'll add ours)

---

## Step 3 — Add Source Files

Drag all files from `Um/Sources/Um/` into the Xcode project:
- `UmApp.swift`
- `AppDelegate.swift`
- `SpeechManager.swift`
- `FillerWordCounter.swift`
- `MenuBarView.swift`

Make sure **"Copy items if needed"** is unchecked (they're already in the right place).

---

## Step 4 — Configure Info.plist

1. In Xcode, click your project in the navigator → select the **Um** target → **Info** tab
2. Add these keys:

| Key | Type | Value |
|-----|------|-------|
| `LSUIElement` | Boolean | YES |
| `NSMicrophoneUsageDescription` | String | Um listens to your microphone to count filler words in real time. Audio is processed entirely on your Mac and never sent anywhere. |
| `NSSpeechRecognitionUsageDescription` | String | Um uses on-device speech recognition to detect filler words. Nothing leaves your Mac. |

Alternatively: replace the generated `Info.plist` with `Um/Resources/Info.plist`.

---

## Step 5 — Configure Signing & Entitlements

1. **Signing & Capabilities** tab → set your Apple Developer team
2. Add a new **Entitlements** file or replace with `Um/Resources/Um.entitlements`
3. Ensure these entitlements are present:
   - `com.apple.security.device.microphone` = YES
   - `com.apple.security.device.audio-input` = YES

---

## Step 6 — Build & Run

Hit **⌘R**. Um will appear in your menu bar as `um: 0`. Click it to open the popover, hit Start, and start talking.

---

## Architecture Notes

```
UmApp.swift          — @main entry point, SwiftUI lifecycle
AppDelegate.swift    — NSStatusItem setup, popover, menu bar label updates
SpeechManager.swift  — SFSpeechRecognizer wrapper, on-device recognition,
                       auto-restart after 60s segment limit
FillerWordCounter.swift — word counting, session tracking, rate calculation
MenuBarView.swift    — SwiftUI popover UI
```

**Key design decisions:**
- `requiresOnDeviceRecognition = true` — audio never leaves the Mac
- Rolling transcript delta tracking — only processes new words, not the full cumulative transcript on every update
- Auto-restart — SFSpeechRecognizer has a ~60s limit per task; SpeechManager handles seamless restart
- Word-boundary regex — "like" won't match inside "likewise"

---

## Roadmap

- [ ] Word history persistence across sessions
- [ ] Per-session graph (improvement over time)
- [ ] Customisable word list via Settings
- [ ] Launch at login option
- [ ] Notification when you exceed a threshold ("You've said 'um' 20 times")
