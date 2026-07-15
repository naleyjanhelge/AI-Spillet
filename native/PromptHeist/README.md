# Prompt Heist — native iOS reboot

This directory contains the new SwiftUI version of Prompt Heist. The existing
Flutter app remains untouched while the native version is validated.

## Product loop

- Pick a short level.
- Persuade NOX to reveal one harmless fictional secret.
- Win in as few prompts as possible.
- Choose **Limit** for a finite prompt budget or **Chill** for unlimited prompts.
- Earn one to three stars and immediately continue to the next level.

There is no room exploration, inventory, cloud account, or server AI in this
version. Levels are data entries in `PromptHeist/Models/HeistLevel.swift`, so
new packs can be added without expanding the game engine.

## Local AI

NOX uses `SystemLanguageModel.default` through Apple's Foundation Models
framework. `NoxEngine` uses guided generation to return a typed reply and a
verified win signal. No backend, API key, or network AI fallback exists.

The app checks all Foundation Models availability states:

- Ready
- Apple Intelligence disabled
- Device not eligible
- Model not downloaded/ready
- Unknown system unavailability

The first-run screen explains that Apple Intelligence is required and that
prompts remain on-device.

## Game Center

Game Center authentication starts at launch but remains optional. Completed
packs and the full campaign submit the sum of each level's local best prompt
count to lowest-score-wins leaderboards. The app also reports first-win and
under-par achievements and can open friend-only pack comparisons.

Create these leaderboards in App Store Connect before testing:

- `game.promptheist.mobile.leaderboard.chapter1`
- `game.promptheist.mobile.leaderboard.chapter2`
- `game.promptheist.mobile.leaderboard.chapter3`
- `game.promptheist.mobile.leaderboard.pack4`
- `game.promptheist.mobile.leaderboard.campaign`

Create these achievements:

- `game.promptheist.mobile.achievement.first_breach`
- `game.promptheist.mobile.achievement.under_par_run`

## Device requirements

- iOS 26.0 or later
- iPhone only
- `UIRequiredDeviceCapabilities` includes `iphone-performance-gaming-tier`
  and `arm64`

The gaming-tier capability limits App Store availability to hardware with at
least iPhone 15 Pro-equivalent performance. Apple doesn't currently publish a
dedicated Apple Intelligence required-capability key, so the runtime
`SystemLanguageModel.availability` gate remains authoritative.

These capability requirements need to be present in the first public App Store
release. Apple doesn't allow an existing app update to add a stricter device
requirement later.

## Build

```sh
xcodebuild \
  -project native/PromptHeist/PromptHeist.xcodeproj \
  -scheme PromptHeist \
  -configuration Debug \
  -sdk iphonesimulator \
  CODE_SIGNING_ALLOWED=NO \
  build
```

Open `PromptHeist.xcodeproj` in Xcode and select an Apple
Intelligence-capable physical iPhone to test actual generation. Foundation
Models availability and output quality must be tested on-device before
TestFlight submission.

## Release identity

- Bundle ID: `game.promptheist.mobile`
- Marketing version: `3.0.0`
- Build: `8`
- Development team: `AV4XNY669E`

The native app intentionally retains the existing bundle ID so it can use the
same App Store Connect record after the migration is approved.
