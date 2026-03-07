# Um

**Um** is a lightweight, on-device Mac menu bar utility that counts your filler words in real time — *um, uh, like, you know, basically, literally* — so you can hear yourself the way others do.

No cloud. No subscription. No recordings stored. Just a number in your menu bar that goes up every time you say *um*.

---

## Why

Most people have no idea how many filler words they use. The moment you see the count tick up live during a Zoom call, it changes your behavior. That's the whole product.

Every alternative (Yoodli, etc.) is cloud-based and costs $25/mo. Um is free, open source, and never sends your audio anywhere.

---

## Features

- 🎙 **Real-time detection** — counts as you speak, no delay
- 📊 **Per-session summary** — total counts per word after each call
- 📈 **History** — track improvement over time
- ⚙️ **Custom word list** — add your own verbal tics
- 🔒 **100% on-device** — audio never leaves your Mac

---

## How it works

Um uses on-device speech recognition (Whisper) running locally on Apple Silicon. It listens for a small vocabulary of filler words — no full transcription, no audio storage, just pattern matching. Tiny CPU footprint.

---

## Status

🚧 Early development — built with SwiftUI for macOS

---

## Tech Stack

- Swift / SwiftUI
- On-device Whisper (Apple Silicon)
- macOS 14+

---

## License

MIT — free forever, open source forever.

---

*Part of the [r3dbars](https://github.com/r3dbars) suite of on-device voice utilities for Mac.*
