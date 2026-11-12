import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:battletech_combat_helper_v2/app_theme.dart';
import 'package:battletech_combat_helper_v2/lance.dart';
import 'package:battletech_combat_helper_v2/lance_totals.dart';
import 'package:battletech_combat_helper_v2/mech_data.dart';
import 'package:battletech_combat_helper_v2/mech_library.dart';
import 'package:battletech_combat_helper_v2/pilot_data.dart';
import 'package:battletech_combat_helper_v2/widgets/pilot_widgets.dart';

const _thunderbolt = Mech(
  id: 'tb',
  name: 'Thunderbolt',
  variant: 'TDR-5S',
  tonnage: 65,
  battleValue: 1335,
);
const _wolverine = Mech(
  id: 'wv',
  name: 'Wolverine',
  variant: 'WVR-6R',
  tonnage: 55,
  battleValue: 1101,
);

void main() {
  const trixie = Pilot(name: 'Trixie', gunnery: 3, piloting: 4);
  final totals = LanceTotals(
    Lance(
      id: 'alpha',
      name: 'Alpha',
      parameters: const LanceParameters(targetBattleValue: 3000),
      slots: const [
        LanceSlot(mechId: 'tb', pilot: trixie),
        LanceSlot(mechId: 'wv'),
      ],
    ),
    MechLibrary(const [_thunderbolt, _wolverine]),
  );

  Future<void> openDialog(WidgetTester tester, {LanceTotals? lance}) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => TextButton(
            onPressed: () => showPilotDialog(
              context,
              mech: _thunderbolt,
              pilot: trixie,
              lance: lance,
            ),
            child: const Text('open'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
  }

  /// The color of the span reading [span] inside the rich text [text].
  Color? colorOf(WidgetTester tester, String text, String span) {
    final rich = tester.widget<RichText>(find.text(text, findRichText: true));
    Color? color;
    rich.text.visitChildren((s) {
      if (s is TextSpan && s.text == span) color = s.style?.color;
      return color == null;
    });
    return color;
  }

  testWidgets('shows the current budget until the skills change', (
    tester,
  ) async {
    await openDialog(tester, lance: totals);

    // Trixie's 3/4: 1,762 + 1,101 = 2,863 of 3,000.
    expect(find.text('1,762  ×1.32', findRichText: true), findsOneWidget);
    expect(find.text('2,863  / 3,000', findRichText: true), findsOneWidget);
    expect(find.text('137', findRichText: true), findsOneWidget);
  });

  testWidgets('better skills that break the budget show in red', (
    tester,
  ) async {
    await openDialog(tester, lance: totals);
    await tester.tap(find.byTooltip('Lower Gunnery'));
    await tester.pump();

    // 2/4 is ×1.54: 1,335 → 2,056, so the lance goes to 3,157.
    expect(
      find.text('1,762 → 2,056  ×1.54', findRichText: true),
      findsOneWidget,
    );
    expect(
      find.text('2,863 → 3,157  / 3,000', findRichText: true),
      findsOneWidget,
    );
    expect(colorOf(tester, '137 → 157 over', '157 over'), AppColors.overBudget);
  });

  testWidgets('without a lance only the mech row shows', (tester) async {
    await openDialog(tester);
    expect(find.text('Mech BV'), findsOneWidget);
    expect(find.text('Lance BV'), findsNothing);
  });
}
