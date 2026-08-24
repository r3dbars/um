# Contributing

Um is a small Mac menu bar app. Keep changes in that shape: launch, listen, show a number.

## Setup

```bash
./scripts/download-model.sh
open Um.xcodeproj
```

Or `swift test` / `swift build` from the repo root (macOS).

## Guidelines

- Audio and transcripts stay on-device. Do not add network analytics or cloud speech APIs.
- The default counting path is Whisper. Apple Speech is only a fallback.
- `WordMatcher` is the testable core — put matching rules there, not in the views.
- The Whisper model is not committed. CI and `scripts/download-model.sh` fetch it.

## Release

See [docs/RELEASE.md](docs/RELEASE.md).
