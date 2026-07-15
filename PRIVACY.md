# Prompt Heist Privacy Policy

**Effective date:** July 15, 2026  
**Contact:** naleyjanhelge@gmail.com

Prompt Heist is a game where you talk to the fictional AI guardian NOX. This
policy explains what happens to data when you use the AI chat.

## The short version

- Prompt Heist has no user accounts, advertising, or cross-app tracking.
- Campaign progress and resumable dialogue are stored locally on your device.
- When you message NOX, data needed to create the reply leaves your device and
  is processed by OpenRouter and a third-party AI model provider.
- Do not enter personal, sensitive, confidential, health, financial, password,
  or workplace information in the NOX chat.

## Data processed for NOX replies

For each NOX request, Prompt Heist sends:

- the message you submit;
- up to 18 recent messages from the current NOX conversation;
- in-game evidence you attach;
- the room objective, visible clues, inventory, device state, valid game routes,
  and NOX relationship state needed to produce and validate the reply; and
- technical request metadata needed to deliver the request.

This information is sent directly from the app to OpenRouter. OpenRouter routes
the request to an available third-party model provider. The purpose is solely to
provide the requested NOX dialogue and in-game response.

Prompt Heist requests providers that declare they do not collect prompt data by
using OpenRouter's `data_collection: deny` routing control. It also explicitly
disables OpenRouter response caching. Provider availability, policies, and
technical practices can change, so NOX chat should still be treated as
non-private. OpenRouter states that it does not train its models on inputs or
outputs, but third-party model providers have their own policies.

Read [OpenRouter's privacy policy](https://openrouter.ai/privacy/) and
[data policy documentation](https://openrouter.ai/docs/guides/privacy/data-collection)
for more information.

## Local data

Prompt Heist stores campaign progress, scores, settings, consent status, and
resumable room dialogue locally on your device. This data is not synchronized
to a Prompt Heist account or server. Game Center features may separately be
processed by Apple under your Apple account and Apple's policies.

Using **Reset campaign** removes local campaign progress, evidence, scores, and
saved room dialogue. Device backups or operating-system services may retain
copies according to their own settings and policies.

## OpenRouter and model-provider data

OpenRouter may retain request metadata such as token counts and latency.
OpenRouter content logging depends on the developer account settings and the
service's current policies. Prompt Heist's per-request routing control excludes
model providers that declare data collection for training or other purposes,
but processing still occurs to generate the requested reply.

Retention, security, international transfer, access, correction, and deletion
requests for data held by OpenRouter or a model provider are governed by those
services' policies. OpenRouter operates in the United States and may process
data in other countries where it or its providers operate.

## Your choices

Before the first NOX request, Prompt Heist asks for explicit permission to share
the data described above. Choosing **Not now** prevents the request without
blocking access to the rest of the app.

You can review or revoke permission at any time under **Settings → AI &
Privacy**. Revoking prevents future NOX requests until you explicitly agree
again. To delete local game data, use **Reset campaign**. For privacy questions
or requests relating to Prompt Heist, contact naleyjanhelge@gmail.com.

## Children

The NOX AI chat is not intended for children under 13. A player under the age of
majority must have permission from a parent or legal guardian as required by
OpenRouter's terms and applicable law.

## Security and changes

Requests are transmitted over encrypted HTTPS connections. No internet service
can be guaranteed completely secure. We may update this policy when the app,
OpenRouter, model providers, or legal requirements change. If a change
materially affects what is shared, the app's consent version will be updated so
players are asked again before another NOX request.
