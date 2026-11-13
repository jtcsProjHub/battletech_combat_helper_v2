import 'package:flutter/gestures.dart' show kSecondaryButton;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:battletech_combat_helper_v2/lance.dart';
import 'package:battletech_combat_helper_v2/mech_columns.dart';
import 'package:battletech_combat_helper_v2/mech_data.dart';
import 'package:battletech_combat_helper_v2/mech_library.dart';
import 'package:battletech_combat_helper_v2/widgets/mech_list_panel.dart';

void main() {
  const mechs = [
    Mech(
      id: 'locust',
      name: 'Locust',
      variant: 'LCT-1V',
      tonnage: 20,
      battleValue: 432,
      role: Role.scout,
      walk: 8,
      run: 12,
    ),
    Mech(
      id: 'wolverine',
      name: 'Wolverine',
      variant: 'WVR-6R',
      tonnage: 55,
      battleValue: 1101,
      role: Role.skirmisher,
      walk: 5,
      run: 8,
      jump: 5,
    ),
    Mech(
      id: 'archer',
      name: 'Archer',
      variant: 'ARC-2R',
      tonnage: 70,
      battleValue: 1353,
      role: Role.missileBoat,
      walk: 4,
      run: 6,
    ),
  ];

  List<String> ids(Iterable<Mech> list) => [for (final m in list) m.id];

  group('ColumnFilter', () {
    test('a checklist keeps mechs with any checked value', () {
      const f = ColumnFilter(values: {'Scout', 'Missile Boat'});
      expect(ids(filterMechs(mechs, columnFilters: {MechColumn.role: f})), [
        'locust',
        'archer',
      ]);
      expect(f.describe(MechColumn.role), 'Role: Missile Boat, Scout');
    });

    test('ranges are inclusive, open-ended, and all must match', () {
      const f = ColumnFilter(
        ranges: {'Walk': (min: 5, max: null), 'Jump': (min: 1, max: 5)},
      );
      expect(ids(filterMechs(mechs, columnFilters: {MechColumn.move: f})), [
        'wolverine',
      ]);
      expect(f.describe(MechColumn.move), 'Walk ≥ 5 · Jump 1–5');
      expect(
        const ColumnFilter(
          ranges: {'BV': (min: null, max: 1101)},
        ).describe(MechColumn.battleValue),
        'BV ≤ 1101',
      );
    });

    test('filters on different columns combine with weight classes', () {
      expect(
        ids(
          filterMechs(
            mechs,
            weightClasses: {WeightClass.light, WeightClass.heavy},
            columnFilters: {
              MechColumn.battleValue: const ColumnFilter(
                ranges: {'BV': (min: 1000, max: null)},
              ),
            },
          ),
        ),
        ['archer'],
      );
    });

    test('empty filters count as empty', () {
      expect(ColumnFilter.none.isEmpty, isTrue);
      expect(
        const ColumnFilter(ranges: {'BV': (min: null, max: null)}).isEmpty,
        isTrue,
      );
    });

    test('only Role, and the numeric columns, are filterable', () {
      expect(
        MechColumn.filterableColumns,
        isNot(contains(MechColumn.weightClass)),
      );
      expect(
        MechColumn.filterableColumns,
        isNot(contains(MechColumn.techBase)),
      );
      expect(MechColumn.filterableColumns, contains(MechColumn.role));
      expect(MechColumn.filterableColumns, contains(MechColumn.move));
    });
  });

  group('MechListPanel', () {
    Future<void> pumpPanel(WidgetTester tester) async {
      tester.view.physicalSize = const Size(1400, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: MechListPanel(
              library: MechLibrary(mechs),
              defaults: const LanceParameters(),
              selectedId: null,
              onSelect: (_) {},
              isInLance: (_) => false,
              remainingBattleValue: 5000,
            ),
          ),
        ),
      );
    }

    String countText(int n) =>
        '$n of 3 mechs  ·  Orange outline: lance default';

    testWidgets('the Role header filter narrows the list and shows a chip', (
      tester,
    ) async {
      await pumpPanel(tester);
      expect(find.text(countText(3)), findsOneWidget);

      await tester.tap(find.text('ROLE'), buttons: kSecondaryButton);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Filter…'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(CheckboxListTile, 'Scout'));
      await tester.tap(find.widgetWithText(CheckboxListTile, 'Skirmisher'));
      await tester.tap(find.text('Apply'));
      await tester.pumpAndSettle();

      expect(find.text(countText(2)), findsOneWidget);
      expect(find.text('Role: Scout, Skirmisher'), findsOneWidget);

      // The chip's delete button still removes it.
      await tester.tap(find.byTooltip('Remove Role filter'));
      await tester.pumpAndSettle();
      expect(find.text(countText(3)), findsOneWidget);

      // With a filter set, the menu offers Clear filter.
      await tester.tap(find.text('ROLE'), buttons: kSecondaryButton);
      await tester.pumpAndSettle();
      expect(find.text('Clear filter'), findsNothing);
      await tester.tap(find.text('Filter…'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(CheckboxListTile, 'Scout'));
      await tester.tap(find.text('Apply'));
      await tester.pumpAndSettle();
      expect(find.text(countText(1)), findsOneWidget);

      await tester.tap(find.text('ROLE'), buttons: kSecondaryButton);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Clear filter'));
      await tester.pumpAndSettle();
      expect(find.text(countText(3)), findsOneWidget);
    });

    testWidgets('right-click sorts either way', (tester) async {
      await pumpPanel(tester);
      List<String> order() =>
          [
            for (final name in ['Locust', 'Wolverine', 'Archer']) name,
          ]..sort(
            (a, b) => tester
                .getTopLeft(find.text(a))
                .dy
                .compareTo(tester.getTopLeft(find.text(b)).dy),
          );

      await tester.tap(find.text('TONS'), buttons: kSecondaryButton);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Sort ascending'));
      await tester.pumpAndSettle();
      expect(order(), ['Locust', 'Wolverine', 'Archer']);

      await tester.tap(find.text('TONS'), buttons: kSecondaryButton);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Sort descending'));
      await tester.pumpAndSettle();
      expect(order(), ['Archer', 'Wolverine', 'Locust']);
    });

    testWidgets('the menu reaches hidden columns, with min/max ranges', (
      tester,
    ) async {
      await pumpPanel(tester);
      // Intro is not a default column.
      expect(find.text('INTRO'), findsNothing);

      await tester.tap(find.text('Column filters'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(MenuItemButton, 'Move'));
      await tester.pumpAndSettle();

      final walkMin = find.widgetWithText(TextField, 'Min').first;
      final walkMax = find.widgetWithText(TextField, 'Max').first;
      await tester.enterText(walkMin, '6');
      await tester.enterText(walkMax, '5');
      await tester.pump();
      expect(find.text('Min must not be above Max.'), findsOneWidget);

      await tester.enterText(walkMax, '');
      await tester.pump();
      await tester.tap(find.text('Apply'));
      await tester.pumpAndSettle();
      expect(find.text(countText(1)), findsOneWidget);
      expect(find.text('Walk ≥ 6'), findsOneWidget);

      // Reset filters clears column filters too.
      await tester.tap(find.text('Reset filters'));
      await tester.pumpAndSettle();
      expect(find.text(countText(3)), findsOneWidget);
      expect(find.text('Walk ≥ 6'), findsNothing);
    });

    testWidgets('weight class chips combine', (tester) async {
      await pumpPanel(tester);
      await tester.tap(find.widgetWithText(FilterChip, 'Light'));
      await tester.pumpAndSettle();
      expect(find.text(countText(1)), findsOneWidget);
      await tester.tap(find.widgetWithText(FilterChip, 'Heavy'));
      await tester.pumpAndSettle();
      expect(find.text(countText(2)), findsOneWidget);
      await tester.tap(find.widgetWithText(FilterChip, 'All classes'));
      await tester.pumpAndSettle();
      expect(find.text(countText(3)), findsOneWidget);
    });
  });
}
