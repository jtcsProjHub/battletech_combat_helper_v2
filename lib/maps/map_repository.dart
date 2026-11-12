// File: lib/maps/map_repository.dart
// Saving and loading map sheets. Each map is one btmap JSON file named
// <id>.btmap.json under the app support directory
// (~/.local/share/<app id>/maps on Linux). The id lives only in the file
// name, so the files stay plain btmap files that the Map Extractor
// prototype can open. The Map Builder and, later, New Skirmish read the
// list through savedMapsProvider.

import 'dart:io';

import 'package:flutter/foundation.dart' show debugPrint;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:map_extractor_prototype/map_extractor.dart';
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';

/// A saved map sheet and the id it is stored under.
class SavedMap {
  const SavedMap({required this.id, required this.sheet});

  /// A new id for a map that is not saved yet.
  factory SavedMap.create(MapSheet sheet) =>
      SavedMap(id: const Uuid().v4(), sheet: sheet);

  final String id;

  /// Printed reference data only. Per-skirmish changes, such as placed
  /// buildings, go in a separate layer.
  final MapSheet sheet;

  String get name => sheet.name;
}

abstract interface class MapRepository {
  /// Every saved map, sorted by name.
  Future<List<SavedMap>> loadAll();

  /// Adds the map, or replaces the saved map with the same id.
  Future<void> save(SavedMap map);

  /// Does nothing when no map has this id.
  Future<void> delete(String id);
}

class FileMapRepository implements MapRepository {
  /// [directory] is resolved on first use, so building the repository does
  /// no I/O.
  FileMapRepository(this._directory);

  /// The maps folder under the app support directory.
  factory FileMapRepository.appSupport() => FileMapRepository(
    () async => Directory(
      '${(await getApplicationSupportDirectory()).path}'
      '${Platform.pathSeparator}maps',
    ),
  );

  final Future<Directory> Function() _directory;

  static const _suffix = '.btmap.json';

  /// Ids come from file names too, so keep them to safe file names.
  static final _safeId = RegExp(r'^[A-Za-z0-9_-]+$');

  Future<File> _file(String id) async {
    if (!_safeId.hasMatch(id)) {
      throw ArgumentError.value(id, 'id', 'Not usable as a file name');
    }
    final dir = await _directory();
    return File('${dir.path}${Platform.pathSeparator}$id$_suffix');
  }

  /// A file that does not parse is skipped and left on disk, so one bad file
  /// does not hide the other maps and can still be fixed by hand.
  @override
  Future<List<SavedMap>> loadAll() async {
    final dir = await _directory();
    if (!await dir.exists()) return [];
    final maps = <SavedMap>[];
    await for (final entity in dir.list()) {
      if (entity is! File || !entity.path.endsWith(_suffix)) continue;
      final name = entity.uri.pathSegments.last;
      final id = name.substring(0, name.length - _suffix.length);
      if (!_safeId.hasMatch(id)) continue;
      try {
        final sheet = MapSheet.fromJsonString(await entity.readAsString());
        maps.add(SavedMap(id: id, sheet: sheet));
      } on Object catch (e) {
        debugPrint('Skipped unreadable map file ${entity.path}: $e');
      }
    }
    return _sortByName(maps);
  }

  /// Writes a temporary file and renames it over the old one, so a failed
  /// write never leaves a half-written map.
  @override
  Future<void> save(SavedMap map) async {
    final file = await _file(map.id);
    await file.parent.create(recursive: true);
    final temp = File('${file.path}.tmp');
    await temp.writeAsString(map.sheet.toJsonString(), flush: true);
    await temp.rename(file.path);
  }

  @override
  Future<void> delete(String id) async {
    final file = await _file(id);
    if (await file.exists()) await file.delete();
  }
}

/// Keeps maps in memory only. Used by tests in place of the file system.
class MemoryMapRepository implements MapRepository {
  MemoryMapRepository([Iterable<SavedMap> maps = const []])
    : _maps = {for (final m in maps) m.id: m};

  final Map<String, SavedMap> _maps;

  @override
  Future<List<SavedMap>> loadAll() async => _sortByName(_maps.values);

  @override
  Future<void> save(SavedMap map) async => _maps[map.id] = map;

  @override
  Future<void> delete(String id) async => _maps.remove(id);
}

List<SavedMap> _sortByName(Iterable<SavedMap> maps) =>
    maps.toList()
      ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));

/// Where maps are saved. Tests override this with a MemoryMapRepository.
final mapRepositoryProvider = Provider<MapRepository>(
  (ref) => FileMapRepository.appSupport(),
);

/// The saved maps, sorted by name. Save and delete through the notifier so
/// every screen that watches the list sees the change.
class SavedMaps extends AsyncNotifier<List<SavedMap>> {
  @override
  Future<List<SavedMap>> build() => ref.watch(mapRepositoryProvider).loadAll();

  Future<void> save(SavedMap map) async {
    await ref.read(mapRepositoryProvider).save(map);
    ref.invalidateSelf();
    await future;
  }

  Future<void> delete(String id) async {
    await ref.read(mapRepositoryProvider).delete(id);
    ref.invalidateSelf();
    await future;
  }
}

final savedMapsProvider = AsyncNotifierProvider<SavedMaps, List<SavedMap>>(
  SavedMaps.new,
);
