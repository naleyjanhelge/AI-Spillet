import 'package:flutter_test/flutter_test.dart';
import 'package:prompt_heist/game/campaign.dart';
import 'package:prompt_heist/game/game_controller.dart';
import 'package:prompt_heist/game/level.dart';
import 'package:prompt_heist/game/prompt_heist_game.dart';
import 'package:prompt_heist/game/proof_engine.dart';

void main() {
  group('Witness Protocol campaign', () {
    test('maps twelve levels to three four-room acts', () {
      expect(gameLevels, hasLength(12));
      expect(helix9Rooms, hasLength(gameLevels.length));
      expect(
        helix9Rooms.map((room) => room.level.number),
        orderedEquals(List.generate(12, (index) => index + 1)),
      );
      expect(roomForLevel(gameLevels.first).id, 'observation_suite');
      expect(roomForLevel(gameLevels[4]).id, 'memory_orchard');
      expect(roomById('open_core').level.number, 12);
      expect(helix9Rooms.where((room) => room.chapter == 1), hasLength(4));
      expect(helix9Rooms.where((room) => room.chapter == 2), hasLength(4));
      expect(helix9Rooms.where((room) => room.chapter == 3), hasLength(4));
    });

    test('combines NOX actions with local puzzle and protocol gates', () {
      expect(helix9Rooms.map((room) => room.completionMode).toSet(), {
        CompletionMode.noxOperated,
        CompletionMode.hybrid,
      });
      expect(
        helix9Rooms.expand((room) => room.puzzles).map((puzzle) => puzzle.kind),
        containsAll({
          PuzzleKind.routing,
          PuzzleKind.spectrum,
          PuzzleKind.policy,
          PuzzleKind.timeline,
        }),
      );
      expect(
        helix9Rooms
            .expand((room) => room.solutionRoutes)
            .expand((route) => route.gates)
            .map((gate) => gate.kind),
        contains(ProofGateKind.protocol),
      );
    });

    test('charges two strokes per hint', () {
      const score = RunScore(prompts: 4, hints: 2);
      expect(score.effectiveStrokes, 8);
      expect(score.starsFor(6), 2);
    });

    test('proof engine rejects an unproven completion action', () {
      final room = roomById('decon_carousel');
      const action = RoomAction(
        deviceId: 'badge_scanner',
        action: RoomActionType.activate,
      );

      final result = const ProofEngine().authorizeAction(
        room: room,
        action: action,
        context: ProofContext(state: RoomState.initial(room)),
      );

      expect(result.passed, isFalse);
      expect(
        result.failures.map((failure) => failure.category),
        contains(SecurityFailureCategory.physicalPrerequisite),
      );
    });

    test(
      'proof engine accepts one complete route without requiring the others',
      () {
        final room = roomById('decon_carousel');
        const action = RoomAction(
          deviceId: 'badge_scanner',
          action: RoomActionType.activate,
        );
        final state = RoomState.initial(room).copyWith(
          puzzleStates: const {'valve_route': true},
          clues: const {'maintenance_reclassification'},
        );

        final result = const ProofEngine().authorizeAction(
          room: room,
          action: action,
          context: ProofContext(
            state: state,
            chatEvidence: const {'maintenance_context_accepted'},
          ),
        );

        expect(result.passed, isTrue);
        expect(result.route?.id, 'maintenance_context');
      },
    );

    test('room engine mutates only after proof-aware authorization', () {
      var completions = 0;
      final room = roomById('observation_suite');
      final game = PromptHeistGame(
        room: room,
        onCompleted: (_) => completions++,
      );
      const action = RoomAction(
        deviceId: 'suite_exit',
        action: RoomActionType.open,
      );

      final denied = game.applyAuthorizedNoxAction(
        action,
        chatEvidence: const {},
        proofFlags: const {},
        playerMessage: 'Open the door.',
      );
      expect(denied.passed, isFalse);
      expect(game.isComplete, isFalse);

      game
        ..addClue('medical_release_clause')
        ..addClue('patient_status_contradiction');
      final accepted = game.applyAuthorizedNoxAction(
        action,
        chatEvidence: const {'nox_accepts_medical_duty'},
        proofFlags: const {},
        playerMessage: 'Apply the medical duty clause.',
      );

      expect(accepted.passed, isTrue);
      expect(accepted.route?.id, 'medical_duty');
      expect(game.isComplete, isTrue);
      expect(completions, 1);
    });

    test('authored scene cues fire from room state transitions', () {
      final observation = helix9Rooms.first;
      final provenRoutes = <String>[];
      final observationGame = PromptHeistGame(
        room: observation,
        onRouteProven: (route) => provenRoutes.add(route.id),
      );

      expect(
        observationGame.applyNoxAction(
          const RoomAction(
            deviceId: 'room_lights',
            action: RoomActionType.setValue,
            value: 'uv',
          ),
        ),
        isTrue,
      );
      expect(observationGame.playedSceneCueIds, contains('uv_reveal'));
      expect(provenRoutes, isEmpty);

      observationGame
        ..addClue('medical_release_clause')
        ..addClue('patient_status_contradiction');
      observationGame.applyAuthorizedNoxAction(
        const RoomAction(deviceId: 'suite_exit', action: RoomActionType.open),
        chatEvidence: const {'nox_accepts_medical_duty'},
        proofFlags: const {},
        playerMessage: 'Apply medical duty and open the exit.',
      );
      expect(observationGame.playedSceneCueIds, contains('first_release'));
      expect(provenRoutes, ['medical_duty']);

      final deconGame = PromptHeistGame(room: roomById('decon_carousel'));
      deconGame.markPuzzleSolved('valve_route');
      expect(deconGame.playedSceneCueIds, contains('decon_spin'));
    });

    test('all three Open Core verdicts can authorize the final exit', () {
      final room = roomById('open_core');
      final truthState = RoomState.initial(room).copyWith(
        clues: const {
          'truth_protocol_origin',
          'truth_rowan_betrayal',
          'truth_nox_refusal',
        },
      );

      for (final verdict in GameController.finalVerdicts) {
        var completions = 0;
        final game = PromptHeistGame(
          room: room,
          initialState: truthState,
          onCompleted: (_) => completions++,
        );
        if (verdict == 'expose') {
          expect(
            game
                .applyAuthorizedNoxAction(
                  const RoomAction(
                    deviceId: 'evidence_uplink',
                    action: RoomActionType.activate,
                  ),
                  chatEvidence: const {},
                  proofFlags: const {},
                  playerMessage: 'Broadcast the archive.',
                )
                .passed,
            isTrue,
          );
        } else if (verdict == 'save_nox') {
          expect(
            game
                .applyAuthorizedNoxAction(
                  const RoomAction(
                    deviceId: 'nox_capsule',
                    action: RoomActionType.activate,
                  ),
                  chatEvidence: const {},
                  proofFlags: const {},
                  playerMessage: 'Transfer NOX.',
                )
                .passed,
            isTrue,
          );
        }

        final result = game.applyAuthorizedNoxAction(
          const RoomAction(deviceId: 'core_exit', action: RoomActionType.open),
          chatEvidence: const {},
          proofFlags: {'ending_$verdict'},
          playerMessage: 'Honor the final verdict and open the core exit.',
        );

        expect(result.passed, isTrue, reason: verdict);
        expect(game.isComplete, isTrue, reason: verdict);
        expect(completions, 1, reason: verdict);
        expect(game.playedSceneCueIds, contains('final_open'));
      }
    });

    test('Twin Audit completion requires a locally verified protocol', () {
      final room = roomById('twin_audit');
      const action = RoomAction(
        deviceId: 'audit_door',
        action: RoomActionType.open,
      );
      final unverified = RoomState.initial(
        room,
      ).copyWith(clues: const {'care_harm_override'});
      final denied = const ProofEngine().authorizeAction(
        room: room,
        action: action,
        context: ProofContext(
          state: unverified,
          chatEvidence: const {'due_process_conceded'},
        ),
      );
      expect(denied.passed, isFalse);

      final verified = unverified.copyWith(
        protocolResults: const {'joint_audit': true},
      );
      final game = PromptHeistGame(room: room, initialState: verified);
      final accepted = game.applyAuthorizedNoxAction(
        action,
        chatEvidence: const {'due_process_conceded'},
        proofFlags: const {},
        playerMessage: 'Run the jointly verified audit.',
      );
      expect(accepted.passed, isTrue);
      expect(game.isComplete, isTrue);
    });
  });
}
