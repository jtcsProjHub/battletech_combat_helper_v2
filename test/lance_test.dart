import 'package:flutter_test/flutter_test.dart';

import 'package:battletech_combat_helper_v2/era.dart';
import 'package:battletech_combat_helper_v2/lance.dart';
import 'package:battletech_combat_helper_v2/mech_data.dart' show TechBase;
import 'package:battletech_combat_helper_v2/pilot_data.dart';

void main() {
  test('Default parameters are 3000 BV and 4 mechs with no filters', () {
    const p = LanceParameters();
    expect(p.targetBattleValue, 3000);
    expect(p.maxMechs, 4);
    expect(p.era, isNull);
    expect(p.faction, isNull);
    expect(p.techBase, isNull);
  });

  test('Lance.create trims the name and makes an id', () {
    final a = Lance.create(name: '  Alpha  ');
    final b = Lance.create(name: 'Bravo');
    expect(a.name, 'Alpha');
    expect(a.id, isNotEmpty);
    expect(a.id, isNot(b.id));
    expect(a.slots, isEmpty);
  });

  test('A blank name is rejected', () {
    expect(() => Lance.create(name: '   '), throwsArgumentError);
  });

  test('JSON round trip keeps parameters and slots', () {
    final lance =
        Lance.create(
          name: 'Alpha',
          parameters: const LanceParameters(
            targetBattleValue: 6000,
            maxMechs: 5,
            era: Era.clanInvasion,
            faction: 'Clan Jade Falcon',
            techBase: TechBase.clan,
          ),
        ).copyWith(
          slots: const [
            LanceSlot(
              mechId: 'mech-1',
              pilot: Pilot(name: 'Aidan', gunnery: 3),
            ),
          ],
        );

    final back = Lance.fromJson(lance.toJson());
    expect(back.id, lance.id);
    expect(back.name, 'Alpha');
    expect(back.parameters, lance.parameters);
    expect(back.slots.single.mechId, 'mech-1');
    expect(back.slots.single.pilot, const Pilot(name: 'Aidan', gunnery: 3));
  });

  test('isFull compares slots to maxMechs', () {
    final lance = Lance.create(
      name: 'Pair',
      parameters: const LanceParameters(maxMechs: 2),
    );
    expect(lance.isFull, isFalse);
    final full = lance.copyWith(
      slots: const [
        LanceSlot(mechId: 'a'),
        LanceSlot(mechId: 'b'),
      ],
    );
    expect(full.isFull, isTrue);
  });
}
