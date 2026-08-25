# Changelog

## Unreleased

- Extract transcript cleanup, cumulative-transcript deltas, and session file I/O into `UmCore` with unit tests
- Document the audio path in `docs/ARCHITECTURE.md`
- GitHub issue and branch cleanup so `main` is the only open branch
- Package as a universal `arm64` + `x86_64` binary; add `scripts/notarize.sh` for Developer ID builds

## 1.0.0

First public release.

- Menu bar filler-word counter that starts listening on launch
- First-run explanation and microphone prompt
- On-device Whisper (`tiny.en`) so *um* / *uh* stay in the transcript
- Apple Speech fallback when the model file is missing
- Custom word list, session history, threshold notifications, launch at login
- Installable `Um.app` + `Um-1.0.0.dmg` from GitHub Actions
- `Um.xcodeproj` so the repo opens in one click
- Unit tests for word-boundary matching
