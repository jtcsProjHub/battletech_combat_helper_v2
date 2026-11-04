import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:battletech_combat_helper_v2/app_theme.dart';
import 'package:battletech_combat_helper_v2/lance.dart';
import 'package:battletech_combat_helper_v2/mech_data.dart';
import 'package:battletech_combat_helper_v2/mech_library.dart';
import 'package:battletech_combat_helper_v2/pilot_data.dart';
import 'package:battletech_combat_helper_v2/widgets/lance_roster_detail.dart';

// The example lance from docs/design/lance_roster_detail.md.
const _thunderbolt = Mech(
  id: 'thunderbolt_tdr_5s',
  name: 'Thunderbolt',
  variant: 'TDR-5S',
  tonnage: 65,
  role: Role.brawler,
  walk: 4,
  run: 6,
  jump: 0,
  armorTotal: 208,
  structureTotal: 104,
  heatSinks: (type: HeatSinkType.single, count: 15),
  battleValue: 1335,
  techBase: TechBase.innerSphere,
  weapons: [
    Weapon(type: 'Large Laser', location: 'RT'),
    Weapon(type: 'Medium Laser', location: 'LT', quantity: 2),
    Weapon(type: 'Medium Laser', location: 'RA'),
    Weapon(type: 'LRM 15', location: 'LT'),
  ],
);

const _wolverine = Mech(
  id: 'wolverine_wvr_6r',
  name: 'Wolverine',
  variant: 'WVR-6R',
  tonnage: 55,
  role: Role.skirmisher,
  walk: 5,
  run: 8,
  jump: 5,
  armorTotal: 152,
  structureTotal: 91,
  heatSinks: (type: HeatSinkType.single, count: 12),
  battleValue: 1101,
  techBase: TechBase.innerSphere,
);

final _library = MechLibrary(const [_thunderbolt, _wolverine]);

Lance _lance({
  List<String> mechIds = const ['thunderbolt_tdr_5s', 'wolverine_wvr_6r'],
  int target = 5000,
  int maxMechs = 4,
  Map<String, Pilot> pilots = const {},
}) => Lance(
  id: 'alpha',
  name: 'Alpha Lance',
  parameters: LanceParameters(
    targetBattleValue: target,
    maxMechs: maxMechs,
    techBase: TechBase.innerSphere,
  ),
  slots: [
    for (final id in mechIds)
      LanceSlot(mechId: id, pilot: pilots[id] ?? const Pilot()),
  ],
);

Future<void> _pump(WidgetTester tester, LanceRosterDetail detail) async {
  tester.view.physicalSize = const Size(800, 1400);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: SingleChildScrollView(child: SizedBox(width: 680, child: detail)),
      ),
    ),
  );
}

void main() {
  testWidgets('read-only shows the name, totals, and a card per mech', (
    tester,
  ) async {
    await _pump(tester, LanceRosterDetail(lance: _lance(), library: _library));

    expect(find.text('ALPHA LANCE'), findsOneWidget);
    expect(
      find.text('Era: Any · Faction: Any · Tech: Inner Sphere'),
      findsOneWidget,
    );
    expect(find.text('2,436'), findsOneWidget);
    expect(find.text(' / 5,000'), findsOneWidget);
    expect(find.text('120'), findsOneWidget);
    expect(find.text(' / 4'), findsOneWidget);

    expect(find.text('THUNDERBOLT'), findsOneWidget);
    expect(find.text('WOLVERINE'), findsOneWidget);
    expect(find.text('65 t · Heavy'), findsOneWidget);
    expect(find.text('4/6/0'), findsOneWidget);
    expect(find.text('15 SHS'), findsOneWidget);
    // Medium lasers from two locations are one chip.
    expect(find.text('3× Medium Laser', findRichText: true), findsOneWidget);

    expect(find.byIcon(Icons.close), findsNothing);
    expect(find.textContaining('ADD MECH'), findsNothing);
    expect(find.text('2 of 4 slots filled'), findsOneWidget);
  });

  testWidgets('editable shows remove buttons and the open slots', (
    tester,
  ) async {
    final removed = <String>[];
    await _pump(
      tester,
      LanceRosterDetail(
        lance: _lance(),
        library: _library,
        editable: true,
        onRemove: removed.add,
      ),
    );

    expect(find.text('REMAINING SLOTS'), findsOneWidget);
    expect(
      find.text('2,564 BV left · about 1,282 BV per slot', findRichText: true),
      findsOneWidget,
    );
    expect(find.text('+ ADD MECH · SLOT 3'), findsOneWidget);
    expect(find.text('+ ADD MECH · SLOT 4'), findsOneWidget);

    await tester.tap(find.byTooltip('Remove Wolverine WVR-6R'));
    expect(removed, ['wolverine_wvr_6r']);
  });

  testWidgets('a tap on a card calls onSelect with that mech', (tester) async {
    Mech? selected;
    await _pump(
      tester,
      LanceRosterDetail(
        lance: _lance(),
        library: _library,
        onSelect: (m) => selected = m,
      ),
    );

    await tester.tap(find.text('WOLVERINE'));
    expect(selected?.id, 'wolverine_wvr_6r');
  });

  testWidgets('a slot with an unknown mech id is skipped', (tester) async {
    await _pump(
      tester,
      LanceRosterDetail(
        lance: _lance(mechIds: ['thunderbolt_tdr_5s', 'not_a_mech']),
        library: _library,
      ),
    );

    expect(tester.takeException(), isNull);
    expect(find.text('THUNDERBOLT'), findsOneWidget);
    expect(find.text('1,335'), findsOneWidget); // the header total
    expect(find.text('1 of 4 slots filled'), findsOneWidget);
  });

  testWidgets('an over-target lance shows its BV in red', (tester) async {
    await _pump(
      tester,
      LanceRosterDetail(
        lance: _lance(target: 2000, maxMechs: 2),
        library: _library,
      ),
    );

    final used = tester.widget<Text>(find.text('2,436'));
    expect(used.style?.color, AppColors.overBudget);
    final note = tester.widget<Text>(
      find.text('Lance is full. 436 BV over the target.'),
    );
    expect(note.style?.color, AppColors.overBudget);
  });

  testWidgets('a full lance under the target says how much BV is left', (
    tester,
  ) async {
    await _pump(
      tester,
      LanceRosterDetail(lance: _lance(maxMechs: 2), library: _library),
    );

    final used = tester.widget<Text>(find.text('2,436'));
    expect(used.style?.color, AppColors.accent);
    expect(
      find.text('Lance is full. 2,564 BV left under the target.'),
      findsOneWidget,
    );
  });

  testWidgets('cards show the assigned pilot, or no pilot at the standard '
      'skills', (tester) async {
    await _pump(
      tester,
      LanceRosterDetail(
        lance: _lance(
          pilots: {
            'thunderbolt_tdr_5s': const Pilot(
              name: 'Trixie Cottonwood',
              gunnery: 3,
              piloting: 4,
            ),
          },
        ),
        library: _library,
      ),
    );

    expect(find.text('Trixie Cottonwood'), findsOneWidget);
    // Her 3/4 skills raise the Thunderbolt from 1,335 to 1,762 BV.
    expect(find.text('2,863'), findsOneWidget);
    expect(
      find.text('1,762 BV\nbase 1,335', findRichText: true),
      findsOneWidget,
    );
    expect(find.text('×1.32 BV '), findsOneWidget);
    expect(find.byTooltip('Gunnery 3'), findsOneWidget);
    expect(find.byTooltip('Piloting 4'), findsOneWidget);
    expect(find.text('No pilot'), findsOneWidget);
    expect(find.byTooltip('Gunnery 4'), findsOneWidget);
    // Read-only: nothing to tap.
    expect(find.text('PILOT'), findsNothing);
    expect(find.byTooltip('Edit pilot'), findsNothing);
  });

  testWidgets('editable cards call onEditPilot with the mech id', (
    tester,
  ) async {
    final edited = <String>[];
    await _pump(
      tester,
      LanceRosterDetail(
        lance: _lance(),
        library: _library,
        editable: true,
        onEditPilot: edited.add,
      ),
    );

    await tester.tap(find.text('PILOT').last);
    expect(edited, ['wolverine_wvr_6r']);
  });
}
