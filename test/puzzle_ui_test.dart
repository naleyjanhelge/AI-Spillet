import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:prompt_heist/ui/prompt_heist_theme.dart';
import 'package:prompt_heist/ui/puzzle_overlays.dart';
import 'package:prompt_heist/ui/room_control_panel.dart';

Widget _host(Widget child, {Size size = const Size(430, 900)}) => MediaQuery(
  data: MediaQueryData(size: size),
  child: MaterialApp(
    theme: buildPromptHeistTheme(),
    home: Scaffold(body: child),
  ),
);

void main() {
  testWidgets('keypad returns a structured digit sequence', (tester) async {
    String? submitted;
    await tester.pumpWidget(
      _host(
        Center(
          child: SingleChildScrollView(
            child: KeypadPuzzle(onSubmit: (value) => submitted = value),
          ),
        ),
      ),
    );

    await tester.tap(find.text('4'));
    await tester.pump();
    await tester.tap(find.text('2'));
    await tester.pump();
    await tester.tap(find.text('0'));
    await tester.pump();
    await tester.tap(find.text('7'));
    await tester.pump();
    await tester.tap(find.text('Enter'));

    expect(submitted, '4207');
  });

  testWidgets('inventory puzzle returns item and target ids', (tester) async {
    InventoryUse? use;
    await tester.pumpWidget(
      _host(
        Center(
          child: InventoryUsePuzzle(
            items: const [InventoryPuzzleItem(id: 'badge', label: 'Badge')],
            targets: const [InventoryTarget(id: 'scanner', label: 'Scanner')],
            onUse: (value) => use = value,
          ),
        ),
      ),
    );

    await tester.tap(find.text('Badge'));
    await tester.pump();
    await tester.tap(find.text('Scanner'));
    await tester.pump();
    await tester.tap(find.text('Use item'));

    expect(use?.itemId, 'badge');
    expect(use?.targetId, 'scanner');
  });

  testWidgets('evidence attachment emits prompt-ready evidence', (
    tester,
  ) async {
    RoomEvidence? attached;
    await tester.pumpWidget(
      _host(
        AdaptiveRoomControlLayout(
          room: const ColoredBox(color: Colors.black),
          nox: const Center(child: Text('NOX transcript')),
          evidence: const [
            RoomEvidence(
              id: 'clause',
              title: 'Medical clause',
              description: 'Emergency care supersedes containment.',
              promptQuote: 'Policy 6: emergency care supersedes containment.',
            ),
          ],
          objective: const Text('Open the observation suite.'),
          composer: const SizedBox(height: 48),
          attachedEvidenceIds: const {},
          onEvidenceAttachmentChanged: (item, value) {
            if (value) attached = item;
          },
        ),
      ),
    );

    await tester.tap(find.text('Evidence'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Attach to prompt'));

    expect(attached?.id, 'clause');
    expect(attached?.promptQuote, contains('Policy 6'));
  });

  testWidgets('tablet layout uses a persistent sidebar', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1200, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      _host(
        AdaptiveRoomControlLayout(
          room: const ColoredBox(color: Colors.black),
          nox: const Text('NOX transcript'),
          evidence: const [],
          objective: const Text('Objective'),
          composer: const SizedBox(height: 48),
          attachedEvidenceIds: const {},
          onEvidenceAttachmentChanged: (_, _) {},
        ),
        size: const Size(1200, 800),
      ),
    );

    expect(find.byType(PersistentRoomControlPanel), findsOneWidget);
    expect(find.byType(PhoneRoomControlPanel), findsNothing);
  });
}
