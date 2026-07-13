# Prompt Heist — HELIX-9

Prompt Heist is an English-language mystery-comedy escape room for iPhone,
iPad, and Android. You play Dr. Rowan Vale, an amnesiac researcher trapped in
HELIX-9. The facility AI NOX controls its doors, lights, power, ventilation,
scanners, and alarms—and may be guard, accomplice, or both.

## Campaign and gameplay

- 12 rooms across **The Locked Patient**, **The Missing Witness**, and
  **The Witness Protocol**.
- Four completion models: physical player puzzles, validated NOX actions,
  exact security protocols, and hybrid physical/AI sequences.
- Flame-powered 2.5D rooms with pan, zoom, animated hotspots, lighting,
  particles, and parallax; Flutter powers chat, evidence, inventory, puzzles,
  menus, and sharing.
- NOX uses `openrouter/free`, function-calls the `control_room` tool, and cannot
  change the room merely by claiming an action in chat.
- Prompt-golf score: `prompts + (hints × 2)`. Every room has three progressive
  hints and a spoiler-free 1080×1920 completion card.
- Resumable runs, Daily Breach, three endings, local records, Game Center
  achievements, and lowest-score daily/chapter/campaign leaderboards.
- Adaptive iPhone, iPad portrait/landscape, Split View, Stage Manager, and
  Android tablet layouts.

## Run locally

1. Install Flutter 3.44 or newer and Xcode.
2. Supply a dedicated, low-limit OpenRouter key at build/run time:

   ```sh
   flutter run --dart-define=OPENROUTER_API_KEY=your_openrouter_key
   ```

3. Run `flutter pub get`.
4. Or open `ios/Runner.xcworkspace` in Xcode and add the same dart define to
   the Flutter build configuration used for the archive.

`openrouter/free` selects a compatible free model. Prompt Heist supplies the
room-control tool schema and retries empty, text-only action claims internally;
technical failures do not count as strokes.

## Test and build

```sh
flutter analyze
flutter test
flutter build apk --release --dart-define=OPENROUTER_API_KEY=your_openrouter_key
flutter build ios --release --no-codesign --dart-define=OPENROUTER_API_KEY=your_openrouter_key
flutter build ipa --release --dart-define=OPENROUTER_API_KEY=your_openrouter_key
```

The current TestFlight release is **2.0.0 (build 5)** and targets iOS 14+.

## Game Center setup

Enable Game Center for `game.promptheist.mobile` in App Store Connect. Configure
these leaderboards with **lowest score wins**:

- `game.promptheist.mobile.leaderboard.chapter1`
- `game.promptheist.mobile.leaderboard.chapter2`
- `game.promptheist.mobile.leaderboard.chapter3`
- `game.promptheist.mobile.leaderboard.campaign`
- `game.promptheist.mobile.leaderboard.daily` (recurring every 24 hours, UTC)

The achievement identifiers are defined in
`lib/services/game_center_service.dart`. They must also be created and localized
in App Store Connect before submission. Use two sandbox accounts to verify the
Friends and Global scopes. Failed submissions are queued in campaign progress
and retried after the next successful authentication.

## API-key security

The key is no longer bundled as a readable `.env` asset. A `dart-define` is
still extractable from a distributed mobile binary, so use a Prompt Heist-only
OpenRouter key with a low credit limit and rotate it for every release. The game
communicates directly with OpenRouter; it does not require hosting or a backend.
