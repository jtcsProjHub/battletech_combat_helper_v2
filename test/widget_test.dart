import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:battletech_combat_helper_v2/main.dart';
import 'package:battletech_combat_helper_v2/screens/lance_builder_screen.dart';

void main() {
  Future<void> pumpApp(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(const MyApp());
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

    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(find.text('SELECT OPERATION'), findsOneWidget);
  });
}
