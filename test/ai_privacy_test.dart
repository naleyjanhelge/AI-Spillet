import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:prompt_heist/game/game_controller.dart';
import 'package:prompt_heist/ui/ai_privacy_notice.dart';
import 'package:prompt_heist/ui/prompt_heist_theme.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  test(
    'AI consent persists across campaign reset and can be revoked',
    () async {
      SharedPreferences.setMockInitialValues({});
      final controller = await GameController.load();

      expect(controller.hasAiPrivacyConsent, isFalse);
      await controller.acceptAiPrivacyConsent();
      expect(controller.hasAiPrivacyConsent, isTrue);

      final restored = await GameController.load();
      expect(restored.hasAiPrivacyConsent, isTrue);
      await restored.reset();

      final afterCampaignReset = await GameController.load();
      expect(afterCampaignReset.hasAiPrivacyConsent, isTrue);
      await afterCampaignReset.revokeAiPrivacyConsent();

      final afterRevoke = await GameController.load();
      expect(afterRevoke.hasAiPrivacyConsent, isFalse);
    },
  );

  testWidgets('NOX permission is explicit and Not Now sends nothing', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final controller = await GameController.load();
    bool? result;

    await tester.pumpWidget(
      MaterialApp(
        theme: buildPromptHeistTheme(),
        home: Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: FilledButton(
                onPressed: () async {
                  result = await ensureAiPrivacyConsent(context, controller);
                },
                child: const Text('MESSAGE NOX'),
              ),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('MESSAGE NOX'));
    await tester.pumpAndSettle();
    expect(find.text('BEFORE YOU CHAT WITH NOX'), findsOneWidget);
    expect(
      find.textContaining('Keep real secrets off the channel'),
      findsOneWidget,
    );

    await tester.tap(find.text('NOT NOW'));
    await tester.pumpAndSettle();
    expect(result, isFalse);
    expect(controller.hasAiPrivacyConsent, isFalse);

    await tester.tap(find.text('MESSAGE NOX'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('I UNDERSTAND & CONTINUE'));
    await tester.pumpAndSettle();
    expect(result, isTrue);
    expect(controller.hasAiPrivacyConsent, isTrue);
  });
}
