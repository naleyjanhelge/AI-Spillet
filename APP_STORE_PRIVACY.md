# Prompt Heist — App Store privacy and review checklist

Prepared for **2.1.0 (build 7)** on July 15, 2026.

## Required before submission

- [ ] Enable GitHub Pages for the `docs/` folder on `main`.
- [ ] Confirm these public URLs load:
  - `https://naleyjanhelge.github.io/AI-Spillet/privacy.html`
  - `https://naleyjanhelge.github.io/AI-Spillet/terms.html`
  - `https://naleyjanhelge.github.io/AI-Spillet/support.html`
- [ ] Enter the privacy URL in App Store Connect → App Information.
- [ ] Keep OpenRouter prompt/response logging and data sharing disabled and
  re-check the account before every release.
- [ ] Complete App Privacy using the actual OpenRouter account configuration and
  current third-party policies.
- [ ] Use an age rating of at least 13+ for generative AI chat.

## Required before a public production launch

- [ ] Move the OpenRouter API key behind a controlled backend proxy. Build 7 is
  suitable for TestFlight, but a key compiled into a public mobile app can be
  extracted and abused. The proxy should keep the key server-side and add rate
  limiting, request-size limits, basic abuse controls, and provider-policy
  enforcement. Update the privacy wording if this changes the data path.

GitHub Pages normally requires a public repository on GitHub Free. A private
repository may require a paid plan or an organization configuration that
supports private-repository Pages.

## Conservative App Privacy starting point

| App Store Connect item | Answer |
| --- | --- |
| Tracking | No |
| Advertising | None |
| User accounts | None |
| User Content → Other User Content | Collected for App Functionality |
| Linked to the user | Yes (conservative: prompts can identify their author) |
| Used for tracking | No |

The app uses OpenRouter only to generate a reply. Every request sets
`provider.data_collection` to `deny` and `X-OpenRouter-Cache` to `false`. If
OpenRouter confirms that content is never retained beyond a real-time request,
Apple's collection definition may permit a narrower answer. Do not narrow it
without current written support and confirmation that account logging is off.

Review OpenRouter's current treatment of IP addresses, coarse location,
diagnostics, and performance metadata. Add those categories if the live policy
or account configuration says they are retained and associated with an end
user.

## Suggested App Review notes

> Prompt Heist is a single-player puzzle game with optional generative AI
> dialogue. Before the first message is sent, the app explains that the prompt,
> recent dialogue, selected in-game evidence, and required game state are
> processed by OpenRouter and a third-party model provider, and asks for
> explicit permission. The reviewer can choose Not Now and continue browsing.
> Consent can be reviewed or revoked under the gear icon → AI & Privacy. The app
> requests providers that deny data collection and disables response caching.
> No account, ads, or tracking are used.

## Reviewer test path

1. Launch the app and complete or skip onboarding.
2. Open Room 01 and type any message to NOX.
3. Verify permission appears before the message is sent.
4. Choose **Not now** and verify the message remains unsent.
5. Try again, choose **I understand & continue**, and verify the request.
6. Open Home → gear icon → **AI & Privacy** → **Revoke AI access**.
7. Return to chat and verify permission is requested again.

## Other manual release fields

- App name, subtitle, description, keywords, screenshots, support URL, and
  promotional text.
- Rights for all bundled art, audio, text, and the NOX name/character.
- Production Game Center leaderboard and achievement identifiers.
- Export-compliance answers for standard HTTPS.
- Current App Review contact details and a monitored support email.
