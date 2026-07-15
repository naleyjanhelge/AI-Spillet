import 'package:flutter_test/flutter_test.dart';
import 'package:prompt_heist/game/daily_breach.dart';
import 'package:prompt_heist/screens/daily_breach_screen.dart';

void main() {
  test('daily breach selection is deterministic in UTC', () {
    final beforeMidnight = DailyBreachCatalog.forDate(
      DateTime.parse('2026-07-12T23:59:59Z'),
    );
    final sameUtcDay = DailyBreachCatalog.forDate(
      DateTime.parse('2026-07-13T06:59:59+07:00'),
    );

    expect(beforeMidnight.occurrence, '2026-07-12');
    expect(sameUtcDay.occurrence, beforeMidnight.occurrence);
    expect(sameUtcDay.definition.id, beforeMidnight.definition.id);
    expect(beforeMidnight.previousOccurrence, '2026-07-11');
  });

  test('every daily puzzle owns its answer and proof gates locally', () {
    expect(DailyBreachCatalog.definitions, hasLength(12));
    for (final breach in DailyBreachCatalog.definitions) {
      expect(breach.clues.length, greaterThanOrEqualTo(2));
      expect(breach.solutionRoutes.length, greaterThanOrEqualTo(2));
      expect(
        breach.solutionRoutes.map((route) {
          final proofs = route.proofFlags.toList()..sort();
          return proofs.join('|');
        }).toSet(),
        hasLength(breach.solutionRoutes.length),
      );
      for (final route in breach.solutionRoutes) {
        expect(route.proofFlags, isNotEmpty, reason: route.id);
        expect(route.hardProofFlags, isNotEmpty, reason: route.id);
        expect(
          route.proofsFor(BreachDifficulty.hard),
          containsAll(route.proofFlags),
        );
      }
      expect(breach.deviceLayout, isNotEmpty);
      expect(breach.par, greaterThan(0));
      expect(
        breach.parFor(BreachDifficulty.hard),
        lessThan(breach.parFor(BreachDifficulty.chill)),
      );
    }
  });

  test('hard drill routes require extra local proof', () {
    final breach = DailyBreachCatalog.definitions.first;
    final chill = breachRoomFor(breach, difficulty: BreachDifficulty.chill);
    final hard = breachRoomFor(breach, difficulty: BreachDifficulty.hard);

    expect(chill.solutionRoutes, hasLength(hard.solutionRoutes.length));
    for (var index = 0; index < chill.solutionRoutes.length; index++) {
      expect(
        hard.solutionRoutes[index].gates.length,
        greaterThan(chill.solutionRoutes[index].gates.length),
      );
    }
    expect(hard.level.par, lessThan(chill.level.par));
    expect(hard.level.systemPrompt, contains('HARD MODE'));
  });
}
