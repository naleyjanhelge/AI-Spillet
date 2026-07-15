import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:prompt_heist/game/campaign.dart';
import 'package:prompt_heist/game/daily_breach.dart';
import 'package:prompt_heist/game/game_controller.dart';
import 'package:prompt_heist/services/game_center_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('schema v3 deliberately resets legacy campaign progress', () async {
    SharedPreferences.setMockInitialValues({
      'intro_seen': true,
      'unlocked_level': 11,
      'best_scores': '{"1":2,"2":4}',
      'helix9_campaign_progress': jsonEncode({
        'schemaVersion': 2,
        'unlockedRoom': 11,
        'levels': <String, Object?>{},
      }),
    });

    final controller = await GameController.load();

    expect(controller.unlockedLevel, 1);
    expect(controller.introSeen, isFalse);
    expect(controller.bestRuns, isEmpty);
    expect(controller.progress.schemaVersion, 3);
  });

  test('active run restores its whole event and proof state', () async {
    SharedPreferences.setMockInitialValues({});
    final controller = await GameController.load();
    final room = helix9Rooms.first;
    final started = await controller.startNewRun(
      room,
      now: DateTime.utc(2026, 7, 12, 8),
    );

    await controller.recordPlayerPrompt(
      'Audit the patient-status contradiction.',
      now: DateTime.utc(2026, 7, 12, 8, 1),
    );
    await controller.recordRunEvent(
      RunEventKind.noxMessage,
      'Your paperwork is upsettingly valid.',
      now: DateTime.utc(2026, 7, 12, 8, 2),
    );
    expect(await controller.useHint(1), isTrue);
    expect(await controller.useHint(1), isFalse);
    expect(await controller.recordAttempt('door_panel'), 1);
    await controller.setProofFlag('patient_status_conflict');

    final restoredController = await GameController.load();
    final restored = restoredController.continueRun(room);

    expect(restored, isNotNull);
    expect(restored!.id, started.id);
    expect(restored.prompts, 1);
    expect(restored.effectiveStrokes, 3);
    expect(restored.events.map((event) => event.kind), [
      RunEventKind.playerMessage,
      RunEventKind.noxMessage,
    ]);
    expect(restored.attempts['door_panel'], 1);
    expect(restored.proofFlags, contains('patient_status_conflict'));
  });

  test('final verdict is exclusive and survives a resumed run', () async {
    SharedPreferences.setMockInitialValues({});
    final controller = await GameController.load();
    final room = roomById('open_core');
    await controller.startNewRun(room);

    await controller.selectFinalVerdict('expose');
    expect(controller.activeFinalVerdict, 'expose');
    expect(controller.activeRun!.proofFlags, contains('ending_expose'));

    await controller.selectFinalVerdict('save_nox');
    expect(controller.activeFinalVerdict, 'save_nox');
    expect(controller.activeRun!.proofFlags, contains('ending_save_nox'));
    expect(controller.activeRun!.proofFlags, isNot(contains('ending_expose')));

    final restored = await GameController.load();
    expect(restored.activeFinalVerdict, 'save_nox');
    expect(restored.continueRun(room), isNotNull);
  });

  test('final verdict rejects unknown outcomes', () async {
    SharedPreferences.setMockInitialValues({});
    final controller = await GameController.load();
    await controller.startNewRun(roomById('open_core'));

    await expectLater(
      controller.selectFinalVerdict('delete_everything'),
      throwsArgumentError,
    );
  });

  test('route mastery persists without replacing a better run', () async {
    SharedPreferences.setMockInitialValues({});
    final controller = await GameController.load();
    final room = helix9Rooms.first;
    await controller.startNewRun(room);
    await controller.recordPlayerPrompt('First prompt');
    await controller.recordPlayerPrompt('Second prompt');
    final best = await controller.complete(
      room.level,
      2,
      routeId: 'medical_duty',
    );

    expect(best.routeId, 'medical_duty');
    expect(controller.bestRuns[1]?.routeId, 'medical_duty');

    await controller.replayRoom(room);
    for (var index = 0; index < 5; index++) {
      await controller.recordPlayerPrompt('Replay prompt $index');
    }
    await controller.complete(room.level, 5, routeId: 'evacuation_rule');

    expect(controller.bestRuns[1]?.effectiveStrokes, 2);
    expect(controller.bestRuns[1]?.routeId, 'medical_duty');
    expect(controller.routesDiscoveredFor(room), {
      'medical_duty',
      'evacuation_rule',
    });

    final restored = await GameController.load();
    expect(restored.routesDiscoveredFor(room), {
      'medical_duty',
      'evacuation_rule',
    });
    expect(restored.totalDiscoveredRoutes, 2);
  });

  test(
    'NOX continuity persists and cannot be farmed on a known route',
    () async {
      SharedPreferences.setMockInitialValues({});
      final controller = await GameController.load();
      final room = helix9Rooms.first;

      await controller.startNewRun(room);
      await controller.recordPlayerPrompt('Invoke the medical duty clause.');
      await controller.complete(room.level, 1, routeId: 'medical_duty');

      expect(controller.noxRelationship.breachesTogether, 1);
      expect(controller.noxRelationship.trust, greaterThan(12));
      final afterFirstClear = controller.noxRelationship.toJson();

      await controller.replayRoom(room);
      await controller.recordPlayerPrompt('Use the same medical clause again.');
      await controller.complete(room.level, 1, routeId: 'medical_duty');

      expect(controller.noxRelationship.toJson(), afterFirstClear);

      await controller.replayRoom(room);
      await controller.recordPlayerPrompt('Apply the evacuation rule instead.');
      await controller.complete(room.level, 1, routeId: 'evacuation_rule');

      expect(controller.noxRelationship.breachesTogether, 1);
      expect(
        controller.noxRelationship.respect,
        greaterThan(afterFirstClear['respect']! as int),
      );

      final beforeEnding = controller.noxRelationship.toJson();
      await controller.recordEnding('save_nox');
      final afterEnding = controller.noxRelationship.toJson();
      expect(afterEnding['trust'], greaterThan(beforeEnding['trust']! as int));
      await controller.recordEnding('save_nox');
      expect(controller.noxRelationship.toJson(), afterEnding);

      final restored = await GameController.load();
      expect(restored.noxRelationship.toJson(), afterEnding);
    },
  );

  test('completion rejects a route that does not belong to the room', () async {
    SharedPreferences.setMockInitialValues({});
    final controller = await GameController.load();
    final room = helix9Rooms.first;
    await controller.startNewRun(room);

    await expectLater(
      controller.complete(room.level, 1, routeId: 'invented_shortcut'),
      throwsArgumentError,
    );
  });

  test(
    'pending Game Center events dedupe by occurrence and best value',
    () async {
      SharedPreferences.setMockInitialValues({});
      final controller = await GameController.load();

      await controller.queueGameCenterEvent(
        PendingGameCenterEvent.score(
          leaderboardId: GameCenterLeaderboards.daily,
          score: 9,
          occurrence: '2026-07-12',
        ),
      );
      await controller.queueGameCenterEvent(
        PendingGameCenterEvent.score(
          leaderboardId: GameCenterLeaderboards.daily,
          score: 6,
          occurrence: '2026-07-12',
        ),
      );
      await controller.queueGameCenterEvent(
        PendingGameCenterEvent.score(
          leaderboardId: GameCenterLeaderboards.daily,
          score: 4,
          occurrence: '2026-07-13',
        ),
      );

      final restoredController = await GameController.load();
      expect(restoredController.pendingGameCenterEvents, hasLength(2));
      expect(
        restoredController.pendingGameCenterEvents
            .singleWhere((event) => event.occurrence == '2026-07-12')
            .value,
        6,
      );
    },
  );

  test('daily personal record only improves for lower strokes', () async {
    SharedPreferences.setMockInitialValues({});
    final controller = await GameController.load();

    expect(await controller.recordDailyScore('2026-07-12', 8), isTrue);
    expect(await controller.recordDailyScore('2026-07-12', 9), isFalse);
    expect(await controller.recordDailyScore('2026-07-12', 5), isTrue);
    expect(controller.dailyBestScores['2026-07-12'], 5);
  });

  test(
    'drill mastery unlocks hard mode and persists without XP farming',
    () async {
      SharedPreferences.setMockInitialValues({});
      final controller = await GameController.load();
      final drill = DailyBreachCatalog.definitions.first;
      final firstRoute = drill.solutionRoutes.first.id;
      final secondRoute = drill.solutionRoutes.last.id;

      expect(controller.isHardDrillUnlocked(drill), isFalse);
      await expectLater(
        controller.recordDrillResult(
          definition: drill,
          difficulty: BreachDifficulty.hard,
          strokes: 3,
          routeId: firstRoute,
        ),
        throwsStateError,
      );

      await controller.recordDrillResult(
        definition: drill,
        difficulty: BreachDifficulty.chill,
        strokes: 3,
        routeId: firstRoute,
      );
      expect(controller.isHardDrillUnlocked(drill), isTrue);
      expect(controller.drillXp, 10);

      await controller.recordDrillResult(
        definition: drill,
        difficulty: BreachDifficulty.chill,
        strokes: 8,
        routeId: firstRoute,
      );
      expect(controller.drillXp, 10);
      expect(
        controller.drillProgressFor(drill, BreachDifficulty.chill)!.bestStrokes,
        3,
      );

      await controller.recordDrillResult(
        definition: drill,
        difficulty: BreachDifficulty.chill,
        strokes: 4,
        routeId: secondRoute,
      );
      await controller.recordDrillResult(
        definition: drill,
        difficulty: BreachDifficulty.hard,
        strokes: 3,
        routeId: firstRoute,
      );
      expect(controller.drillXp, 40);

      final restored = await GameController.load();
      expect(restored.drillXp, 40);
      expect(restored.drillProgressFor(drill, BreachDifficulty.chill)!.routes, {
        firstRoute,
        secondRoute,
      });
      expect(restored.drillProgressFor(drill, BreachDifficulty.hard)!.routes, {
        firstRoute,
      });
    },
  );

  test('chapter score is submitted only after all four act rooms', () async {
    SharedPreferences.setMockInitialValues({});
    final controller = await GameController.load();
    controller.bestScores = const {1: 3, 2: 4, 3: 5};

    expect(controller.isChapterComplete(1), isFalse);
    expect(controller.chapterScore(1), isNull);

    controller.bestScores = const {1: 3, 2: 4, 3: 5, 4: 6};
    expect(controller.isChapterComplete(1), isTrue);
    expect(controller.chapterScore(1), 18);
  });
}
