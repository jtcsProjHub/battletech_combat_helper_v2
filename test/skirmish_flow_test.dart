import 'package:flutter/gestures.dart' show kDoubleTapMinTime;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:map_extractor_prototype/map_extractor.dart';

import 'package:battletech_combat_helper_v2/lance.dart';
import 'package:battletech_combat_helper_v2/lance_repository.dart';
import 'package:battletech_combat_helper_v2/location.dart';
import 'package:battletech_combat_helper_v2/main.dart';
import 'package:battletech_combat_helper_v2/maps/map_repository.dart';
import 'package:battletech_combat_helper_v2/mech_data.dart';
import 'package:battletech_combat_helper_v2/mech_library.dart';
import 'package:battletech_combat_helper_v2/screens/load_skirmish_screen.dart';
import 'package:battletech_combat_helper_v2/screens/skirmish_play_screen.dart';
import 'package:battletech_combat_helper_v2/screens/skirmish_setup_screen.dart';
import 'package:battletech_combat_helper_v2/skirmish/skirmish_repository.dart';

void main() {
  const mechs = [
    Mech(
      id: 'archer',
      name: 'Archer',
      variant: 'ARC-2R',
      tonnage: 70,
      battleValue: 1353,
      techBase: TechBase.innerSphere,
      armorTotal: 30,
      armorByLocation: {Location.head: 9, Location.centerTorso: 21},
      structureTotal: 25,
      structureByLocation: {Location.head: 3, Location.centerTorso: 22},
    ),
  ];

  late MemorySkirmishRepository skirmishes;

  Future<void> pumpApp(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1600, 1000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    skirmishes = MemorySkirmishRepository();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          mechLibraryProvider.overrideWith((ref) => MechLibrary(mechs)),
          lanceRepositoryProvider.overrideWithValue(
            MemoryLanceRepository([
              for (final name in ['Alpha', 'Bravo'])
                Lance(
                  id: name.toLowerCase(),
                  name: name,
                  slots: const [LanceSlot(mechId: 'archer')],
                ),
            ]),
          ),
          mapRepositoryProvider.overrideWithValue(
            MemoryMapRepository([
              SavedMap(
                id: 'hills',
                sheet: MapSheet(
                  name: 'Hills',
                  grid: const GridSpec(columns: 3, rows: 3),
                  hexes: const {},
                ),
              ),
            ]),
          ),
          skirmishRepositoryProvider.overrideWithValue(skirmishes),
        ],
        child: const MyApp(),
      ),
    );
  }

  Future<void> tapText(WidgetTester tester, String text) async {
    await tester.tap(find.text(text).first);
    await tester.pumpAndSettle();
  }

  FilledButton filledButton(WidgetTester tester, String label) =>
      tester.widget<FilledButton>(find.widgetWithText(FilledButton, label));

  Future<void> openNewSkirmish(WidgetTester tester) async {
    await tester.tap(find.text('NEW SKIRMISH').first);
    await tester.pumpAndSettle();
    expect(find.byType(SkirmishSetupScreen), findsOneWidget);
  }

  testWidgets('picks both lances and a map, then confirms into play', (
    tester,
  ) async {
    await pumpApp(tester);
    await openNewSkirmish(tester);

    expect(find.text('NEW SKIRMISH · PLAYER 1 LANCE'), findsOneWidget);
    expect(find.textContaining('SKIRMISH 20'), findsOneWidget);
    expect(filledButton(tester, 'NEXT: PLAYER 2').onPressed, isNull);

    // Picking a lance shows it in the preview with the builder's roster.
    await tapText(tester, 'ALPHA');
    expect(find.text('LANCE ROSTER'), findsOneWidget);
    await tapText(tester, 'NEXT: PLAYER 2');

    expect(find.text('NEW SKIRMISH · PLAYER 2 LANCE'), findsOneWidget);
    await tester.tap(find.text('BRAVO').last);
    await tester.pumpAndSettle();
    await tapText(tester, 'NEXT: MAP');

    expect(filledButton(tester, 'NEXT: REVIEW').onPressed, isNull);
    await tapText(tester, 'HILLS');
    await tapText(tester, 'NEXT: REVIEW');
    expect(find.text('ALPHA  VS  BRAVO'), findsOneWidget);

    await tapText(tester, 'CONFIRM & START');
    expect(find.byType(SkirmishPlayScreen), findsOneWidget);
    expect(find.text('SKIRMISH · TURN 1'), findsOneWidget);
    expect(find.text('ARCHER ARC-2R'), findsNWidgets(2));

    final saved = (await skirmishes.loadAll()).single;
    expect(saved.isActive, isTrue);
    expect(saved.player1.units.single.armorLeft, 30);

    // Back asks first, then returns to the main menu.
    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(find.text('Leave the skirmish?'), findsOneWidget);
    await tapText(tester, 'STAY');
    expect(find.byType(SkirmishPlayScreen), findsOneWidget);

    await tester.pageBack();
    await tester.pumpAndSettle();
    await tapText(tester, 'LEAVE');
    expect(find.text('SELECT OPERATION'), findsOneWidget);
  });

  testWidgets('back saves a started setup, but not an empty one', (
    tester,
  ) async {
    await pumpApp(tester);
    await openNewSkirmish(tester);
    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(find.text('SELECT OPERATION'), findsOneWidget);
    expect(await skirmishes.loadAll(), isEmpty);

    await openNewSkirmish(tester);
    await tapText(tester, 'ALPHA');
    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(find.text('SELECT OPERATION'), findsOneWidget);
    final saved = (await skirmishes.loadAll()).single;
    expect(saved.isActive, isFalse);
    expect(saved.player1.lance!.name, 'Alpha');
  });

  testWidgets('double-click renames the skirmish; cancel keeps the name', (
    tester,
  ) async {
    await pumpApp(tester);
    await openNewSkirmish(tester);
    final title = find.textContaining('SKIRMISH 20');

    Future<void> doubleTap(Finder f) async {
      await tester.tap(f);
      await tester.pump(kDoubleTapMinTime);
      await tester.tap(f);
      await tester.pumpAndSettle();
    }

    await doubleTap(title);
    await tester.enterText(find.byType(TextField), 'Grudge Match');
    await tester.tap(find.byTooltip('Cancel rename'));
    await tester.pumpAndSettle();
    expect(title, findsOneWidget);

    await doubleTap(title);
    await tester.enterText(find.byType(TextField), '   ');
    await tester.pump();
    final check = tester.widget<IconButton>(
      find.widgetWithIcon(IconButton, Icons.check),
    );
    expect(check.onPressed, isNull, reason: 'an empty name cannot be saved');

    await tester.enterText(find.byType(TextField), 'Grudge Match');
    await tester.pump();
    await tester.tap(find.byTooltip('Save name'));
    await tester.pumpAndSettle();
    expect(find.text('GRUDGE MATCH'), findsOneWidget);

    await tapText(tester, 'ALPHA');
    await tester.pageBack();
    await tester.pumpAndSettle();
    expect((await skirmishes.loadAll()).single.name, 'Grudge Match');
  });

  testWidgets('Load Skirmish continues a setup at its saved step', (
    tester,
  ) async {
    await pumpApp(tester);
    await openNewSkirmish(tester);
    await tapText(tester, 'ALPHA');
    await tapText(tester, 'NEXT: PLAYER 2');
    await tester.pageBack();
    await tester.pumpAndSettle();

    await tester.tap(find.text('LOAD SKIRMISH').first);
    await tester.pumpAndSettle();
    expect(find.byType(LoadSkirmishScreen), findsOneWidget);
    expect(find.textContaining('Setup · Player 2 Lance'), findsOneWidget);

    await tester.tap(find.textContaining('SKIRMISH 20').first);
    await tester.pumpAndSettle();
    await tapText(tester, 'CONTINUE SETUP');
    expect(find.text('NEW SKIRMISH · PLAYER 2 LANCE'), findsOneWidget);
    expect(find.text('LANCE ROSTER'), findsOneWidget, reason: 'P1 summary');

    // Back returns to Load Skirmish.
    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(find.byType(LoadSkirmishScreen), findsOneWidget);

    await tapText(tester, 'DELETE');
    await tester.tap(find.widgetWithText(FilledButton, 'DELETE'));
    await tester.pumpAndSettle();
    expect(await skirmishes.loadAll(), isEmpty);
    expect(find.textContaining('No saved skirmishes yet'), findsOneWidget);
  });
}
