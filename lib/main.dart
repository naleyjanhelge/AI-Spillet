import 'dart:async';

import 'package:flutter/material.dart';

import 'game/game_controller.dart';
import 'screens/home_screen.dart';
import 'screens/intro_screen.dart';
import 'services/game_center_service.dart';
import 'services/audio_service.dart';
import 'ui/prompt_heist_theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final controller = await GameController.load();
  await PromptHeistAudio.instance.load();
  unawaited(_restoreGameCenter(controller));
  if (const bool.fromEnvironment('PROMPT_HEIST_DEMO')) {
    controller
      ..introSeen = true
      ..unlockedLevel = 4
      ..bestScores = {1: 2, 2: 4, 3: 6};
  }
  runApp(PromptHeistApp(controller: controller));
}

Future<void> _restoreGameCenter(GameController controller) async {
  final gameCenter = GameCenterService();
  if (!gameCenter.isAvailable || !await gameCenter.authenticate()) return;
  final result = await gameCenter.flushPendingEvents(
    controller.pendingGameCenterEvents,
  );
  if (result.submittedCount > 0 ||
      result.remaining.length != controller.pendingGameCenterEvents.length) {
    await controller.replacePendingGameCenterEvents(result.remaining);
  }
}

class PromptHeistApp extends StatelessWidget {
  const PromptHeistApp({super.key, required this.controller});

  final GameController controller;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Prompt Heist',
      debugShowCheckedModeBanner: false,
      theme: buildPromptHeistTheme(),
      home: controller.introSeen
          ? HomeScreen(controller: controller)
          : IntroScreen(controller: controller),
    );
  }
}
