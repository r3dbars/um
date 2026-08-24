# Releasing Um

## 1. Make the GitHub repo public

The code can be public; the current GitHub repo starts private. In the GitHub UI:

1. Open https://github.com/r3dbars/um/settings
2. **General → Danger Zone → Change repository visibility → Public**
3. Add topics if you want: `macos`, `menubar`, `swift`, `whisper`, `privacy`

Set the repository description to:

> On-device filler word counter for Mac. Real-time. Private. Free.

## 2. Ship a DMG

GitHub Actions builds on `macos-15`, bundles the Whisper model, ad-hoc signs `Um.app`, and attaches `Um-x.y.z.dmg` to a GitHub Release.

From the default branch after merge:

```bash
git tag v1.0.0
git push origin v1.0.0
```

Or run the **Release** workflow from the Actions tab (`workflow_dispatch`).

## 3. First-run note for users

The CI app is not Developer ID signed. README already documents right-click → Open. A paid Apple Developer account plus notarization would remove that step.

## 4. Version bumps

Update `CFBundleShortVersionString` in `Um/Resources/Info.plist`, `MARKETING_VERSION` in `Um.xcodeproj/project.pbxproj`, and [CHANGELOG.md](../CHANGELOG.md). The release workflow reads the version from the `v*` tag.
