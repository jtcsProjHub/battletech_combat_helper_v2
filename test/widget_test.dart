import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:battletech_combat_helper_v2/main.dart';
import 'package:battletech_combat_helper_v2/mech_data.dart';
import 'package:battletech_combat_helper_v2/mech_library.dart';
import 'package:battletech_combat_helper_v2/screens/lance_builder_screen.dart';
import 'package:battletech_combat_helper_v2/screens/lance_editor_screen.dart';

void main() {
  Future<void> pumpApp(
    WidgetTester tester, {
    List<Mech> mechs = const [],
    Size size = const Size(1280, 800),
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ProviderScope(
        // The real provider parses the bundled asset on an isolate, which doesn't work under the test clock.
        overrides: [
          mechLibraryProvider.overrideWith((ref) => MechLibrary(mechs)),
        ],
        child: const MyApp(),
      ),
    );
  }

  testWidgets('Main menu shows the three options and Quit', (tester) async {
    await pumpApp(tester);

    // The first option shows in the menu and in the briefing panel.
    expect(find.text('CREATE / EDIT LANCE PRECONS'), findsNWidgets(2));
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
    expect(find.text('3000'), findsOneWidget);
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
    expect(find.text('3000'), findsOneWidget);
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
}
