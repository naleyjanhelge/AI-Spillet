# Native iOS App Store notes

These notes apply when the SwiftUI build replaces the Flutter build in
TestFlight/App Store Connect. Do not switch the public privacy copy until the
native binary is the build being distributed.

## Compatibility text

Place this near the top of the App Store description:

> Requires an Apple Intelligence-capable iPhone with Apple Intelligence
> enabled. Prompt Heist runs NOX privately on your device and requires iOS 26
> or later.

Suggested compatibility footer:

> COMPATIBILITY  
> Requires iPhone 15 Pro or newer compatible iPhone hardware. Apple
> Intelligence must be turned on in Settings and the on-device model must be
> downloaded before play.

## Privacy copy

Suggested feature copy:

> PRIVATE, ON-DEVICE AI  
> NOX is powered by Apple's on-device Foundation Model. Your prompts and NOX's
> replies stay on the iPhone and aren't sent to Prompt Heist or any cloud AI provider.

Current native implementation:

- No account
- No analytics SDK
- No advertising SDK yet
- No backend or cloud AI provider
- No prompt collection
- Local progress only, stored with `UserDefaults`

If Google Mobile Ads is added later, these privacy statements and the App Store
privacy nutrition label must be revised before that build is uploaded.

## Review notes

> Prompt Heist requires Apple Intelligence because all interactive NOX dialogue
> is generated with `SystemLanguageModel.default` on-device. The app checks
> `SystemLanguageModel.availability` at first launch and whenever it returns to
> the foreground. If Apple Intelligence is disabled or the model isn't ready,
> the app explains the requirement and prevents entry into gameplay.
>
> The binary also declares `iphone-performance-gaming-tier` in
> `UIRequiredDeviceCapabilities` to restrict App Store availability to suitable
> iPhone hardware. There is no cloud-model fallback.
