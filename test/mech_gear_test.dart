import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:battletech_combat_helper_v2/lance.dart';
import 'package:battletech_combat_helper_v2/location.dart';
import 'package:battletech_combat_helper_v2/mech_columns.dart';
import 'package:battletech_combat_helper_v2/mech_data.dart';
import 'package:battletech_combat_helper_v2/mech_gear.dart';
import 'package:battletech_combat_helper_v2/mech_library.dart';
import 'package:battletech_combat_helper_v2/widgets/mech_list_panel.dart';

void main() {
  const raven = Mech(
    id: 'raven',
    name: 'Raven',
    variant: 'RVN-3L',
    tonnage: 35,
    engineType: 'Fusion Engine',
    weapons: [
      Weapon(type: 'Medium Laser'),
      Weapon(type: 'ECM Suite'),
      Weapon(type: 'Narc'),
    ],
    critTable: {
      Location.leftTorso: ['CASE', 'Ammo (Narc) 6', 'Medium Pulse La'],
    },
  );
  const atlas = Mech(
    id: 'atlas',
    name: 'Atlas',
    variant: 'AS7-K',
    tonnage: 100,
    engineType: 'XL Fusion Engine',
    heatSinks: (type: HeatSinkType.dbl, count: 20),
    weapons: [
      Weapon(type: 'Gauss Rifle'),
      Weapon(type: 'Medium Laser'),
    ],
  );
  const mechs = [raven, atlas];

  List<String> ids(Iterable<Mech> list) => [for (final m in list) m.id];

  test('gear comes from weapons, known crit entries, engine, and sinks', () {
    expect(raven.gear, {
      'Medium Laser',
      'ECM Suite',
      'Narc',
      'CASE',
      'Fusion Engine',
    });
    expect(atlas.gear, contains(doubleHeatSinks));
    expect(atlas.gear, contains('XL Fusion Engine'));
  });

  test('the catalog splits weapons from equipment, with counts', () {
    final c = gearCatalog(mechs);
    expect(c.weapons, {'Gauss Rifle': 1, 'Medium Laser': 2});
    expect(c.equipment.keys, [
      'CASE',
      doubleHeatSinks,
      'ECM Suite',
      'Fusion Engine',
      'Narc',
      'XL Fusion Engine',
    ]);
  });

  test('all needs every item; any needs one', () {
    const all = GearFilter(items: {'Medium Laser', 'ECM Suite'});
    expect(ids(filterMechs(mechs, gear: all)), ['raven']);
    expect(all.describe(), 'Has all: ECM Suite, Medium Laser');

    const any = GearFilter(
      items: {'Gauss Rifle', 'ECM Suite'},
      match: GearMatch.any,
    );
    expect(ids(filterMechs(mechs, gear: any)), ['raven', 'atlas']);
    expect(ids(filterMechs(mechs, gear: GearFilter.none)), ['raven', 'atlas']);
  });

  test('the real catalog lists crit-table equipment', () {
    final real = mechsFromJsonString(
      File('assets/base_data/mechs_clean.json').readAsStringSync(),
    );
    final c = gearCatalog(real);
    for (final name in critTableEquipment) {
      expect(c.equipment, contains(name));
    }
    expect(c.equipment, contains('ECM Suite'));
    expect(c.weapons, contains('Medium Laser'));
    expect(c.weapons, isNot(contains('ECM Suite')));
  });

  testWidgets('the More filters menu opens the gear filter', (tester) async {
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
    String count(int n) => '$n of 2 mechs  ·  Orange outline: lance default';

    await tester.tap(find.text('More filters'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Weapons & equipment…'));
    await tester.pumpAndSettle();

    await tester.enterText(
      find.widgetWithText(TextField, 'Search').last,
      'ecm',
    );
    await tester.pump();
    expect(find.widgetWithText(CheckboxListTile, 'Gauss Rifle'), findsNothing);
    await tester.tap(find.widgetWithText(CheckboxListTile, 'ECM Suite'));
    await tester.enterText(find.widgetWithText(TextField, 'Search').last, '');
    await tester.pump();
    await tester.tap(find.widgetWithText(CheckboxListTile, 'Gauss Rifle'));
    await tester.tap(find.text('Has any'));
    await tester.tap(find.text('Apply'));
    await tester.pumpAndSettle();
    expect(find.text(count(2)), findsOneWidget);
    expect(find.text('Has any: ECM Suite, Gauss Rifle'), findsOneWidget);

    await tester.tap(find.text('Has any: ECM Suite, Gauss Rifle'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Has all'));
    await tester.tap(find.text('Apply'));
    await tester.pumpAndSettle();
    expect(find.text(count(0)), findsOneWidget);

    await tester.tap(find.byTooltip('Remove weapons & equipment filter'));
    await tester.pumpAndSettle();
    expect(find.text(count(2)), findsOneWidget);
  });
}
