import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../game/game_controller.dart';
import 'prompt_heist_theme.dart';

const openRouterPrivacyUrl = 'https://openrouter.ai/privacy';
const promptHeistPrivacyUrl =
    'https://naleyjanhelge.github.io/Prompt-Heist/privacy.html';

/// Presents the just-in-time permission required before any player-authored
/// content is sent to OpenRouter or an AI model provider.
Future<bool> ensureAiPrivacyConsent(
  BuildContext context,
  GameController controller,
) async {
  if (controller.hasAiPrivacyConsent) return true;

  return await showDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder: (dialogContext) => AlertDialog(
          icon: const Icon(Icons.privacy_tip_rounded, color: AppColors.cyan),
          title: const Text('BEFORE YOU CHAT WITH NOX'),
          content: const SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Your message, recent NOX conversation, selected in-game '
                  'evidence, and required game state are sent to OpenRouter '
                  'and a third-party AI model to generate NOX\'s reply.',
                ),
                SizedBox(height: 14),
                _PrivacyCallout(
                  icon: Icons.no_accounts_rounded,
                  title: 'Keep real secrets off the channel',
                  body:
                      'Never enter real names, contact details, passwords, '
                      'health or financial information, workplace secrets, '
                      'or other personal, sensitive, or confidential data.',
                ),
                SizedBox(height: 12),
                Text(
                  'Prompt Heist uses free AI models. The app requests '
                  'providers that say they do not collect prompts for '
                  'training and disables response caching, but provider '
                  'availability and policies can change. Treat NOX chat as '
                  'non-private.',
                ),
                SizedBox(height: 12),
                Text(
                  'OpenRouter may retain request metadata such as token '
                  'counts and latency. Campaign progress and resumable '
                  'dialogue are stored locally on this device.',
                  style: TextStyle(color: AppColors.textMuted),
                ),
                SizedBox(height: 12),
                Text(
                  'You must be at least 13, or have permission from a parent '
                  'or guardian, to use the AI chat.',
                  style: TextStyle(color: AppColors.textMuted),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('NOT NOW'),
            ),
            FilledButton(
              onPressed: () async {
                await controller.acceptAiPrivacyConsent();
                if (dialogContext.mounted) {
                  Navigator.of(dialogContext).pop(true);
                }
              },
              child: const Text('I UNDERSTAND & CONTINUE'),
            ),
          ],
        ),
      ) ??
      false;
}

Future<void> showAiPrivacyDetails(
  BuildContext context,
  GameController controller,
) async {
  await showDialog<void>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      icon: Icon(
        controller.hasAiPrivacyConsent
            ? Icons.shield_rounded
            : Icons.shield_outlined,
        color: controller.hasAiPrivacyConsent
            ? AppColors.success
            : AppColors.textMuted,
      ),
      title: const Text('AI & PRIVACY'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _PrivacyStatus(granted: controller.hasAiPrivacyConsent),
            const SizedBox(height: 18),
            const _PrivacySection(
              title: 'WHAT LEAVES THIS DEVICE',
              body:
                  'Your message, up to 18 recent NOX messages, selected '
                  'in-game evidence, and the game state needed to answer.',
            ),
            const _PrivacySection(
              title: 'WHO PROCESSES IT',
              body:
                  'OpenRouter and the third-party free AI model provider '
                  'selected for that request. Prompt Heist asks OpenRouter '
                  'to use only providers that deny data collection and also '
                  'disables response caching.',
            ),
            const _PrivacySection(
              title: 'YOUR CHOICE',
              body:
                  'Do not enter personal, sensitive, confidential, health, '
                  'financial, password, or workplace information. You can '
                  'revoke AI access below; the rest of the app remains '
                  'available and you will be asked again before another '
                  'NOX request.',
            ),
            const _PolicyLink(
              label: 'Prompt Heist privacy policy',
              url: promptHeistPrivacyUrl,
            ),
            const _PolicyLink(
              label: 'OpenRouter privacy policy',
              url: openRouterPrivacyUrl,
            ),
          ],
        ),
      ),
      actions: [
        if (controller.hasAiPrivacyConsent)
          TextButton(
            onPressed: () async {
              await controller.revokeAiPrivacyConsent();
              if (dialogContext.mounted) Navigator.of(dialogContext).pop();
            },
            child: const Text(
              'REVOKE AI ACCESS',
              style: TextStyle(color: AppColors.danger),
            ),
          ),
        FilledButton(
          onPressed: () => Navigator.of(dialogContext).pop(),
          child: const Text('DONE'),
        ),
      ],
    ),
  );
}

class _PolicyLink extends StatelessWidget {
  const _PolicyLink({required this.label, required this.url});

  final String label;
  final String url;

  @override
  Widget build(BuildContext context) => Align(
    alignment: Alignment.centerLeft,
    child: TextButton.icon(
      onPressed: () async {
        final opened = await launchUrl(
          Uri.parse(url),
          mode: LaunchMode.externalApplication,
        );
        if (!opened && context.mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text('Could not open $url')));
        }
      },
      icon: const Icon(Icons.open_in_new_rounded, size: 18),
      label: Text(label),
    ),
  );
}

class _PrivacyCallout extends StatelessWidget {
  const _PrivacyCallout({
    required this.icon,
    required this.title,
    required this.body,
  });

  final IconData icon;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: AppColors.danger.withValues(alpha: .08),
      border: Border.all(color: AppColors.danger.withValues(alpha: .35)),
      borderRadius: BorderRadius.circular(14),
    ),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: AppColors.danger, size: 21),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: const TextStyle(fontWeight: FontWeight.w800)),
              const SizedBox(height: 4),
              Text(body, style: const TextStyle(color: AppColors.textMuted)),
            ],
          ),
        ),
      ],
    ),
  );
}

class _PrivacyStatus extends StatelessWidget {
  const _PrivacyStatus({required this.granted});
  final bool granted;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(13),
    decoration: BoxDecoration(
      color: (granted ? AppColors.success : AppColors.textMuted).withValues(
        alpha: .09,
      ),
      borderRadius: BorderRadius.circular(12),
    ),
    child: Row(
      children: [
        Icon(
          granted ? Icons.check_circle_rounded : Icons.pause_circle_rounded,
          color: granted ? AppColors.success : AppColors.textMuted,
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            granted
                ? 'AI access is enabled.'
                : 'AI access is off. No NOX request can be sent.',
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
        ),
      ],
    ),
  );
}

class _PrivacySection extends StatelessWidget {
  const _PrivacySection({required this.title, required this.body});
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 16),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            color: AppColors.cyan,
            fontWeight: FontWeight.w800,
            fontSize: 12,
            letterSpacing: .7,
          ),
        ),
        const SizedBox(height: 4),
        Text(body, style: const TextStyle(color: AppColors.textMuted)),
      ],
    ),
  );
}
