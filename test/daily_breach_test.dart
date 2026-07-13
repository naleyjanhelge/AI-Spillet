import 'package:flutter_test/flutter_test.dart';
import 'package:prompt_heist/game/daily_breach.dart';

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
    expect(DailyBreachCatalog.definitions, isNotEmpty);
    for (final breach in DailyBreachCatalog.definitions) {
      expect(breach.clues.length, greaterThanOrEqualTo(2));
      expect(breach.solutionRoutes.length, greaterThanOrEqualTo(2));
      expect(breach.requiredProofFlags, isNotEmpty);
      expect(breach.deviceLayout, isNotEmpty);
      expect(breach.par, greaterThan(0));
    }
  });
}
