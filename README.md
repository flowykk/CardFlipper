# CardFlipper

CardFlipper is a local-first iPhone flashcard app for building and studying a Russian–English vocabulary library. Vocabulary and tags are stored only on the device with SwiftData. The app has no accounts, cloud sync, analytics, or persisted study sessions and results.

The optional Free Dictionary API suggestion can fill an English IPA value and the first recognized part of speech. English lookup terms are sent to `dictionaryapi.dev` after a short typing delay; no vocabulary is persisted outside the device. The service requires a network connection, uses no API key, and never prevents manual editing when it is offline or has no match. English pronunciation uses the system `en-GB` voice and does not persist audio.

## Requirements

- Xcode 26.0.1
- Tuist 4.40.0
- iOS 18 or later

## Generate
`tuist generate`

## Test
`tuist test CardFlipper --no-selective-testing`

## Build
`tuist build CardFlipper`
