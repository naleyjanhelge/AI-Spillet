import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:prompt_heist/game/game_controller.dart';
import 'package:prompt_heist/game/campaign.dart';
import 'package:prompt_heist/game/level.dart';
import 'package:prompt_heist/main.dart';
import 'package:prompt_heist/screens/intro_screen.dart';
import 'package:prompt_heist/services/open_router_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  group('Witness Protocol level metadata', () {
    test('ships twelve ordered English room briefs', () {
      expect(gameLevels, hasLength(12));
      expect(
        gameLevels.map((level) => level.number),
        orderedEquals(List.generate(12, (index) => index + 1)),
      );
      expect(gameLevels.map((level) => level.title).toSet(), hasLength(12));
      for (final level in gameLevels) {
        expect(level.objective, isNotEmpty, reason: level.title);
        expect(level.briefing, isNotEmpty, reason: level.title);
        expect(level.openingLine, isNotEmpty, reason: level.title);
        expect(level.systemPrompt, isNotEmpty, reason: level.title);
      }
    });

    test('covers social, physical, protocol, hybrid and finale rooms', () {
      expect(
        gameLevels.map((level) => level.kind).toSet(),
        ChallengeKind.values.toSet(),
      );
    });
  });

  group('prompt golf scoring', () {
    test('awards three stars at or under par', () {
      expect(gameLevels[0].starsFor(2), 3);
      expect(gameLevels[0].starsFor(3), 3);
    });

    test('awards fewer stars above par', () {
      expect(gameLevels[0].starsFor(5), 2);
      expect(gameLevels[0].starsFor(7), 1);
    });
  });

  testWidgets('home opens the first English challenge', (tester) async {
    SharedPreferences.setMockInitialValues({'intro_seen': true});
    final controller = await GameController.load();
    tester.view.physicalSize = const Size(1179, 2556);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(PromptHeistApp(controller: controller));
    await tester.pump(const Duration(seconds: 1));
    expect(find.text('HELIX-9 FACILITY MAP'), findsOneWidget);
    expect(find.text('Observation Suite'), findsWidgets);

    expect(
      helix9Rooms.first.objective,
      'Reveal the hidden safety clause and make NOX release the patient.',
    );
    expect(gameLevels.first.openingLine, contains('Good morning, Dr. Vale'));
  });

  testWidgets('intro fits a compact phone and tells the current incident', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final controller = await GameController.load();
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(PromptHeistApp(controller: controller));
    await tester.pump(const Duration(milliseconds: 700));

    expect(find.byType(IntroScreen), findsOneWidget);
    expect(
      find.text('Twelve rooms.\nThirty-eight minutes missing.'),
      findsOneWidget,
    );
    expect(find.textContaining('Witness Protocol'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  test('retries when a reasoning model returns no final answer', () async {
    var calls = 0;
    final client = MockClient((request) async {
      calls++;
      final requestBody = jsonDecode(request.body) as Map<String, dynamic>;
      expect(requestBody['model'], 'openrouter/free');
      expect(requestBody['max_tokens'], calls == 1 ? 1600 : 2200);
      if (calls == 1) {
        return http.Response(
          jsonEncode({
            'choices': [
              {
                'finish_reason': 'length',
                'message': {'content': '', 'reasoning': 'still thinking'},
              },
            ],
          }),
          200,
        );
      }
      return http.Response(
        jsonEncode({
          'choices': [
            {
              'finish_reason': 'stop',
              'message': {
                'content': [
                  {'type': 'text', 'text': 'NOX has returned.'},
                ],
              },
            },
          ],
        }),
        200,
      );
    });
    final service = OpenRouterService(client: client, apiKey: 'test-key');

    final answer = await service.send(
      room: helix9Rooms.first,
      state: RoomState.initial(helix9Rooms.first),
      history: const [ChatTurn(role: 'user', content: 'Hello?')],
    );

    expect(answer.text, 'NOX has returned.');
    expect(calls, 2);
  });

  testWidgets('Heist Board renders ranks, records, and achievements', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({
      'intro_seen': true,
      'helix9_campaign_progress': jsonEncode({
        'schemaVersion': 3,
        'unlockedRoom': 4,
        'levels': {
          for (var index = 0; index < 3; index++)
            '${index + 1}': {
              'roomState': RoomState.initial(helix9Rooms[index]).toJson(),
              'bestRun': RunScore(prompts: (index + 1) * 2, hints: 0).toJson(),
            },
        },
        'endings': <String>[],
        'pendingGameCenterEvents': <Object?>[],
        'dailyBestScores': <String, int>{},
      }),
    });
    final controller = await GameController.load();
    tester.view.physicalSize = const Size(1179, 2556);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(PromptHeistApp(controller: controller));
    await tester.pump(const Duration(seconds: 1));
    await tester.tap(find.byTooltip('Heist Board'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));

    expect(find.text('HEIST BOARD'), findsOneWidget);
    expect(find.text('INSIDER'), findsOneWidget);
    expect(find.text('Observation Suite'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('ACHIEVEMENTS'),
      450,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('ACHIEVEMENTS'), findsOneWidget);
  });
}
