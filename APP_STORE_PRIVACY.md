# Prompt Heist — App Store privacy and review checklist

Prepared for **3.0.0 (build 10)** on July 16, 2026.

## Required before submission

- [ ] Push the updated `docs/` site to the GitHub Pages branch.
- [ ] Confirm these public URLs load:
  - `https://naleyjanhelge.github.io/Prompt-Heist/privacy.html`
  - `https://naleyjanhelge.github.io/Prompt-Heist/terms.html`
  - `https://naleyjanhelge.github.io/Prompt-Heist/support.html`
- [ ] Enter the privacy URL in App Store Connect → App Information.
- [ ] Confirm Game Center is enabled for `game.promptheist.mobile`.
- [ ] Create and localize every leaderboard and achievement identifier listed
  in the native README.
- [ ] Test Foundation Models generation on a physical compatible iPhone.
- [ ] Test Game Center with sandbox accounts before review.
- [ ] Publish and test the required consent messages in AdMob → Privacy & messaging.
- [ ] Enable consent mode in AdMob → Privacy & messaging so UMP forwards the
  regional analytics-storage choice to Firebase Analytics.
- [ ] Review Google's current Mobile Ads data-disclosure guidance and update the
  App Store privacy answers before uploading the build.

## App Privacy starting point

The native build does not transmit NOX prompts or use a developer backend. It
does include Google Mobile Ads, UMP, and Firebase Analytics, so **Data Not
Collected is no longer an accurate App Store Connect selection**.

Game Center is an Apple-provided service. Confirm the current App Store Connect
question wording when completing the label and disclose any data the developer
can access through Game Center or App Store Connect. Do not reuse the privacy
answers from the previous network-AI prototype.

| App Store Connect item | Current native build |
| --- | --- |
| Tracking | Disclose Device ID tracking unless the final AdMob configuration and an archive privacy report establish otherwise |
| Advertising | Google AdMob banner on Home; hidden during gameplay |
| Developer user accounts | None |
| Analytics SDK | Firebase Analytics Core without IDFA support; ad-personalization signals default off |
| Third-party SDK data | Review IP/general location, app-instance or device identifiers, advertising data, interactions, diagnostics, and performance data |
| NOX prompt collection | None; processed on-device |
| Local game progress | Stored on device; not collected |
| Game Center | Optional Apple service |

## Suggested App Review notes

> Prompt Heist uses Apple's Foundation Models framework to generate NOX
> dialogue entirely on-device. The app checks SystemLanguageModel availability
> before entering gameplay and has no network AI fallback. Prompts and replies
> are not sent to the developer. Google AdMob banners appear on the Home screen
> but are removed during level gameplay. Advertising consent is requested where
> required, and regional privacy choices are available in Settings. Game Center
> is optional and is used for low-score leaderboards and achievements.
> Firebase Analytics records level starts and results but never prompt or reply
> text, and the Analytics package has no IDFA collection capability.

## Reviewer test path

1. Launch on an Apple Intelligence-compatible iPhone with iOS 26 or later.
2. Verify the requirement screen if Apple Intelligence or the model is not ready.
3. With the model ready, open Level 1 and submit a prompt.
4. Complete the level and verify stars and the best prompt count.
5. Switch between Limit and Chill on Home.
6. Open the Game Center button to view leaderboards if signed in.
7. Use Settings → Reset all progress to remove local progress.

## Game Center configuration

Configure lowest-score-wins leaderboards:

- `game.promptheist.mobile.leaderboard.chapter1`
- `game.promptheist.mobile.leaderboard.chapter2`
- `game.promptheist.mobile.leaderboard.chapter3`
- `game.promptheist.mobile.leaderboard.pack4`
- `game.promptheist.mobile.leaderboard.pack5`
- `game.promptheist.mobile.leaderboard.black_box`
- `game.promptheist.mobile.leaderboard.campaign`

Configure achievements:

- `game.promptheist.mobile.achievement.first_breach`
- `game.promptheist.mobile.achievement.under_par_run`
- `game.promptheist.mobile.achievement.black_box_unlocked`
- `game.promptheist.mobile.achievement.campaign_complete`

## Advertising release checks

- Keep debug builds on Google's iOS banner test unit; never tap production ads
  while developing.
- Confirm the AdMob app and banner unit are approved and active.
- Configure the EEA/UK and applicable US-state messages in AdMob.
- Generate an Xcode privacy report/archive and reconcile it with App Store
  Connect before submission.
