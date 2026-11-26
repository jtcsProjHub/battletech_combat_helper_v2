import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:battletech_combat_helper_v2/app_theme.dart';
import 'package:battletech_combat_helper_v2/era.dart';
import 'package:battletech_combat_helper_v2/history/change_history.dart';
import 'package:battletech_combat_helper_v2/lance.dart';
import 'package:battletech_combat_helper_v2/mech_data.dart';
import 'package:battletech_combat_helper_v2/mech_library.dart';
import 'package:battletech_combat_helper_v2/pilot_data.dart';
import 'package:battletech_combat_helper_v2/widgets/skirmish/lance_balancing_roster.dart';

const _era = Era.lateSuccessionWarRenaissance;

Mech _atlas(
  String variant,
  int bv,
  List<Weapon> weapons, {
  Map<Era, List<String>> availability = const {
    _era: ['Federated Suns'],
  },
}) => Mech(
  id: 'atlas_${variant.toLowerCase()}',
  name: 'Atlas',
  variant: variant,
  tonnage: 100,
  walk: 3,
  run: 5,
  armorTotal: 304,
  structureTotal: 152,
  heatSinks: (type: HeatSinkType.single, count: 20),
  battleValue: bv,
  weapons: weapons,
  availability: availability,
);

final _d = _atlas('AS7-D', 1897, const [Weapon(type: 'AC/20')]);
final _s = _atlas('AS7-S', 2009, const [Weapon(type: 'LRM 15')]);
final _a = _atlas(
  'AS7-A',
  1747,
  const [Weapon(type: 'AC/20')],
  availability: const {
    _era: ['Draconis Combine'],
  },
);

final _library = MechLibrary([_d, _s, _a]);

final _lance = Lance(
  id: 'hammer',
  name: 'Hammer',
  parameters: const LanceParameters(era: _era, faction: 'Federated Suns'),
  slots: const [LanceSlot(mechId: 'atlas_as7-d')],
);

/// Pumps the roster in a skirmish-column-sized box. Returns the lances
/// passed to onChanged; the host keeps the latest one, like the setup
/// screen does.
Future<List<Lance>> _pump(
  WidgetTester tester, {
  ChangeHistory<Lance>? history,
}) async {
  tester.view.physicalSize = const Size(600, 1600);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  final changes = <Lance>[];
  var lance = _lance;
  await tester.pumpWidget(
    MaterialApp(
      theme: buildAppTheme(),
      home: Scaffold(
        body: Align(
          alignment: Alignment.topLeft,
          child: SizedBox(
            width: 480,
            height: 1600,
            child: StatefulBuilder(
              builder: (context, setState) => LanceBalancingRoster(
                lance: lance,
                library: _library,
                savedBattleValue: 1897,
                history: history,
                onChanged: (l) => setState(() {
                  changes.add(l);
                  lance = l;
                }),
              ),
            ),
          ),
        ),
      ),
    ),
  );
  return changes;
}

Finder _chip(String text) => find.text(text, findRichText: true);

void main() {
  testWidgets('the arrow lists variants grouped by the lance filters', (
    tester,
  ) async {
    await _pump(tester);
    expect(find.text('No changes'), findsOneWidget);
    expect(find.text('AS7-S'), findsNothing);

    await tester.tap(find.byTooltip('See variants'));
    await tester.pump();

    expect(find.text('FITS LANCE FILTERS'), findsOneWidget);
    expect(find.text('OUTSIDE LANCE FILTERS'), findsOneWidget);
    expect(
      find.textContaining('not fielded by Federated Suns'),
      findsOneWidget,
    );
    // AS7-S fits, so it comes before AS7-A despite costing more.
    expect(
      tester.getTopLeft(find.text('AS7-S')).dy,
      lessThan(tester.getTopLeft(find.text('AS7-A')).dy),
    );
    expect(_chip('1× AC/20'), findsWidgets); // the card and AS7-S's removed row
    expect(_chip('1× LRM 15'), findsOneWidget);
    expect(find.text('− REMOVED'), findsOneWidget);
    expect(find.text('+ ADDED'), findsOneWidget);
    expect(find.text('Same weapons and equipment.'), findsOneWidget); // AS7-A
  });

  testWidgets('hovering a variant previews it; tapping swaps to it', (
    tester,
  ) async {
    final changes = await _pump(tester);
    await tester.tap(find.byTooltip('See variants'));
    await tester.pump();

    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    addTearDown(mouse.removePointer);
    await mouse.addPointer(location: Offset.zero);
    await mouse.moveTo(tester.getCenter(find.text('AS7-S')));
    await tester.pump();
    expect(find.text('PREVIEW'), findsOneWidget);
    expect(find.text('2,009'), findsWidgets);

    await tester.tap(find.text('AS7-S'));
    await tester.pump();
    expect(changes.single.slots.single.mechId, 'atlas_as7-s');
    // The list stays open, now compared against AS7-S.
    expect(find.text('AS7-D'), findsWidgets);
    await mouse.moveTo(Offset.zero);
    await tester.pump();
    expect(find.text('VS SAVED LANCE'), findsOneWidget);
    expect(find.textContaining('+112 BV', findRichText: true), findsOneWidget);
  });

  testWidgets('Edit pilot closes the variants and turns into Cancel', (
    tester,
  ) async {
    final changes = await _pump(tester);
    await tester.tap(find.byTooltip('See variants'));
    await tester.pump();
    expect(find.text('AS7-S'), findsOneWidget);

    await tester.tap(find.text('EDIT PILOT'));
    await tester.pump();
    expect(find.text('AS7-S'), findsNothing);
    expect(find.text('CANCEL'), findsOneWidget);
    final save = find.widgetWithText(FilledButton, 'SAVE');
    expect(tester.widget<FilledButton>(save).onPressed, isNull);

    await tester.tap(find.byTooltip('Lower Gunnery'));
    await tester.pump();
    expect(find.text('PREVIEW'), findsOneWidget);
    expect(find.text('+379 BV'), findsOneWidget); // 1,897 × 1.20

    await tester.tap(find.text('CANCEL'));
    await tester.pump();
    expect(changes, isEmpty);
    expect(find.text('EDIT PILOT'), findsOneWidget);
    expect(find.text('PREVIEW'), findsNothing);

    // Reopening starts from the saved pilot again.
    await tester.tap(find.text('EDIT PILOT'));
    await tester.pump();
    expect(find.text('No change in BV'), findsOneWidget);
    await tester.tap(find.byTooltip('Lower Gunnery'));
    await tester.pump();
    await tester.tap(save);
    await tester.pump();

    expect(changes.single.slots.single.pilot, const Pilot(gunnery: 3));
    expect(find.text('CANCEL'), findsNothing);
    expect(
      find.textContaining('base 1,897', findRichText: true),
      findsOneWidget,
    );
  });

  testWidgets('Undo and Redo step through the kept changes', (tester) async {
    final history = ChangeHistory<Lance>();
    final changes = await _pump(tester, history: history);
    expect(find.byTooltip('Nothing to undo'), findsOneWidget);
    expect(find.byTooltip('Nothing to redo'), findsOneWidget);

    await tester.tap(find.byTooltip('See variants'));
    await tester.pump();
    await tester.tap(find.text('AS7-S'));
    await tester.pump();
    await tester.tap(find.text('EDIT PILOT'));
    await tester.pump();
    await tester.tap(find.byTooltip('Lower Gunnery'));
    await tester.pump();
    await tester.tap(find.widgetWithText(FilledButton, 'SAVE'));
    await tester.pump();
    expect(history.entries.map((c) => c.label), [
      'Atlas AS7-D → AS7-S',
      'Atlas AS7-S pilot 4/5 → 3/5',
    ]);

    await tester.tap(find.byTooltip('Undo: Atlas AS7-S pilot 4/5 → 3/5'));
    await tester.pump();
    expect(changes.last.slots.single.mechId, 'atlas_as7-s');
    expect(changes.last.slots.single.pilot, const Pilot());

    await tester.tap(find.byTooltip('Undo: Atlas AS7-D → AS7-S'));
    await tester.pump();
    expect(changes.last.slots.single.mechId, 'atlas_as7-d');
    expect(find.text('No changes'), findsOneWidget);

    await tester.tap(find.byTooltip('Redo: Atlas AS7-D → AS7-S'));
    await tester.pump();
    expect(changes.last.slots.single.mechId, 'atlas_as7-s');
    expect(find.byTooltip('Redo: Atlas AS7-S pilot 4/5 → 3/5'), findsOneWidget);
  });
}
