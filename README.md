# Prompt Heist

Prompt Heist is a native iPhone puzzle game where you trick the stubborn AI
character NOX into revealing a harmless fictional secret in as few prompts as
possible. It is designed for short, replayable sessions rather than a large
story campaign.

## Native iOS game

The current app lives in [`native/PromptHeist`](native/PromptHeist) and is built
with SwiftUI, Foundation Models, Liquid Glass, and GameKit.

- 20 data-driven levels across four packs
- **Limit** mode with a finite prompt budget
- **Chill** mode with unlimited attempts
- One-to-three stars and local best prompt counts
- On-device NOX dialogue with no backend or network AI fallback
- Game Center lowest-score leaderboards, achievements, and friend comparisons
- iPhone only, iOS 26+, Apple Intelligence-compatible hardware required

Open [`native/PromptHeist/PromptHeist.xcodeproj`](native/PromptHeist/PromptHeist.xcodeproj)
in Xcode and test Foundation Models generation on a compatible physical iPhone.

```sh
xcodebuild \
  -project native/PromptHeist/PromptHeist.xcodeproj \
  -scheme PromptHeist \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
  test
```

The app keeps the existing bundle ID `game.promptheist.mobile`. Current native
release metadata is **3.0.0 (build 8)**.

## Game Center setup

Enable Game Center for the bundle ID and configure these leaderboards with
**lowest score wins**:

- `game.promptheist.mobile.leaderboard.chapter1`
- `game.promptheist.mobile.leaderboard.chapter2`
- `game.promptheist.mobile.leaderboard.chapter3`
- `game.promptheist.mobile.leaderboard.pack4`
- `game.promptheist.mobile.leaderboard.campaign`

Achievements:

- `game.promptheist.mobile.achievement.first_breach`
- `game.promptheist.mobile.achievement.under_par_run`

## Website and App Store material

The GitHub Pages site lives in [`docs`](docs) and is published at
<https://naleyjanhelge.github.io/AI-Spillet/>. Copy-ready store text and release
privacy notes are in [`APP_STORE_METADATA.md`](APP_STORE_METADATA.md) and
[`APP_STORE_PRIVACY.md`](APP_STORE_PRIVACY.md).

## Legacy prototype

The repository root also contains the earlier Flutter prototype. It is retained
for reference while the native SwiftUI version is validated, but it is not the
current release direction.
