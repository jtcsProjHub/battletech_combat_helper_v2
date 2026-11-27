import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:battletech_combat_helper_v2/maps/map_model.dart';

import 'package:battletech_combat_helper_v2/maps/map_repository.dart';
import 'package:battletech_combat_helper_v2/screens/skirmish_map_editor_screen.dart';
import 'package:battletech_combat_helper_v2/skirmish/skirmish_map.dart';

void main() {
  const hill = HexCoord(2, 2);
  SkirmishMap fresh() => SkirmishMap(
    SavedMap(
      id: 'm',
      sheet: MapSheet(
        name: 'Hills',
        grid: const GridSpec(columns: 2, rows: 2),
        hexes: {hill: const HexTerrain(level: 2)},
      ),
    ),
  );

  late SkirmishMap map;
  Map<HexCoord, HexOverlay>? result;
  var returned = false;

  Future<void> pumpEditor(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1600, 1000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    map = fresh();
    result = null;
    returned = false;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: TextButton(
                onPressed: () async {
                  result = await SkirmishMapEditorScreen.open(context, map);
                  returned = true;
                },
                child: const Text('OPEN'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('OPEN'));
    await tester.pumpAndSettle();
    expect(find.byType(SkirmishMapEditorScreen), findsOneWidget);
  }

  Future<void> ctrl(WidgetTester tester, LogicalKeyboardKey key) async {
    await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
    await tester.sendKeyEvent(key);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
    await tester.pumpAndSettle();
  }

  Future<void> key(WidgetTester tester, LogicalKeyboardKey key) async {
    await tester.sendKeyEvent(key);
    await tester.pumpAndSettle();
  }

  Text stat(WidgetTester tester, String label) => tester.widget<Text>(
    find
        .descendant(
          of: find.ancestor(
            of: find.text(label),
            matching: find.byType(Column),
          ),
          matching: find.byType(Text),
        )
        .last,
  );

  testWidgets('sets one absolute level on the selection, with undo', (
    tester,
  ) async {
    await pumpEditor(tester);
    expect(find.textContaining('Select hexes'), findsOneWidget);

    await ctrl(tester, LogicalKeyboardKey.keyA);
    expect(find.text('4 HEXES'), findsOneWidget);
    expect(find.text('LEVEL (MIXED)'), findsOneWidget);

    // Every hex gets the same level, stepped from the primary hex (the
    // first one, at level 0). The hill drops from 2 to 1.
    await key(tester, LogicalKeyboardKey.equal);
    expect(find.text('LEVEL (MIXED)'), findsNothing);
    expect(stat(tester, 'CHANGED HEXES').data, '4');
    expect(map.overlay, isEmpty, reason: 'the editor works on a copy');

    await ctrl(tester, LogicalKeyboardKey.keyZ);
    expect(stat(tester, 'CHANGED HEXES').data, '0');
    expect(find.text('LEVEL (MIXED)'), findsOneWidget);

    await ctrl(tester, LogicalKeyboardKey.keyY);
    expect(stat(tester, 'CHANGED HEXES').data, '4');

    await tester.tap(find.text('DONE'));
    await tester.pumpAndSettle();
    expect(returned, isTrue);
    final applied = fresh()..restoreOverlay(result!);
    for (final h in applied.grid.allHexes) {
      expect(applied.terrainAt(h).level, 1);
    }
  });

  testWidgets('a building locks level and terrain until removed', (
    tester,
  ) async {
    await pumpEditor(tester);
    await ctrl(tester, LogicalKeyboardKey.keyA);

    await tester.tap(find.text('Building'));
    await tester.pumpAndSettle();
    expect(stat(tester, 'BUILDINGS').data, '4');
    expect(find.text('A building stands on level 0 ground.'), findsOneWidget);
    final up = find.ancestor(
      of: find.byTooltip('Increase Level'),
      matching: find.byType(IconButton),
    );
    expect(tester.widget<IconButton>(up).onPressed, isNull);

    // Delete resets the selection to printed.
    await key(tester, LogicalKeyboardKey.delete);
    expect(stat(tester, 'BUILDINGS').data, '0');
    expect(stat(tester, 'CHANGED HEXES').data, '0');
  });

  testWidgets('building height has its own stepper and keyboard steps', (
    tester,
  ) async {
    await pumpEditor(tester);
    await ctrl(tester, LogicalKeyboardKey.keyA);
    expect(find.text('BUILDING HEIGHT'), findsNothing);

    await tester.tap(find.text('Building'));
    await tester.pumpAndSettle();
    expect(find.text('BUILDING HEIGHT'), findsOneWidget);

    // With only buildings selected, + steps the height, not the level.
    await key(tester, LogicalKeyboardKey.equal);
    await key(tester, LogicalKeyboardKey.equal);
    await tester.tap(
      find.ancestor(
        of: find.byTooltip('Decrease Building height'),
        matching: find.byType(IconButton),
      ),
    );
    await tester.pumpAndSettle();

    await ctrl(tester, LogicalKeyboardKey.keyZ);
    await tester.tap(find.text('DONE'));
    await tester.pumpAndSettle();
    final applied = fresh()..restoreOverlay(result!);
    for (final h in applied.grid.allHexes) {
      expect(applied.buildingHeightAt(h), 3);
      expect(applied.terrainAt(h).level, 0);
    }
  });

  testWidgets('back with changes asks before discarding', (tester) async {
    await pumpEditor(tester);
    await ctrl(tester, LogicalKeyboardKey.keyA);
    await tester.tap(find.text('Building'));
    await tester.pumpAndSettle();

    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(find.text('Discard map changes?'), findsOneWidget);
    await tester.tap(find.text('CANCEL'));
    await tester.pumpAndSettle();
    expect(find.byType(SkirmishMapEditorScreen), findsOneWidget);

    await tester.pageBack();
    await tester.pumpAndSettle();
    await tester.tap(find.text('DISCARD'));
    await tester.pumpAndSettle();
    expect(returned, isTrue);
    expect(result, isNull);
    expect(map.overlay, isEmpty);
  });
}
