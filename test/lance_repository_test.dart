import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:battletech_combat_helper_v2/era.dart';
import 'package:battletech_combat_helper_v2/lance.dart';
import 'package:battletech_combat_helper_v2/lance_repository.dart';

void main() {
  late Directory dir;
  late FileLanceRepository repo;

  setUp(() async {
    dir = await Directory.systemTemp.createTemp('lances_');
    repo = FileLanceRepository(() async => dir);
  });

  tearDown(() => dir.delete(recursive: true));

  Lance lance(String name, {String? id}) => Lance(
    id: id ?? name.toLowerCase(),
    name: name,
    parameters: const LanceParameters(
      targetBattleValue: 4500,
      era: Era.clanInvasion,
    ),
    slots: const [LanceSlot(mechId: 'thunderbolt_tdr_5s')],
  );

  test('loads nothing before the first save', () async {
    final missing = FileLanceRepository(
      () async => Directory('${dir.path}/not_created'),
    );
    expect(await missing.loadAll(), isEmpty);
  });

  test('saves and loads lances sorted by name', () async {
    await repo.save(lance('Bravo'));
    await repo.save(lance('alpha'));

    final loaded = await repo.loadAll();
    expect(loaded.map((l) => l.name), ['alpha', 'Bravo']);
    final bravo = loaded.last;
    expect(bravo.parameters.targetBattleValue, 4500);
    expect(bravo.parameters.era, Era.clanInvasion);
    expect(bravo.slots.single.mechId, 'thunderbolt_tdr_5s');
  });

  test('saving the same id replaces the lance', () async {
    await repo.save(lance('Alpha', id: 'a1'));
    await repo.save(lance('Alpha Renamed', id: 'a1'));

    final loaded = await repo.loadAll();
    expect(loaded.map((l) => l.name), ['Alpha Renamed']);
    expect(dir.listSync().length, 1, reason: 'no temp file is left behind');
  });

  test('delete removes the lance and ignores unknown ids', () async {
    await repo.save(lance('Alpha'));
    await repo.delete('alpha');
    await repo.delete('never_saved');
    expect(await repo.loadAll(), isEmpty);
  });

  test('an unreadable file is skipped and left on disk', () async {
    await repo.save(lance('Alpha'));
    final bad = File('${dir.path}/broken.json')..writeAsStringSync('{ nope');

    expect((await repo.loadAll()).map((l) => l.name), ['Alpha']);
    expect(bad.existsSync(), isTrue);
  });

  test('rejects ids that are not safe file names', () async {
    expect(
      () => repo.save(lance('Escape', id: '../escape')),
      throwsArgumentError,
    );
  });
}
