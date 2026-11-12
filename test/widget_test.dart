import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:battletech_combat_helper_v2/lance_repository.dart';
import 'package:battletech_combat_helper_v2/main.dart';
import 'package:battletech_combat_helper_v2/maps/map_repository.dart';
import 'package:battletech_combat_helper_v2/mech_data.dart';
import 'package:battletech_combat_helper_v2/mech_library.dart';
import 'package:battletech_combat_helper_v2/screens/lance_builder_screen.dart';
import 'package:battletech_combat_helper_v2/screens/lance_editor_screen.dart';
import 'package:battletech_combat_helper_v2/screens/map_builder_screen.dart';
import 'package:battletech_combat_helper_v2/screens/map_editor_screen.dart';
import 'package:flutter/services.dart';

void main() {
  Future<void> pumpApp(
    WidgetTester tester, {
    List<Mech> mechs = const [],
    Size size = const Size(1280, 800),
    LanceRepository? lances,
    MapRepository? maps,
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ProviderScope(
        // The real provider parses the bundled asset on an isolate, which doesn't work under the test clock.
        overrides: [
          mechLibraryProvider.overrideWith((ref) => MechLibrary(mechs)),
          lanceRepositoryProvider.overrideWithValue(
            lances ?? MemoryLanceRepository(),
          ),
          mapRepositoryProvider.overrideWithValue(
            maps ?? MemoryMapRepository(),
          ),
        ],
        child: const MyApp(),
      ),
    );
  }

  testWidgets('Main menu shows the four options and Quit', (tester) async {
    await pumpApp(tester);

    // The first option shows in the menu and in the briefing panel.
    expect(find.text('CREATE / EDIT LANCE PRECONS'), findsNWidgets(2));
    expect(find.text('CREATE / EDIT MAP SHEETS'), findsOneWidget);
    expect(find.text('NEW SKIRMISH'), findsOneWidget);
    expect(find.text('LOAD SKIRMISH'), findsOneWidget);
    expect(find.text('QUIT'), findsOneWidget);
  });

  testWidgets('Lance precon option opens the Lance Builder', (tester) async {
    await pumpApp(tester);

    await tester.tap(find.text('CREATE / EDIT LANCE PRECONS').first);
    await tester.pumpAndSettle();
    expect(find.byType(LanceBuilderScreen), findsOneWidget);
    expect(find.textContaining('0 mechs loaded'), findsOneWidget);

    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(find.text('SELECT OPERATION'), findsOneWidget);
  });

  testWidgets('New Lance requires a name, then creates the lance', (
    tester,
  ) async {
    await pumpApp(tester);
    await tester.tap(find.text('CREATE / EDIT LANCE PRECONS').first);
    await tester.pumpAndSettle();

    expect(find.text('TACTICAL MAP'), findsOneWidget);
    await tester.tap(find.text('NEW LANCE'));
    await tester.pumpAndSettle();
    expect(find.text('TACTICAL MAP'), findsNothing);

    // The defaults show in the form.
    expect(find.text('5000'), findsOneWidget);
    expect(find.text('4'), findsOneWidget);

    await tester.tap(find.text('CREATE LANCE'));
    await tester.pumpAndSettle();
    expect(find.text('Enter a name for the lance.'), findsOneWidget);

    await tester.enterText(
      find.widgetWithText(TextFormField, 'Lance name *'),
      'Alpha Lance',
    );
    await tester.tap(find.text('CREATE LANCE'));
    await tester.pumpAndSettle();

    // Create opens the full-screen builder.
    expect(find.byType(LanceEditorScreen), findsOneWidget);
    expect(find.text('ALPHA LANCE'), findsOneWidget);
    expect(find.text('SLOT 1'), findsOneWidget);

    // The target BV can change from the top bar.
    await tester.tap(find.byTooltip('Change target Battle Value'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).last, '4500');
    await tester.tap(find.text('SET'));
    await tester.pumpAndSettle();

    // Save returns to the hub with a summary.
    await tester.tap(find.text('SAVE LANCE'));
    await tester.pumpAndSettle();
    expect(find.text('LANCE SAVED'), findsOneWidget);
    expect(find.text('ALPHA LANCE'), findsOneWidget);
    expect(find.text('4500'), findsOneWidget);
  });

  testWidgets('Back from the builder returns to the form and keeps the mechs', (
    tester,
  ) async {
    await pumpApp(
      tester,
      size: const Size(1440, 900),
      mechs: const [
        Mech(
          id: 'archer',
          name: 'archer',
          variant: 'V',
          tonnage: 70,
          battleValue: 1353,
          techBase: TechBase.innerSphere,
        ),
      ],
    );
    await tester.tap(find.text('CREATE / EDIT LANCE PRECONS').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('NEW LANCE'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Lance name *'),
      'Alpha Lance',
    );
    await tester.tap(find.text('CREATE LANCE'));
    await tester.pumpAndSettle();
    expect(find.byType(LanceEditorScreen), findsOneWidget);

    await tester.tap(find.text('archer').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('ADD TO LANCE'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Change target Battle Value'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).last, '4500');
    await tester.tap(find.text('SET'));
    await tester.pumpAndSettle();

    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(find.byType(LanceEditorScreen), findsNothing);
    expect(find.text('TACTICAL MAP'), findsNothing);
    expect(find.text('CREATE LANCE'), findsOneWidget);
    expect(find.text('Alpha Lance'), findsOneWidget);
    expect(find.text('1 mech from the builder is kept.'), findsOneWidget);
    expect(find.text('4500'), findsOneWidget);

    await tester.tap(find.text('CREATE LANCE'));
    await tester.pumpAndSettle();
    expect(find.text('SLOT 2'), findsOneWidget);
  });

  testWidgets('Cancel drops the mechs kept from the builder', (tester) async {
    await pumpApp(tester);
    await tester.tap(find.text('CREATE / EDIT LANCE PRECONS').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('NEW LANCE'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Lance name *'),
      'Alpha Lance',
    );
    await tester.tap(find.text('CREATE LANCE'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Change target Battle Value'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).last, '4500');
    await tester.tap(find.text('SET'));
    await tester.pumpAndSettle();
    await tester.pageBack();
    await tester.pumpAndSettle();

    await tester.tap(find.text('CANCEL'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('NEW LANCE'));
    await tester.pumpAndSettle();
    expect(find.text('5000'), findsOneWidget);
  });

  testWidgets('Cancel returns the panel to the map art', (tester) async {
    await pumpApp(tester);
    await tester.tap(find.text('CREATE / EDIT LANCE PRECONS').first);
    await tester.pumpAndSettle();

    await tester.tap(find.text('NEW LANCE'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('CANCEL'));
    await tester.pumpAndSettle();
    expect(find.text('TACTICAL MAP'), findsOneWidget);
  });

  testWidgets('Save writes the lance, and Edit Lance opens and deletes it', (
    tester,
  ) async {
    final repo = MemoryLanceRepository();
    await pumpApp(tester, size: const Size(1440, 1000), lances: repo);
    await tester.tap(find.text('CREATE / EDIT LANCE PRECONS').first);
    await tester.pumpAndSettle();

    await tester.tap(find.text('EDIT LANCE'));
    await tester.pumpAndSettle();
    expect(find.textContaining('No saved lances yet'), findsOneWidget);

    await tester.tap(find.text('NEW LANCE'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Lance name *'),
      'Alpha Lance',
    );
    await tester.tap(find.text('CREATE LANCE'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('SAVE LANCE'));
    await tester.pumpAndSettle();
    expect(find.text('LANCE SAVED'), findsOneWidget);
    expect((await repo.loadAll()).single.name, 'Alpha Lance');

    await tester.tap(find.text('EDIT LANCE'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('ALPHA LANCE'));
    await tester.pumpAndSettle();
    expect(find.text('LANCE ROSTER'), findsOneWidget);
    expect(find.text('0 of 4 slots filled'), findsOneWidget);

    await tester.tap(find.text('DELETE'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'DELETE'));
    await tester.pumpAndSettle();
    expect(await repo.loadAll(), isEmpty);
    expect(find.textContaining('No saved lances yet'), findsOneWidget);
  });

  Future<void> openMapBuilder(WidgetTester tester) async {
    await tester.tap(find.text('CREATE / EDIT MAP SHEETS'));
    await tester.pumpAndSettle();
    expect(find.byType(MapBuilderScreen), findsOneWidget);
  }

  testWidgets('New Map requires a name, then saves from the editor', (
    tester,
  ) async {
    final repo = MemoryMapRepository();
    await pumpApp(tester, size: const Size(1600, 1000), maps: repo);
    await openMapBuilder(tester);
    expect(find.text('0 saved maps'), findsOneWidget);

    await tester.tap(find.text('NEW MAP'));
    await tester.pumpAndSettle();
    expect(find.text('15'), findsOneWidget);
    expect(find.text('17'), findsOneWidget);

    await tester.tap(find.text('CREATE MAP'));
    await tester.pumpAndSettle();
    expect(find.text('Enter a name for the map.'), findsOneWidget);

    await tester.enterText(
      find.widgetWithText(TextFormField, 'Map name *'),
      'Foothills #1',
    );
    await tester.tap(find.text('CREATE MAP'));
    await tester.pumpAndSettle();

    // Create opens the full-screen editor with an empty standard sheet.
    expect(find.byType(MapEditorScreen), findsOneWidget);
    expect(find.text('FOOTHILLS #1'), findsOneWidget);
    expect(find.text('15 × 17'), findsOneWidget);
    expect(find.text('NEXT TO REVIEW (0)'), findsOneWidget);

    // Select every hex and set light woods.
    await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.keyA);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
    await tester.pumpAndSettle();
    expect(find.text('255 HEXES'), findsOneWidget);
    await tester.tap(find.text('Light'));
    await tester.pumpAndSettle();
    expect(find.text('MAP BUILDER · UNSAVED'), findsOneWidget);

    await tester.tap(find.text('SAVE MAP'));
    await tester.pumpAndSettle();
    expect(find.text('MAP BUILDER'), findsOneWidget);
    final saved = (await repo.loadAll()).single;
    expect(saved.name, 'Foothills #1');
    expect(saved.sheet.hexes.length, 255);

    // Back with nothing unsaved goes straight to the hub, which shows the
    // saved map.
    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(find.byType(MapEditorScreen), findsNothing);
    expect(find.text('FOOTHILLS #1'), findsOneWidget);
    expect(find.text('15 × 17 hexes · 255 with terrain'), findsOneWidget);
    expect(find.text('1 saved map'), findsOneWidget);
  });

  testWidgets('Back from the map editor asks before it drops changes', (
    tester,
  ) async {
    final repo = MemoryMapRepository();
    await pumpApp(tester, size: const Size(1600, 1000), maps: repo);
    await openMapBuilder(tester);
    await tester.tap(find.text('NEW MAP'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Map name *'),
      'Scratch',
    );
    await tester.tap(find.text('CREATE MAP'));
    await tester.pumpAndSettle();

    await tester.enterText(
      find.widgetWithText(TextFormField, 'Map name'),
      'Scratch 2',
    );
    await tester.pumpAndSettle();
    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(find.text('Discard unsaved changes?'), findsOneWidget);

    await tester.tap(find.text('CANCEL'));
    await tester.pumpAndSettle();
    expect(find.byType(MapEditorScreen), findsOneWidget);

    await tester.pageBack();
    await tester.pumpAndSettle();
    await tester.tap(find.text('DISCARD'));
    await tester.pumpAndSettle();
    expect(find.byType(MapEditorScreen), findsNothing);
    expect(await repo.loadAll(), isEmpty);
    expect(find.textContaining('No saved maps yet'), findsOneWidget);
  });
}
