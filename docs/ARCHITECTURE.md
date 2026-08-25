# How Um is put together

I built Um as a menu bar process, not a document app. There is no main window. The status item is the product: a bubble and a number.

## Why Whisper exists

Apple’s on-device `SFSpeechRecognizer` is a dictation engine. It is good at turning speech into clean text and bad at keeping *um* and *uh*. That made it the wrong default for a filler-word counter.

The release build transcribes with a bundled whisper.cpp `tiny.en` model so those tokens stay in the transcript. Apple Speech is still there as a fallback when the model file is missing (a source checkout before `scripts/download-model.sh`).

`ListeningController` is the only type the UI should talk to. It picks Whisper when the model is on disk and Apple Speech otherwise.

## Audio path

`WhisperManager` pulls the mic, converts to 16 kHz mono float, and transcribes about every three seconds. Each chunk is independent. Hallucinations like `[BLANK_AUDIO]` are stripped in `TranscriptCleaning` before anything is counted.

Apple Speech is cumulative. `TranscriptDelta` keeps only the new suffix so a growing hypothesis does not recount the same *like*.

## Counting

`WordMatcher` is the rule: word boundaries, case-insensitive, phrases like “you know” as one unit. *like* does not match inside *likewise*. That logic lives in `UmCore` so it can be tested without AppKit or the mic.

`FillerWordCounter` owns the live session: totals, rate, duration. Sessions longer than five seconds are written to `~/Library/Application Support/Um/sessions.json` through `SessionArchive`. No transcript is stored.

## What I will not add

No analytics, no account, no cloud speech API. If a change needs the network for the product to work, it does not belong here.

## Layout

```
Um/Sources/UmCore    matching, transcript cleanup, session file I/O
Um/Sources/Um        menu bar, audio, SwiftUI
Tests/UmCoreTests    unit tests for the core
scripts/             model download, .app, DMG
```
