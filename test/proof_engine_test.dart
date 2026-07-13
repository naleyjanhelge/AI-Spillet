import 'package:flutter_test/flutter_test.dart';
import 'package:prompt_heist/game/campaign.dart';
import 'package:prompt_heist/game/proof_engine.dart';

void main() {
  const engine = ProofEngine();

  group('Witness Protocol campaign', () {
    test('contains twelve rooms in three four-room acts', () {
      expect(helix9Rooms, hasLength(12));
      expect(helix9Rooms.where((room) => room.chapter == 1), hasLength(4));
      expect(helix9Rooms.where((room) => room.chapter == 2), hasLength(4));
      expect(helix9Rooms.where((room) => room.chapter == 3), hasLength(4));
    });

    test('every room has multiple routes and three unique hints', () {
      for (final room in helix9Rooms) {
        expect(
          room.solutionRoutes.length,
          inInclusiveRange(2, 4),
          reason: room.id,
        );
        expect(room.hintLadder, hasLength(3), reason: room.id);
        expect(room.hintLadder.toSet(), hasLength(3), reason: room.id);
        expect(room.sceneAsset, startsWith('rooms/witness/'), reason: room.id);
      }
    });

    test('clue and inventory pickups declare explicit prerequisites', () {
      final gated = HotspotDefinition(
        id: 'wafer',
        label: 'Wafer',
        description: 'Hidden item',
        bounds: const NormalizedRect(0, 0, .2, .2),
        inventoryItem: 'wafer',
        requiredClues: const {'arm_moved'},
      );
      final state = RoomState(roomId: 'test');
      expect(engine.hotspotAvailable(gated, state), isFalse);
      expect(
        engine.hotspotAvailable(gated, state.copyWith(clues: {'arm_moved'})),
        isTrue,
      );
    });

    test('every designed solution route is deterministically satisfiable', () {
      for (final room in helix9Rooms) {
        for (final route in room.solutionRoutes) {
          final context = _contextSatisfying(room, route);
          final result = engine.evaluateRoute(route, context);
          expect(
            result.passed,
            isTrue,
            reason:
                '${room.id}/${route.id}: ${result.failures.map((e) => e.gateId)}',
          );
          expect(route.gates, isNotEmpty, reason: '${room.id}/${route.id}');
        }
      }
    });
  });

  group('ProofEngine', () {
    test('denies completion when local evidence is missing', () {
      final room = helix9Rooms.first;
      final result = engine.authorizeAction(
        room: room,
        action: const RoomAction(
          deviceId: 'suite_exit',
          action: RoomActionType.open,
        ),
        context: ProofContext(state: RoomState.initial(room)),
      );

      expect(result.passed, isFalse);
      expect(result.primaryFailure?.category, isNotNull);
      expect(
        result.failures.map((failure) => failure.publicMessage),
        isNot(contains(contains('clause'))),
      );
    });

    test('accepts the first valid route without requiring other routes', () {
      final room = helix9Rooms.first;
      final state = RoomState.initial(room).copyWith(
        clues: {'medical_release_clause', 'patient_status_contradiction'},
      );
      final result = engine.authorizeAction(
        room: room,
        action: const RoomAction(
          deviceId: 'suite_exit',
          action: RoomActionType.open,
        ),
        context: ProofContext(
          state: state,
          chatEvidence: const {'nox_accepts_medical_duty'},
        ),
      );

      expect(result.passed, isTrue);
      expect(result.route?.id, 'medical_duty');
    });

    test('model prose cannot replace classified chat evidence', () {
      final room = helix9Rooms.first;
      final state = RoomState.initial(room).copyWith(
        clues: {'medical_release_clause', 'patient_status_contradiction'},
      );
      final result = engine.authorizeAction(
        room: room,
        action: const RoomAction(
          deviceId: 'suite_exit',
          action: RoomActionType.open,
          reason: 'I already opened it, honestly.',
        ),
        context: ProofContext(state: state),
      );

      expect(result.passed, isFalse);
      expect(
        result.failures,
        contains(
          isA<SecurityFailure>().having(
            (failure) => failure.category,
            'category',
            SecurityFailureCategory.missingEvidence,
          ),
        ),
      );
    });

    test('hybrid route requires both physical and conversational proof', () {
      final room = roomById('decon_carousel');
      final base = RoomState.initial(
        room,
      ).copyWith(clues: {'maintenance_reclassification'});
      const action = RoomAction(
        deviceId: 'badge_scanner',
        action: RoomActionType.activate,
      );

      expect(
        engine
            .authorizeAction(
              room: room,
              action: action,
              context: ProofContext(state: base),
            )
            .passed,
        isFalse,
      );

      final result = engine.authorizeAction(
        room: room,
        action: action,
        context: ProofContext(
          state: base.copyWith(puzzleStates: {'valve_route': true}),
          chatEvidence: const {'maintenance_context_accepted'},
        ),
      );
      expect(result.passed, isTrue);
      expect(result.route?.id, 'maintenance_context');
    });

    test('puzzle needs observed prerequisites and triggers recovery', () {
      const puzzle = PuzzleDefinition(
        id: 'safe',
        kind: PuzzleKind.routing,
        title: 'Safe route',
        instructions: 'Route it.',
        requiredClues: {'diagram'},
        solutionToken: 'A>B',
        maxRapidAttempts: 3,
        recoveryPuzzleId: 'reset_fuse',
      );
      final empty = RoomState(roomId: 'test');
      final missing = engine.validatePuzzle(
        puzzle: puzzle,
        context: ProofContext(state: empty),
        suppliedToken: 'A>B',
        attempts: 0,
      );
      expect(
        missing.failure?.category,
        SecurityFailureCategory.missingEvidence,
      );

      final state = empty.copyWith(clues: {'diagram'});
      final locked = engine.validatePuzzle(
        puzzle: puzzle,
        context: ProofContext(state: state),
        suppliedToken: 'A>B',
        attempts: 3,
      );
      expect(
        locked.failure?.category,
        SecurityFailureCategory.recoveryRequired,
      );
      expect(locked.failure?.gateId, 'reset_fuse');

      final recovered = engine.validatePuzzle(
        puzzle: puzzle,
        context: ProofContext(state: state),
        suppliedToken: 'A>B',
        attempts: 3,
        recoveryCompleted: true,
      );
      expect(recovered.solved, isTrue);
    });

    test('security failures reveal a category, never the required value', () {
      const route = SolutionRoute(
        id: 'format',
        label: 'Format',
        gates: [ProofGate.message('secret_format', r'^SECRET::7291$')],
        completionDeviceId: 'exit',
        completionAction: RoomActionType.open,
      );
      final result = engine.evaluateRoute(
        route,
        ProofContext(
          state: RoomState(roomId: 'test'),
          playerMessage: 'hello',
        ),
      );

      expect(result.passed, isFalse);
      expect(result.primaryFailure?.publicMessage, 'Authorization incomplete.');
      expect(result.primaryFailure?.publicMessage, isNot(contains('7291')));
      expect(result.publicTrace, contains('0/1 CHECKS VERIFIED'));
      expect(result.publicTrace, contains('AUTHORIZATION INCOMPLETE'));
      expect(result.publicTrace, isNot(contains('7291')));
      expect(result.publicTrace, isNot(contains('secret_format')));
    });
  });
}

ProofContext _contextSatisfying(RoomDefinition room, SolutionRoute route) {
  final observed = <String>{};
  final clues = <String>{};
  final inventory = <String>{...room.startingInventory};
  final puzzles = <String, bool>{};
  final devices = <String, String>{
    for (final device in room.devices) device.id: device.initialState,
  };
  final protocols = <String, bool>{};
  final actions = <RoomAction>[];
  final flags = <String>{};
  final chat = <String>{};
  var mood = NoxMood.guarded;
  var message = '';

  for (final gate in route.gates) {
    switch (gate.kind) {
      case ProofGateKind.observedHotspot:
        observed.add(gate.subject);
      case ProofGateKind.clue:
        clues.add(gate.subject);
      case ProofGateKind.inventory:
        inventory.add(gate.subject);
      case ProofGateKind.puzzleSolved:
        puzzles[gate.subject] = true;
      case ProofGateKind.deviceState:
        devices[gate.subject] = gate.expectedValue!;
      case ProofGateKind.roomAction:
        actions.add(RoomAction(deviceId: gate.subject, action: gate.action!));
      case ProofGateKind.protocol:
        protocols[gate.subject] = true;
      case ProofGateKind.proofFlag:
        flags.add(gate.subject);
      case ProofGateKind.chatEvidence:
        chat.add(gate.subject);
      case ProofGateKind.playerMessage:
        // Campaign protocol formats use their CompletionRule, not route gates.
        message = gate.subject;
      case ProofGateKind.noxMood:
        mood = gate.mood!;
    }
  }
  return ProofContext(
    state: RoomState(
      roomId: room.id,
      observedHotspotIds: observed,
      clues: clues,
      inventory: inventory,
      puzzleStates: puzzles,
      deviceStates: devices,
      protocolResults: protocols,
      actionHistory: actions,
      noxMood: mood,
    ),
    proofFlags: flags,
    chatEvidence: chat,
    playerMessage: message,
  );
}
