# Releasing Um

The repo is public. Ship from `main` after a pull request — the branch is protected and **Build** must pass.

## DMG

GitHub Actions on `macos-15` downloads the Whisper model, builds a universal `arm64` + `x86_64` binary, and attaches `Um-x.y.z.dmg` to a GitHub Release. Local contributor builds are ad-hoc. Public `v*` releases should be Developer ID signed, hardened-runtime, and notarized with `scripts/notarize.sh` when the signing secrets are available.

```bash
git tag v1.0.1
git push origin v1.0.1
```

Or run the **Release** workflow from the Actions tab.

Locally:

```bash
./scripts/download-model.sh
./scripts/package-app.sh
./scripts/create-dmg.sh
```

## First-run note

Release builds set `ENABLE_HARDENED_RUNTIME = YES` in the Xcode project. That is required for notarization; it is not notarization by itself.

GitHub Releases meant for download should be Developer ID signed and notarized (`scripts/notarize.sh`). Local `swift build` / `./run.sh` binaries and current CI artifacts are ad-hoc signed. README documents right-click → Open for those builds.

To ship a Gatekeeper-clean download you need a **Developer ID Application** certificate (Apple Development is not enough) plus:

```bash
xcrun notarytool store-credentials um-notarize
./scripts/package-app.sh      # signs with Developer ID when it is in the keychain
./scripts/notarize.sh         # submits to Apple and staples
./scripts/create-dmg.sh
```

`package-app.sh` now emits a universal binary (`arm64` + `x86_64`).

## Version bumps

Update `CFBundleShortVersionString` in `Um/Resources/Info.plist`, `MARKETING_VERSION` in `Um.xcodeproj/project.pbxproj`, and [CHANGELOG.md](../CHANGELOG.md). The release workflow reads the version from the `v*` tag.
