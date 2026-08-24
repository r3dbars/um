# Privacy

Um is built to hear you and tell you nothing else.

- **Microphone.** Used only to count filler words while you have listening turned on.
- **On-device.** The release build transcribes with a bundled whisper.cpp model inside the app. A fallback path uses Apple’s on-device speech recognizer. Audio is not sent to a server by Um.
- **No transcript store.** Partial text is scanned for the tracked word list and discarded. Um does not write recordings or transcripts to disk.
- **History.** If you finish a session longer than five seconds, Um saves counts, duration, and rate to `~/Library/Application Support/Um/sessions.json` on this Mac. You can delete sessions or clear all history in the app.
- **Notifications.** Optional, local, and only if you enable them.
- **No account. No analytics. No third-party trackers.**

The GitHub download fetches a disk image from GitHub Releases. That is hosting, not telemetry from the app.
