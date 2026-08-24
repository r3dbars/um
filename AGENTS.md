# AGENTS.md

## Cursor Cloud specific instructions

**Um is a macOS-only menu bar GUI app.** The `Um` executable target imports Apple
frameworks (`AppKit`, `SwiftUI`, `Speech`, `AVFoundation`) and links `SwiftWhisper`.
Cloud Agent VMs are Linux, so the full app **cannot be built or run here**, and neither
can Xcode. Building/running the actual app and the full test suite happens on macOS +
Xcode 15 (see `README.md` / `SETUP.md`); CI runs on `macos-15` (`.github/workflows/ci.yml`).

What *does* work on Linux is the portable, dependency-free core:

- `UmCore` (`Um/Sources/UmCore/WordMatcher.swift`) — the word-boundary filler-word
  matcher. `CONTRIBUTING.md` calls it "the testable core"; put matching logic there.

### Toolchain

- Swift 6.3.3 is installed via `swiftly` (in `~/.local/share/swiftly`). It is added to
  `PATH` for new shells by an `env.sh` line in both `~/.profile` and `~/.bashrc`, so
  `swift` is available in interactive terminals without any extra step.

### Build / run the core

- Build the portable library: `swift build --target UmCore` (from repo root).
- `swift package resolve` fetches the `SwiftWhisper` dependency (also the update script).

### Running tests on Linux (important gotcha)

- **`swift test` and `swift build` (whole package) FAIL on Linux.** They compile the
  entire package graph, which includes the AppKit-based `Um` target → `no such module
  'AppKit'`. This is expected, not a broken environment.
- To run the real `UmCoreTests` XCTest suite on Linux, build it in isolation with a
  throwaway package that symlinks the actual sources (no repo changes):

  ```bash
  rm -rf /tmp/umcore-check
  mkdir -p /tmp/umcore-check/Sources /tmp/umcore-check/Tests
  ln -s /workspace/Um/Sources/UmCore   /tmp/umcore-check/Sources/UmCore
  ln -s /workspace/Tests/UmCoreTests   /tmp/umcore-check/Tests/UmCoreTests
  cat > /tmp/umcore-check/Package.swift <<'EOF'
  // swift-tools-version: 5.9
  import PackageDescription
  let package = Package(name: "UmCoreCheck", targets: [
      .target(name: "UmCore"),
      .testTarget(name: "UmCoreTests", dependencies: ["UmCore"]),
  ])
  EOF
  (cd /tmp/umcore-check && swift test)
  ```

### Notes

- The Whisper model (`scripts/download-model.sh`, ~75 MB, gitignored under `models/`)
  is only needed for macOS app builds; it is irrelevant to `UmCore` work on Linux.
- If you ever need `SwiftWhisper`'s C++ (whisper.cpp) to compile on Linux, the bundled
  clang needs `-Xcc --gcc-install-dir=/usr/lib/gcc/x86_64-linux-gnu/13`. This still won't
  let the `Um` app build (AppKit), so it is informational only.
