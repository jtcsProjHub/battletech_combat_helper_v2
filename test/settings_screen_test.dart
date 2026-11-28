import 'package:battletech_logic/battletech_logic.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:battletech_combat_helper_v2/main.dart';
import 'package:battletech_combat_helper_v2/screens/settings_screen.dart';
import 'package:battletech_combat_helper_v2/server/hotspot.dart';
import 'package:battletech_combat_helper_v2/settings/settings_repository.dart';

class _FakeProfiles implements HotspotProfiles {
  final networks = <String, HotspotNetwork>{
    'BattleTech-Hotspot': const HotspotNetwork(
      ssid: 'BattleTech',
      password: 'original1',
    ),
  };

  @override
  Future<HotspotNetwork> read(String connection) async =>
      networks[connection] ??
      (throw HotspotException('No profile "$connection".'));

  @override
  Future<void> write(String connection, HotspotNetwork network) async {
    if (!networks.containsKey(connection)) {
      throw HotspotException('No profile "$connection".');
    }
    networks[connection] = network;
  }
}

void main() {
  late MemorySettingsRepository repo;
  late _FakeProfiles profiles;

  Future<void> openSettings(
    WidgetTester tester, {
    bool missingProfile = false,
  }) async {
    tester.view.physicalSize = const Size(1600, 1000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    repo = MemorySettingsRepository();
    profiles = _FakeProfiles();
    if (missingProfile) profiles.networks.clear();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          settingsRepositoryProvider.overrideWithValue(repo),
          hotspotProfilesProvider.overrideWithValue(profiles),
        ],
        child: const MyApp(),
      ),
    );
    await tester.tap(find.byTooltip('Settings'));
    await tester.pumpAndSettle();
    expect(find.byType(SettingsScreen), findsOneWidget);
  }

  FilledButton saveButton(WidgetTester tester) =>
      tester.widget<FilledButton>(find.widgetWithText(FilledButton, 'SAVE'));

  testWidgets('reads the network from the profile and saves it back', (
    tester,
  ) async {
    await openSettings(tester);
    expect(find.text('SERVER SETTINGS'), findsOneWidget);
    expect(find.text('BattleTech'), findsOneWidget);
    expect(saveButton(tester).onPressed, isNull);

    await tester.enterText(find.widgetWithText(TextField, 'Password'), 'short');
    await tester.pump();
    expect(find.text('Use 8 to 63 characters.'), findsOneWidget);
    expect(saveButton(tester).onPressed, isNull);

    await tester.enterText(
      find.widgetWithText(TextField, 'Password'),
      'longenough',
    );
    await tester.enterText(
      find.widgetWithText(TextField, 'Network name'),
      'Battlefield',
    );
    await tester.pump();
    await tester.tap(find.text('SAVE'));
    await tester.pumpAndSettle();

    expect(
      profiles.networks['BattleTech-Hotspot'],
      const HotspotNetwork(ssid: 'Battlefield', password: 'longenough'),
    );
    // Only the profile changed, so the settings file was not written.
    expect(repo.saves, 0);
    expect(find.text('All changes saved'), findsOneWidget);
  });

  testWidgets('switching profiles locks the network until saved', (
    tester,
  ) async {
    await openSettings(tester);
    profiles.networks['Other'] = const HotspotNetwork(ssid: 'OtherNet');

    await tester.enterText(
      find.widgetWithText(TextField, 'Hotspot profile'),
      'Other',
    );
    await tester.pump();
    expect(find.textContaining('Save to switch profiles'), findsOneWidget);
    final ssid = tester.widget<TextField>(
      find.widgetWithText(TextField, 'Network name'),
    );
    expect(ssid.enabled, isFalse);

    await tester.tap(find.text('SAVE'));
    await tester.pumpAndSettle();
    expect(repo.saved.host.hotspotConnection, 'Other');
    expect(find.text('OtherNet'), findsOneWidget);
    expect(find.textContaining('could not be read'), findsOneWidget);
  });

  testWidgets('a missing profile is reported and can be retried', (
    tester,
  ) async {
    await openSettings(tester, missingProfile: true);
    expect(
      find.textContaining('No profile "BattleTech-Hotspot"'),
      findsOneWidget,
    );
    final ssid = tester.widget<TextField>(
      find.widgetWithText(TextField, 'Network name'),
    );
    expect(ssid.enabled, isFalse);

    profiles.networks['BattleTech-Hotspot'] = const HotspotNetwork(
      ssid: 'Back',
    );
    await tester.tap(find.text('RETRY'));
    await tester.pumpAndSettle();
    expect(find.text('Back'), findsOneWidget);
  });

  testWidgets('unchecking a group disables its rolls; revert undoes it', (
    tester,
  ) async {
    await openSettings(tester);
    await tester.tap(find.text('GAME PLAY'));
    await tester.pumpAndSettle();

    CheckboxListTile tile(String label) => tester.widget<CheckboxListTile>(
      find.widgetWithText(CheckboxListTile, label),
    );
    expect(tile('Initiative roll').enabled, isTrue);

    await tester.tap(find.text('INITIATIVE'));
    await tester.pump();
    expect(tile('INITIATIVE').value, isFalse);
    expect(tile('Initiative roll').enabled, isFalse);
    expect(tile('Initiative roll').value, isTrue);
    expect(find.text('Unsaved changes'), findsOneWidget);

    await tester.tap(find.text('REVERT'));
    await tester.pump();
    expect(tile('INITIATIVE').value, isTrue);
    expect(tile('Initiative roll').enabled, isTrue);
  });

  testWidgets('a roll unchecked deep in the list is saved', (tester) async {
    await openSettings(tester);
    await tester.tap(find.text('GAME PLAY'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Shutdown avoidance'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Shutdown avoidance'));
    await tester.pump();
    await tester.tap(find.text('SAVE'));
    await tester.pumpAndSettle();
    expect(repo.saved.gameplay.rolls.isAutomated('heat.shutdown'), isFalse);
    expect(repo.saved.gameplay.rolls, isNot(RollPreferences.automated));
  });

  testWidgets('leaving with unsaved changes asks first', (tester) async {
    await openSettings(tester);
    await tester.enterText(
      find.widgetWithText(TextField, 'Hotspot profile'),
      'Other',
    );
    await tester.pump();
    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(find.text('Discard changes?'), findsOneWidget);
    await tester.tap(find.text('DISCARD'));
    await tester.pumpAndSettle();
    expect(find.byType(SettingsScreen), findsNothing);
    expect(repo.saves, 0);
  });
}
