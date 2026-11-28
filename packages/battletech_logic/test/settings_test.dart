import 'package:battletech_logic/battletech_logic.dart';
import 'package:test/test.dart';

void main() {
  group('roll catalog', () {
    test('ids are unique and every roll has a path', () {
      final ids = [
        for (final g in rollCatalog)
          for (final o in g.selfAndDescendants) o.id,
      ];
      expect(ids.toSet().length, ids.length);
      expect(RollOption.pathTo('damage.criticalSlot').map((o) => o.id), [
        'damage',
        'damage.critical',
        'damage.criticalSlot',
      ]);
      expect(RollOption.pathTo('nope'), isEmpty);
    });
  });

  group('RollPreferences', () {
    test('everything is automated by default', () {
      for (final g in rollCatalog) {
        for (final o in g.selfAndDescendants) {
          expect(RollPreferences.automated.isAutomated(o.id), isTrue);
        }
      }
    });

    test('an unchecked group hands its rolls to the players but keeps '
        'their own checks', () {
      final p = RollPreferences.automated
          .withChecked('damage.criticalSlot', checked: false)
          .withChecked('damage', checked: false);
      expect(p.isAutomated('damage.psr'), isFalse);
      expect(p.isChecked('damage.psr'), isTrue);

      final back = p.withChecked('damage', checked: true);
      expect(back.isAutomated('damage.psr'), isTrue);
      expect(back.isAutomated('damage.critical'), isTrue);
      expect(back.isAutomated('damage.criticalSlot'), isFalse);
    });

    test('JSON round trip drops unknown ids', () {
      final p = RollPreferences.automated.withChecked(
        'heat.ammo',
        checked: false,
      );
      expect(RollPreferences.fromJson(p.toJson()), p);
      expect(
        RollPreferences.fromJson({
          'unchecked': ['heat.ammo', 'retired.roll'],
        }),
        p,
      );
      expect(RollPreferences.fromJson(null), RollPreferences.automated);
    });
  });

  group('PlayerSettings', () {
    test('a blank name counts as none; the lance name stands in', () {
      expect(PlayerSettings(name: '  ').name, isNull);
      expect(PlayerSettings().displayName('Alpha Lance'), 'Alpha Lance');
      expect(PlayerSettings(name: ' Kai ').displayName('Alpha'), 'Kai');
    });

    test('start from the host defaults and round trip', () {
      final defaults = GameplaySettings(
        rolls: RollPreferences.automated.withChecked(
          'initiative',
          checked: false,
        ),
      );
      final p = PlayerSettings.fromDefaults(defaults).copyWith(name: 'Kai');
      expect(p.rolls, defaults.rolls);
      expect(PlayerSettings.fromJson(p.toJson()), p);
      expect(p.withoutName().name, isNull);
    });
  });

  group('AppSettings', () {
    test('file text round trip', () {
      final s = AppSettings(
        host: const HostConfig(hotspotConnection: 'BT', port: 9000),
        gameplay: GameplaySettings(
          rolls: RollPreferences.automated.withChecked('heat', checked: false),
        ),
      );
      expect(AppSettings.decode(s.encode()), s);
    });

    test('missing or bad values fall back to defaults', () {
      final s = AppSettings.fromJson({
        'host': {'hotspotConnection': ' ', 'port': 80, 'ssid': 'Old'},
      });
      expect(s, const AppSettings());
      expect(() => AppSettings.decode('[]'), throwsFormatException);
    });
  });

  group('SkirmishSettings', () {
    test('snapshot gives both players the host defaults', () {
      final rolls = RollPreferences.automated.withChecked(
        'weapons.toHit',
        checked: false,
      );
      final s = SkirmishSettings.snapshot(
        AppSettings(gameplay: GameplaySettings(rolls: rolls)),
      );
      expect(s.players, hasLength(2));
      expect(
        s.players.every((p) => p.rolls == rolls && p.name == null),
        isTrue,
      );

      s.players[1] = s.players[1].copyWith(name: 'Kai');
      final back = SkirmishSettings.fromJson(s.toJson());
      expect(back.players[1].name, 'Kai');
      expect(back.defaults.rolls, rolls);
    });
  });

  group('AppSettingsDraft', () {
    test('tracks changes, validates, reverts and saves', () {
      final d = AppSettingsDraft(const AppSettings());
      expect(d.isDirty, isFalse);

      d.host.port = '80';
      expect(d.host.portError, isNotNull);
      expect(d.canSave, isFalse);

      d.host.port = '9001';
      d.setRollChecked('falls', checked: false);
      expect(d.canSave, isTrue);
      expect(d.value.host.port, 9001);
      expect(d.value.gameplay.rolls.isAutomated('falls.facing'), isFalse);

      final saved = d.value;
      d.markSaved(saved);
      expect(d.isDirty, isFalse);
      expect(d.saved, saved);

      d.host.connection = '';
      expect(d.host.connectionError, isNotNull);
      d.revert();
      expect(d.host.connection, saved.host.hotspotConnection);
      expect(d.isDirty, isFalse);
    });

    test('the network comes from the profile and is saved back to it', () {
      final d = AppSettingsDraft(const AppSettings());
      expect(d.networkEditable, isFalse);
      expect(d.networkToSave, isNull);

      d.networkLoaded(const HotspotNetwork(ssid: 'Net', password: 'pw123456'));
      final n = d.network!;
      expect(n.ssid, 'Net');
      expect(d.isDirty, isFalse);

      n.password = 'short';
      expect(n.passwordError, isNotNull);
      expect(d.canSave, isFalse);

      // A blank password keeps the profile's.
      n
        ..password = ''
        ..ssid = ' Field ';
      expect(
        d.networkToSave,
        const HotspotNetwork(ssid: 'Field', password: 'pw123456'),
      );
      expect(d.canSave, isTrue);
      expect(d.settingsDirty, isFalse);

      n.ssid = '';
      expect(n.ssidError, isNotNull);
      expect(d.canSave, isFalse);

      d.revert();
      expect(d.network!.ssid, 'Net');
      expect(d.isDirty, isFalse);

      d.network!.ssid = 'Field';
      d.markSaved(d.value, network: d.networkToSave);
      expect(d.network!.loaded.ssid, 'Field');
      expect(d.isDirty, isFalse);
    });

    test('a renamed profile locks the network until saved', () {
      final d = AppSettingsDraft(const AppSettings())
        ..networkLoaded(const HotspotNetwork(ssid: 'Net'));
      d.network!.ssid = 'Typed';
      d.host.connection = 'Other';
      expect(d.profileRenamed, isTrue);
      expect(d.networkEditable, isFalse);
      // The typed network is not written to either profile.
      expect(d.networkToSave, isNull);

      d.markSaved(d.value);
      expect(d.saved.host.hotspotConnection, 'Other');
      expect(d.network, isNull);
      d.networkFailed('No such profile');
      expect(d.networkError, 'No such profile');
      expect(d.isValid, isTrue);
    });
  });
}
