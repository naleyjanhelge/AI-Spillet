import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:prompt_heist/game/daily_breach.dart';
import 'package:prompt_heist/game/game_controller.dart';
import 'package:prompt_heist/screens/drill_lab_screen.dart';
import 'package:prompt_heist/ui/prompt_heist_theme.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('drill lab exposes quick play and locks hard per drill', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final controller = await GameController.load();
    tester.view.physicalSize = const Size(393, 852);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        theme: buildPromptHeistTheme(),
        home: DrillLabScreen(controller: controller),
      ),
    );
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.text('NOX DRILLS'), findsOneWidget);
    expect(find.text('FIVE-MINUTE HEISTS'), findsOneWidget);
    expect(find.text('Hazardous Coffee Exception'), findsOneWidget);
    expect(
      find.text('${DailyBreachCatalog.definitions.length}'),
      findsOneWidget,
    );

    await tester.tap(find.text('HARD'));
    await tester.pump();
    expect(find.text('Clear CHILL to unlock.'), findsWidgets);
    expect(tester.takeException(), isNull);
  });
}
