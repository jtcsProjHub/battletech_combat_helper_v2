import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:map_extractor_prototype/map_extractor.dart';

import 'package:battletech_combat_helper_v2/lance.dart';
import 'package:battletech_combat_helper_v2/location.dart';
import 'package:battletech_combat_helper_v2/maps/map_repository.dart';
import 'package:battletech_combat_helper_v2/mech_data.dart';
import 'package:battletech_combat_helper_v2/mech_library.dart';
import 'package:battletech_combat_helper_v2/pilot_data.dart';
import 'package:battletech_combat_helper_v2/skirmish/skirmish.dart';
import 'package:battletech_combat_helper_v2/skirmish/skirmish_map.dart';
import 'package:battletech_combat_helper_v2/skirmish/skirmish_repository.dart';

void main() {
  final library = MechLibrary(const [
    Mech(
      id: 'archer',
      name: 'Archer',
      variant: 'ARC-2R',
      tonnage: 70,
      armorTotal: 30,
      armorByLocation: {Location.head: 9, Location.centerTorso: 21},
      structureTotal: 25,
      structureByLocation: {Location.head: 3, Location.centerTorso: 22},
    ),
  ]);

  Lance lance(String name) => Lance(
    id: name.toLowerCase(),
    name: name,
    slots: const [
      LanceSlot(
        mechId: 'archer',
        pilot: Pilot(name: 'Kai', gunnery: 3),
      ),
      LanceSlot(mechId: 'not_in_catalog'),
    ],
  );

  final map = SavedMap(
    id: 'hills',
    sheet: MapSheet(
      name: 'Hills',
      grid: const GridSpec(columns: 3, rows: 3),
      hexes: {const HexCoord(1, 1): const HexTerrain(level: 2)},
    ),
  );

  Skirmish ready() => Skirmish.create(now: DateTime(2026, 11, 12, 19, 5))
    ..player1.lance = lance('Alpha')
    ..player2.lance = lance('Bravo')
    ..map = SkirmishMap(map);

  test('a new skirmish is named after its start time', () {
    final s = Skirmish.create(now: DateTime(2026, 11, 12, 9, 5));
    expect(s.name, 'Skirmish 2026-11-12 09:05');
    expect(s.phase, SkirmishPhase.setup);
    expect(s.hasSelections, isFalse);
  });

  test('steps open in order as choices are made', () {
    final s = Skirmish.create();
    expect(s.isStepReachable(SetupStep.player1), isTrue);
    expect(s.isStepReachable(SetupStep.player2), isFalse);

    s.player1.lance = lance('Alpha');
    expect(s.isStepReachable(SetupStep.player2), isTrue);
    expect(s.isStepReachable(SetupStep.map), isFalse);

    s.player2.lance = lance('Bravo');
    s.map = SkirmishMap(map);
    expect(s.isStepReachable(SetupStep.overview), isTrue);
    expect(s.canConfirm, isTrue);
  });

  test('confirm cannot run before everything is chosen', () {
    expect(() => Skirmish.create().confirm(library), throwsStateError);
  });

  test('confirm builds units at full armor and starts turn 1', () {
    final s = ready()..confirm(library);

    expect(s.phase, SkirmishPhase.active);
    expect(s.turn, 1);
    expect(s.log.single, contains('Alpha vs Bravo on Hills'));
    // The unknown mech is skipped.
    final unit = s.player1.units.single;
    expect(unit.mechId, 'archer');
    expect(unit.pilot.gunnery, 3);
    expect(unit.armorLeft, 30);
    expect(unit.structureLeft, 25);
    expect(unit.heat, 0);
    expect(s.player2.units, hasLength(1));
  });

  test('round-trips through JSON', () {
    final s = ready()..confirm(library);
    s.player1.units.single
      ..armor[Location.head] = 4
      ..heat = 7;

    final loaded = Skirmish.fromJson(s.toJson());
    expect(loaded.id, s.id);
    expect(loaded.name, s.name);
    expect(loaded.createdAt, s.createdAt);
    expect(loaded.phase, SkirmishPhase.active);
    expect(loaded.turn, 1);
    expect(loaded.log, s.log);
    expect(loaded.player1.lance!.name, 'Alpha');
    expect(loaded.map!.id, 'hills');
    expect(loaded.map!.terrainAt(const HexCoord(1, 1)).level, 2);
    final unit = loaded.player1.units.single;
    expect(unit.armor[Location.head], 4);
    expect(unit.armor[Location.centerTorso], 21);
    expect(unit.heat, 7);
    expect(unit.pilot.name, 'Kai');
  });

  test('setup copies refresh from their sources; active ones do not', () {
    final s = ready();
    final edited = lance('Alpha').copyWith(name: 'Alpha Mk II');

    expect(s.refreshFromSources(lances: [edited], maps: const []), isTrue);
    expect(s.player1.lance!.name, 'Alpha Mk II');
    // Bravo's precon is gone, so its copy stays.
    expect(s.player2.lance!.name, 'Bravo');
    expect(s.map!.source, same(map));

    s.confirm(library);
    final later = lance('Alpha').copyWith(name: 'Alpha Mk III');
    expect(s.refreshFromSources(lances: [later], maps: const []), isFalse);
    expect(s.player1.lance!.name, 'Alpha Mk II');
  });

  group('SkirmishMap merge rules', () {
    const hill = HexCoord(1, 1); // printed level 2
    const woods = HexCoord(2, 1);
    final printed = SavedMap(
      id: 'm',
      sheet: MapSheet(
        name: 'M',
        grid: const GridSpec(columns: 3, rows: 3),
        hexes: {
          hill: const HexTerrain(level: 2, features: {TerrainFeature.rough}),
          woods: const HexTerrain(woods: Woods.heavy),
        },
      ),
    );

    test('no overlay leaves the printed terrain', () {
      final m = SkirmishMap(printed);
      expect(m.terrainAt(hill), printed.sheet.terrainAt(hill));
      expect(m.merged, same(printed.sheet));
    });

    test('an environment override replaces all but the level', () {
      final m = SkirmishMap(printed)
        ..setEnvironment([
          hill,
        ], const HexTerrain(woods: Woods.light, level: 5, waterDepth: 1));
      expect(
        m.terrainAt(hill),
        const HexTerrain(woods: Woods.light, level: 2, waterDepth: 1),
      );
      expect(m.overlayAt(hill).environment!.level, 0);

      m.setEnvironment([hill], null);
      expect(m.terrainAt(hill), printed.sheet.terrainAt(hill));
      expect(m.overlay, isEmpty);
    });

    test('a building plays as an empty level 0 hex with the building', () {
      final m = SkirmishMap(printed)
        ..setEnvironment([hill], const HexTerrain(woods: Woods.light))
        ..setLevel([hill], 3)
        ..setBuilding([hill, woods], true);
      const building = HexTerrain(features: {TerrainFeature.building});
      expect(m.terrainAt(hill), building);
      expect(m.terrainAt(woods), building);

      // Removing the building brings back what was under it.
      m.setBuilding([hill, woods], false);
      expect(m.terrainAt(hill), const HexTerrain(woods: Woods.light, level: 3));
      expect(m.terrainAt(woods), const HexTerrain(woods: Woods.heavy));
    });

    test('level overrides are absolute and combine with environment', () {
      final m = SkirmishMap(printed)
        ..setLevel([hill], 1)
        ..setEnvironment([hill], const HexTerrain(waterDepth: 2));
      expect(m.terrainAt(hill), const HexTerrain(level: 1, waterDepth: 2));

      // Each hex in a selection gets the same absolute level.
      m.setLevel([hill, woods], 0);
      expect(m.terrainAt(hill).level, 0);
      expect(m.terrainAt(woods), const HexTerrain(woods: Woods.heavy));
      expect(m.overlayAt(woods), HexOverlay.none, reason: 'already level 0');

      // Setting the printed level again drops the override.
      m.setLevel([hill], 2);
      expect(m.overlayAt(hill).level, isNull);
      expect(m.terrainAt(hill), const HexTerrain(level: 2, waterDepth: 2));
    });

    test('confirming locks in empty level 0 ground under buildings', () {
      final m = SkirmishMap(printed)
        ..setEnvironment([hill], const HexTerrain(woods: Woods.light))
        ..setLevel([hill], 3)
        ..setBuilding([hill], true)
        ..setLevel([woods], 1);
      final s = ready()..map = m;
      s.confirm(library);

      expect(
        m.terrainAt(hill),
        const HexTerrain(features: {TerrainFeature.building}),
      );
      // A destroyed building leaves bare level 0 ground, not the printed
      // level 2 hill or the setup-time woods.
      m.setBuilding([hill], false);
      expect(m.terrainAt(hill), HexTerrain.clear);
      // Hexes without a building keep their overrides.
      expect(
        m.terrainAt(woods),
        const HexTerrain(woods: Woods.heavy, level: 1),
      );
      expect(SkirmishMap.fromJson(m.toJson()).overlay, m.overlay);
    });

    test('hexes off the sheet are ignored, and clear removes every layer', () {
      final m = SkirmishMap(printed)
        ..setBuilding([const HexCoord(9, 9)], true)
        ..setBuilding([hill], true)
        ..setLevel([hill], 3);
      expect(m.overlay.keys, [hill]);
      m.clear([hill]);
      expect(m.overlay, isEmpty);
    });

    test('the overlay round-trips through JSON', () {
      final m = SkirmishMap(printed)
        ..setEnvironment([woods], const HexTerrain(woods: Woods.light))
        ..setBuilding([hill], true)
        ..setLevel([woods], -1);
      final loaded = SkirmishMap.fromJson(m.toJson());
      expect(loaded.overlay, m.overlay);
      expect(loaded.terrainAt(hill), m.terrainAt(hill));
      expect(loaded.merged.hexes, m.merged.hexes);
    });

    test('refreshing the sheet from its source keeps the overlay', () {
      final s = ready()
        ..map = (SkirmishMap(printed)..setBuilding([hill], true));
      final edited = SavedMap(
        id: 'm',
        sheet: MapSheet(
          name: 'M v2',
          grid: printed.sheet.grid,
          hexes: const {},
        ),
      );
      s.refreshFromSources(lances: const [], maps: [edited]);
      expect(s.map!.name, 'M v2');
      expect(s.map!.terrainAt(hill).features, {TerrainFeature.building});
    });
  });

  group('FileSkirmishRepository', () {
    late Directory dir;
    late FileSkirmishRepository repo;

    setUp(() async {
      dir = await Directory.systemTemp.createTemp('skirmishes_');
      repo = FileSkirmishRepository(() async => dir);
    });

    tearDown(() => dir.delete(recursive: true));

    test('saves, lists most recent first, and deletes', () async {
      final older = ready()..updatedAt = DateTime(2026, 1, 1);
      final newer = Skirmish.create()..updatedAt = DateTime(2026, 6, 1);
      await repo.save(older);
      await repo.save(newer);

      final loaded = await repo.loadAll();
      expect(loaded.map((s) => s.id), [newer.id, older.id]);
      expect(loaded.last.map!.name, 'Hills');
      expect(dir.listSync().length, 2, reason: 'no temp file is left');

      await repo.delete(older.id);
      await repo.delete('unknown');
      expect((await repo.loadAll()).single.id, newer.id);
    });

    test('skips files that do not parse', () async {
      await repo.save(ready());
      await File('${dir.path}/broken.json').writeAsString('{not json');
      expect(await repo.loadAll(), hasLength(1));
    });
  });
}
