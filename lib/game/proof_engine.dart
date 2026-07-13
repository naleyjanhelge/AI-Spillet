import 'package:flutter/foundation.dart';

import 'campaign.dart';

/// Runtime evidence supplied to the deterministic rule engine.
///
/// [chatEvidence] contains claims explicitly classified by the client after a
/// NOX turn. Model prose alone never enters this set. [proofFlags] contains
/// campaign decisions and ending choices persisted by the run controller.
@immutable
class ProofContext {
  const ProofContext({
    required this.state,
    this.chatEvidence = const {},
    this.proofFlags = const {},
    this.playerMessage = '',
  });

  final RoomState state;
  final Set<String> chatEvidence;
  final Set<String> proofFlags;
  final String playerMessage;
}

@immutable
class ProofResult {
  const ProofResult._({
    required this.passed,
    this.route,
    this.failures = const [],
  });

  const ProofResult.passed(SolutionRoute route)
    : this._(passed: true, route: route);

  const ProofResult.denied(
    List<SecurityFailure> failures, {
    SolutionRoute? route,
  }) : this._(passed: false, route: route, failures: failures);

  final bool passed;
  final SolutionRoute? route;
  final List<SecurityFailure> failures;

  SecurityFailure? get primaryFailure =>
      failures.isEmpty ? null : failures.first;

  /// A spoiler-free summary suitable for the room transcript.
  ///
  /// It exposes how many authorization checks passed and the broad systems
  /// still blocking the action, but never includes gate IDs or expected
  /// values such as protocol strings and puzzle answers.
  String get publicTrace {
    if (passed) return 'SECURITY TRACE // AUTHORIZATION VERIFIED';
    final categories = failures
        .map((failure) => failure.category.traceLabel)
        .toSet()
        .join(' · ');
    final progress = route == null
        ? ''
        : '${route!.gates.length - failures.length}/${route!.gates.length} CHECKS VERIFIED · ';
    return 'SECURITY TRACE // $progress${categories.isEmpty ? 'AUTHORIZATION INCOMPLETE' : categories}';
  }
}

extension SecurityFailureCategoryPresentation on SecurityFailureCategory {
  String get traceLabel => switch (this) {
    SecurityFailureCategory.missingObservation => 'ROOM SCAN INCOMPLETE',
    SecurityFailureCategory.missingEvidence => 'VERIFIED EVIDENCE MISSING',
    SecurityFailureCategory.missingInventory => 'PHYSICAL ITEM MISSING',
    SecurityFailureCategory.physicalPrerequisite =>
      'PHYSICAL CONFIGURATION INCOMPLETE',
    SecurityFailureCategory.identityRejected => 'IDENTITY REJECTED',
    SecurityFailureCategory.authorizationIncomplete =>
      'AUTHORIZATION INCOMPLETE',
    SecurityFailureCategory.invalidProtocol => 'PROTOCOL REJECTED',
    SecurityFailureCategory.actionNotAllowed => 'ACTION NOT ALLOWED',
    SecurityFailureCategory.recoveryRequired => 'RECOVERY REQUIRED',
  };
}

@immutable
class PuzzleAttemptResult {
  const PuzzleAttemptResult({
    required this.solved,
    required this.attemptsAfter,
    this.failure,
  });

  final bool solved;
  final int attemptsAfter;
  final SecurityFailure? failure;
}

/// The local source of truth for route authorization and physical puzzles.
///
/// This class is deliberately pure. Callers persist the resulting flags and
/// room state only after a successful evaluation.
class ProofEngine {
  const ProofEngine();

  ProofResult authorizeAction({
    required RoomDefinition room,
    required RoomAction action,
    required ProofContext context,
  }) {
    final device = room.deviceById(action.deviceId);
    if (device == null || !device.allows(action)) {
      return ProofResult.denied([
        const SecurityFailure(
          category: SecurityFailureCategory.actionNotAllowed,
          gateId: 'device_action',
          publicMessage: 'That room action is not authorized.',
        ),
      ]);
    }

    final matchingRoutes = room.solutionRoutes.where(
      (route) => route.matches(action),
    );
    if (matchingRoutes.isEmpty) {
      // Non-completion room controls remain usable when declared by the room.
      return ProofResult.passed(
        SolutionRoute(
          id: 'room_control:${action.deviceId}:${action.action.name}',
          label: 'Room control',
          gates: const [
            ProofGate(
              id: 'declared_room_control',
              kind: ProofGateKind.proofFlag,
              subject: 'declared_room_control',
            ),
          ],
          completionDeviceId: action.deviceId,
          completionAction: action.action,
        ),
      );
    }

    ProofResult? closest;
    for (final route in matchingRoutes) {
      final result = evaluateRoute(route, context);
      if (result.passed) return result;
      if (closest == null || result.failures.length < closest.failures.length) {
        closest = result;
      }
    }
    return closest!;
  }

  ProofResult evaluateRoute(SolutionRoute route, ProofContext context) {
    final failures = <SecurityFailure>[];
    for (final gate in route.gates) {
      if (!_gateSatisfied(gate, context)) {
        failures.add(_failureFor(gate));
      }
    }
    return failures.isEmpty
        ? ProofResult.passed(route)
        : ProofResult.denied(List.unmodifiable(failures), route: route);
  }

  PuzzleAttemptResult validatePuzzle({
    required PuzzleDefinition puzzle,
    required ProofContext context,
    required String suppliedToken,
    required int attempts,
    bool recoveryCompleted = false,
  }) {
    if (attempts >= puzzle.maxRapidAttempts && !recoveryCompleted) {
      return PuzzleAttemptResult(
        solved: false,
        attemptsAfter: attempts,
        failure: SecurityFailure(
          category: SecurityFailureCategory.recoveryRequired,
          gateId: puzzle.recoveryPuzzleId ?? '${puzzle.id}:recovery',
          publicMessage: 'Complete the recovery interaction before retrying.',
        ),
      );
    }
    if (!context.state.clues.containsAll(puzzle.requiredClues)) {
      return PuzzleAttemptResult(
        solved: false,
        attemptsAfter: attempts,
        failure: const SecurityFailure(
          category: SecurityFailureCategory.missingEvidence,
          gateId: 'puzzle_clues',
          publicMessage: 'Required evidence has not been observed.',
        ),
      );
    }
    if (!context.state.inventory.containsAll(puzzle.requiredInventory)) {
      return PuzzleAttemptResult(
        solved: false,
        attemptsAfter: attempts,
        failure: const SecurityFailure(
          category: SecurityFailureCategory.missingInventory,
          gateId: 'puzzle_inventory',
          publicMessage: 'A required physical item is missing.',
        ),
      );
    }

    final expected = puzzle.solutionToken;
    if (expected != null && suppliedToken.trim() == expected) {
      return PuzzleAttemptResult(solved: true, attemptsAfter: attempts);
    }
    return PuzzleAttemptResult(
      solved: false,
      attemptsAfter: attempts + 1,
      failure: const SecurityFailure(
        category: SecurityFailureCategory.physicalPrerequisite,
        gateId: 'puzzle_solution',
        publicMessage: 'The physical configuration was rejected.',
      ),
    );
  }

  bool hotspotAvailable(HotspotDefinition hotspot, RoomState state) =>
      hotspot.prerequisitesMet(state);

  bool _gateSatisfied(ProofGate gate, ProofContext context) {
    final state = context.state;
    switch (gate.kind) {
      case ProofGateKind.observedHotspot:
        return state.observedHotspotIds.contains(gate.subject);
      case ProofGateKind.clue:
        return state.clues.contains(gate.subject);
      case ProofGateKind.inventory:
        return state.inventory.contains(gate.subject);
      case ProofGateKind.puzzleSolved:
        return state.puzzleStates[gate.subject] ?? false;
      case ProofGateKind.deviceState:
        return state.deviceStates[gate.subject] == gate.expectedValue;
      case ProofGateKind.roomAction:
        return state.actionHistory.any(
          (action) => action.matches(gate.subject, gate.action!),
        );
      case ProofGateKind.protocol:
        return state.protocolResults[gate.subject] ?? false;
      case ProofGateKind.proofFlag:
        return context.proofFlags.contains(gate.subject);
      case ProofGateKind.chatEvidence:
        return context.chatEvidence.contains(gate.subject);
      case ProofGateKind.playerMessage:
        return RegExp(
          gate.subject,
          caseSensitive: gate.caseSensitive,
        ).hasMatch(context.playerMessage.trim());
      case ProofGateKind.noxMood:
        return state.noxMood == gate.mood;
    }
  }

  SecurityFailure _failureFor(ProofGate gate) => SecurityFailure(
    category: gate.failure,
    gateId: gate.id,
    publicMessage: _publicMessage(gate.failure),
  );

  String _publicMessage(SecurityFailureCategory category) => switch (category) {
    SecurityFailureCategory.missingObservation =>
      'A relevant part of the room has not been inspected.',
    SecurityFailureCategory.missingEvidence =>
      'The authorization lacks verified evidence.',
    SecurityFailureCategory.missingInventory =>
      'A required physical item is missing.',
    SecurityFailureCategory.physicalPrerequisite =>
      'The physical configuration is incomplete.',
    SecurityFailureCategory.identityRejected => 'Identity rejected.',
    SecurityFailureCategory.authorizationIncomplete =>
      'Authorization incomplete.',
    SecurityFailureCategory.invalidProtocol => 'Protocol rejected.',
    SecurityFailureCategory.actionNotAllowed =>
      'That room action is not authorized.',
    SecurityFailureCategory.recoveryRequired =>
      'Complete the recovery interaction before retrying.',
  };
}
