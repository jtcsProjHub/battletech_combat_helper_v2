import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:map_extractor_prototype/map_extractor.dart';

import 'package:battletech_combat_helper_v2/maps/map_repository.dart';
import 'package:battletech_combat_helper_v2/maps/map_sheet_draft.dart';

void main() {
  SavedMap map(String name, {String? id}) => SavedMap(
    id: id ?? name.toLowerCase(),
    sheet: MapSheet(
      name: name,
      grid: GridSpec.standard,
      hexes: {
        const HexCoord(1, 2): const HexTerrain(woods: Woods.light),
        const HexCoord(13, 5): const HexTerrain(level: 2),
      },
      unverified: {const HexCoord(13, 5)},
    ),
  );

  group('FileMapRepository', () {
    late Directory dir;
    late FileMapRepository repo;

    setUp(() async {
      dir = await Directory.systemTemp.createTemp('maps_');
      repo = FileMapRepository(() async => dir);
    });

    tearDown(() => dir.delete(recursive: true));

    test('loads nothing before the first save', () async {
      final missing = FileMapRepository(
        () async => Directory('${dir.path}/not_created'),
      );
      expect(await missing.loadAll(), isEmpty);
    });

    test('saves plain btmap files and loads them sorted by name', () async {
      await repo.save(map('Foothills #1', id: 'f1'));
      await repo.save(map('desert #1', id: 'd1'));

      final loaded = await repo.loadAll();
      expect(loaded.map((m) => m.name), ['desert #1', 'Foothills #1']);
      final foothills = loaded.last;
      expect(foothills.id, 'f1');
      expect(
        foothills.sheet.terrainAt(const HexCoord(1, 2)),
        const HexTerrain(woods: Woods.light),
      );
      expect(foothills.sheet.unverified, {const HexCoord(13, 5)});

      // The file is a plain btmap file, so the prototype can open it.
      final raw = await File('${dir.path}/f1.btmap.json').readAsString();
      expect(MapSheet.fromJsonString(raw).name, 'Foothills #1');
      expect(raw, isNot(contains('"id"')));
    });

    test('saving the same id replaces the map', () async {
      await repo.save(map('Old', id: 'm1'));
      await repo.save(map('New', id: 'm1'));
      expect((await repo.loadAll()).single.name, 'New');
    });

    test('delete removes the map and ignores unknown ids', () async {
      await repo.save(map('Alpha', id: 'a1'));
      await repo.delete('a1');
      await repo.delete('missing');
      expect(await repo.loadAll(), isEmpty);
    });

    test('skips files that do not parse and other files', () async {
      await repo.save(map('Good', id: 'good'));
      await File('${dir.path}/bad.btmap.json').writeAsString('{not json');
      await File('${dir.path}/notes.json').writeAsString('{}');
      expect((await repo.loadAll()).single.name, 'Good');
    });

    test('rejects ids that are not safe file names', () {
      expect(() => repo.save(map('X', id: '../x')), throwsArgumentError);
    });
  });

  group('MapSheetDraft', () {
    test('starts clean from a saved map and tracks edits', () {
      final draft = MapSheetDraft.fromSaved(map('Foothills #1', id: 'f1'));
      expect(draft.hasUnsavedChanges, isFalse);
      expect(draft.terrainCount, 2);
      expect(draft.toReviewCount, 1);

      draft.updateTerrain([const HexCoord(13, 5)], (t) => t.copyWith(level: 3));
      expect(draft.hasUnsavedChanges, isTrue);
      // Editing a hex counts as checking it.
      expect(draft.toReviewCount, 0);

      draft.markSaved();
      expect(draft.hasUnsavedChanges, isFalse);
      expect(draft.toSaved().id, 'f1');
    });

    test('a smaller grid drops outside hexes and flags on save', () {
      final draft = MapSheetDraft.fromSaved(map('Foothills #1'));
      draft.grid = const GridSpec(columns: 10, rows: 17);
      expect(draft.toReviewCount, 0);
      final sheet = draft.toSheet();
      expect(sheet.hexes.keys, [const HexCoord(1, 2)]);
      expect(sheet.unverified, isEmpty);

      // Growing the grid again brings the kept terrain back.
      draft.grid = GridSpec.standard;
      expect(draft.toSheet().hexes.length, 2);
    });

    test('next to review wraps around in column-then-row order', () {
      final draft = MapSheetDraft(id: 'x')
        ..setVerifiedAll([const HexCoord(2, 1), const HexCoord(5, 5)], false);
      expect(draft.nextToReview(null), const HexCoord(2, 1));
      expect(draft.nextToReview(const HexCoord(2, 1)), const HexCoord(5, 5));
      expect(draft.nextToReview(const HexCoord(5, 5)), const HexCoord(2, 1));
    });
  });
}
