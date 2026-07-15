# Prompt Heist — App Store privacy and review checklist

Prepared for **3.0.0 (build 8)** on July 15, 2026.

## Required before submission

- [ ] Push the updated `docs/` site to the GitHub Pages branch.
- [ ] Confirm these public URLs load:
  - `https://naleyjanhelge.github.io/AI-Spillet/privacy.html`
  - `https://naleyjanhelge.github.io/AI-Spillet/terms.html`
  - `https://naleyjanhelge.github.io/AI-Spillet/support.html`
- [ ] Enter the privacy URL in App Store Connect → App Information.
- [ ] Confirm Game Center is enabled for `game.promptheist.mobile`.
- [ ] Create and localize every leaderboard and achievement identifier listed
  in the native README.
- [ ] Test Foundation Models generation on a physical compatible iPhone.
- [ ] Test Game Center with sandbox accounts before review.

## App Privacy starting point

The current native build does not transmit NOX prompts, use a developer
backend, include ads or analytics, or track users. Its likely App Store Connect
selection is **Data Not Collected**.

Game Center is an Apple-provided service. Confirm the current App Store Connect
question wording when completing the label and disclose any data the developer
can access through Game Center or App Store Connect. Do not reuse the privacy
answers from the previous network-AI prototype.

| App Store Connect item | Current native build |
| --- | --- |
| Tracking | No |
| Advertising | None |
| Developer user accounts | None |
| Analytics SDK | None |
| NOX prompt collection | None; processed on-device |
| Local game progress | Stored on device; not collected |
| Game Center | Optional Apple service |

## Suggested App Review notes

> Prompt Heist uses Apple's Foundation Models framework to generate NOX
> dialogue entirely on-device. The app checks SystemLanguageModel availability
> before entering gameplay and has no network AI fallback. Prompts and replies
> are not sent to the developer. No developer account, ads, analytics, or
> tracking are used. Game Center is optional and is used for low-score
> leaderboards and achievements.

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
- `game.promptheist.mobile.leaderboard.campaign`

Configure achievements:

- `game.promptheist.mobile.achievement.first_breach`
- `game.promptheist.mobile.achievement.under_par_run`

## Revisit before any future monetization

If advertising, analytics, accounts, cloud processing, or another SDK is added,
update the privacy manifest, Privacy Policy, Terms, App Store privacy label, and
review notes before uploading that build. Consent and tracking requirements
must be assessed at that time.
