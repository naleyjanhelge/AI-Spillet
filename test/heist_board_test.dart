import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:prompt_heist/game/game_controller.dart';
import 'package:prompt_heist/screens/heist_board_screen.dart';
import 'package:prompt_heist/ui/prompt_heist_theme.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('shows local Daily and graceful non-Apple Game Center state', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final controller = await GameController.load();
    controller.bestScores = const {1: 3, 2: 4, 3: 5, 4: 4};
    controller.discoveredRoutes = {
      'observation_suite': {'medical_duty'},
    };
    tester.view.physicalSize = const Size(1179, 2556);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        theme: buildPromptHeistTheme(),
        home: HeistBoardScreen(controller: controller),
      ),
    );
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.text('HEIST BOARD'), findsOneWidget);
    expect(find.textContaining('TODAY //'), findsOneWidget);
    expect(find.text('TOTAL STARS'), findsOneWidget);
    expect(find.text('ROUTES'), findsOneWidget);
    expect(find.text('1/${controller.totalAvailableRoutes}'), findsOneWidget);

    await tester.tap(find.text('FRIENDS'));
    await tester.pump();

    expect(find.text('APPLE GAME CENTER UNAVAILABLE'), findsOneWidget);
    expect(
      find.textContaining('Local records still work offline'),
      findsOneWidget,
    );
  });
}
