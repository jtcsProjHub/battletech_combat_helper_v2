import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:battletech_combat_helper_v2/era.dart';
import 'package:battletech_combat_helper_v2/lance.dart';
import 'package:battletech_combat_helper_v2/lance_draft.dart';
import 'package:battletech_combat_helper_v2/mech_columns.dart';
import 'package:battletech_combat_helper_v2/mech_data.dart';
import 'package:battletech_combat_helper_v2/mech_library.dart';
import 'package:battletech_combat_helper_v2/screens/lance_editor_screen.dart';

Mech _mech(
  String id, {
  double tons = 50,
  int bv = 1000,
  TechBase tech = TechBase.innerSphere,
  Map<Era, List<String>> availability = const {},
}) => Mech(
  id: id,
  name: id,
  variant: 'V',
  tonnage: tons,
  battleValue: bv,
  techBase: tech,
  availability: availability,
);

void main() {
  final library = MechLibrary([
    _mech(
      'thunderbolt',
      tons: 65,
      bv: 1335,
      availability: {
        Era.clanInvasion: ['Federated Commonwealth'],
      },
    ),
    _mech(
      'wolverine',
      tons: 55,
      bv: 1101,
      availability: {
        Era.clanInvasion: ['Draconis Combine'],
      },
    ),
    _mech('archer', tons: 70, bv: 1353),
    _mech('kitfox', tons: 30, bv: 1200, tech: TechBase.clan),
  ]);

  group('LanceDraft', () {
    LanceDraft draft({int maxMechs = 2, int target = 3000}) => LanceDraft(
      Lance.create(
        name: 'Alpha',
        parameters: LanceParameters(
          maxMechs: maxMechs,
          targetBattleValue: target,
        ),
      ),
      library,
    );

    test('adds mechs and computes totals', () {
      final d = draft();
      d.add(library.byId('thunderbolt')!);
      expect(d.usedBattleValue, 1335);
      expect(d.tonnage, 65);
      expect(d.remainingBattleValue, 1665);
      expect(d.openSlots, 1);
      expect(d.battleValuePerOpenSlot, 1665);
    });

    test('rejects duplicates and adds past the max', () {
      final d = draft();
      final tb = library.byId('thunderbolt')!;
      d.add(tb);
      d.add(tb);
      expect(d.mechs.length, 1);
      d.add(library.byId('wolverine')!);
      d.add(library.byId('archer')!);
      expect(d.mechs.map((m) => m.id), ['thunderbolt', 'wolverine']);
      expect(d.isFull, isTrue);
    });

    test('remove frees the slot and notifies', () {
      final d = draft();
      var calls = 0;
      d.addListener(() => calls++);
      d.add(library.byId('archer')!);
      d.remove('archer');
      expect(d.mechs, isEmpty);
      expect(calls, 2);
    });

    test('over budget is flagged', () {
      final d = draft(target: 2000);
      d.add(library.byId('thunderbolt')!);
      d.add(library.byId('archer')!);
      expect(d.isOverBudget, isTrue);
      expect(d.remainingBattleValue, -688);
    });

    test('target battle value can change, keeping the mechs', () {
      final d = draft(target: 2000);
      var calls = 0;
      d.addListener(() => calls++);
      d.add(library.byId('thunderbolt')!);
      d.add(library.byId('archer')!);
      d.setTargetBattleValue(3000);
      expect(d.isOverBudget, isFalse);
      expect(d.remainingBattleValue, 312);
      expect(d.mechs.length, 2);
      expect(d.parameters.maxMechs, 2);
      d.setTargetBattleValue(0);
      d.setTargetBattleValue(3000);
      expect(d.parameters.targetBattleValue, 3000);
      expect(calls, 3);
    });
  });

  group('filterMechs', () {
    test('era and faction use availability', () {
      final ids = filterMechs(
        library.mechs,
        era: Era.clanInvasion,
        faction: 'Federated Commonwealth',
      ).map((m) => m.id);
      expect(ids, ['thunderbolt']);
    });

    test('faction without era matches any era', () {
      final ids = filterMechs(
        library.mechs,
        faction: 'Draconis Combine',
      ).map((m) => m.id);
      expect(ids, ['wolverine']);
    });

    test('tech base, weight class, and search', () {
      expect(
        filterMechs(library.mechs, techBase: TechBase.clan).map((m) => m.id),
        ['kitfox'],
      );
      expect(
        filterMechs(
          library.mechs,
          weightClass: WeightClass.heavy,
        ).map((m) => m.id),
        ['thunderbolt', 'archer'],
      );
      expect(filterMechs(library.mechs, query: 'WOLV').map((m) => m.id), [
        'wolverine',
      ]);
    });
  });

  test('MechColumn text and sort values', () {
    final tb = library.byId('thunderbolt')!;
    expect(MechColumn.battleValue.text(tb), '1335');
    expect(MechColumn.weightClass.text(tb), 'Heavy');
    expect(
      MechColumn.tons
          .sortValue(tb)
          .compareTo(MechColumn.tons.sortValue(library.byId('archer')!)),
      lessThan(0),
    );
  });

  testWidgets('Builder adds a mech from the preview and removes it', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1440, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MaterialApp(
        home: LanceEditorScreen(
          lance: Lance.create(
            name: 'Alpha',
            parameters: const LanceParameters(targetBattleValue: 5000),
          ),
          library: library,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.text('4 of 4 mechs  ·  Orange outline: lance default'),
      findsOneWidget,
    );
    await tester.tap(find.text('archer').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('ADD TO LANCE'));
    await tester.pumpAndSettle();

    expect(find.text('IN LANCE'), findsWidgets);
    expect(find.text('1353'), findsWidgets);
    expect(find.text('SLOT 2'), findsOneWidget);

    await tester.tap(find.byTooltip('Remove archer V'));
    await tester.pumpAndSettle();
    expect(find.text('SLOT 1'), findsOneWidget);
  });

  testWidgets('Sorting by each column fits the arrow in the header', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1440, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MaterialApp(
        home: LanceEditorScreen(
          lance: Lance.create(
            name: 'Alpha',
            parameters: const LanceParameters(targetBattleValue: 5000),
          ),
          library: library,
        ),
      ),
    );
    await tester.pumpAndSettle();

    // A header overflow is reported as a test failure.
    for (final c in MechColumn.defaults) {
      final header = find.text(c.label.toUpperCase());
      await tester.ensureVisible(header);
      for (var i = 0; i < 2; i++) {
        await tester.tap(header);
        await tester.pumpAndSettle();
      }
    }
  });
}
