// File: lib/lance_repository.dart
// Saving and loading lance precons. Each lance is one JSON file named by its
// id, under the app support directory (~/.local/share/<app id>/lances on
// Linux). The Lance Builder and New Skirmish read the list through
// savedLancesProvider.

import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart' show debugPrint;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';

import 'lance.dart';

abstract interface class LanceRepository {
  /// Every saved lance, sorted by name.
  Future<List<Lance>> loadAll();

  /// Adds the lance, or replaces the saved lance with the same id.
  Future<void> save(Lance lance);

  /// Does nothing when no lance has this id.
  Future<void> delete(String id);
}

class FileLanceRepository implements LanceRepository {
  /// [directory] is resolved on first use, so building the repository does
  /// no I/O.
  FileLanceRepository(this._directory);

  /// The lances folder under the app support directory.
  factory FileLanceRepository.appSupport() => FileLanceRepository(
    () async => Directory(
      '${(await getApplicationSupportDirectory()).path}'
      '${Platform.pathSeparator}lances',
    ),
  );

  final Future<Directory> Function() _directory;

  /// Ids come from saved files too, so keep them to safe file names.
  static final _safeId = RegExp(r'^[A-Za-z0-9_-]+$');

  Future<File> _file(String id) async {
    if (!_safeId.hasMatch(id)) {
      throw ArgumentError.value(id, 'id', 'Not usable as a file name');
    }
    final dir = await _directory();
    return File('${dir.path}${Platform.pathSeparator}$id.json');
  }

  /// A file that does not parse is skipped and left on disk, so one bad file
  /// does not hide the other lances and can still be fixed by hand.
  @override
  Future<List<Lance>> loadAll() async {
    final dir = await _directory();
    if (!await dir.exists()) return [];
    final lances = <Lance>[];
    await for (final entity in dir.list()) {
      if (entity is! File || !entity.path.endsWith('.json')) continue;
      try {
        final json = jsonDecode(await entity.readAsString());
        lances.add(Lance.fromJson(json as Map<String, dynamic>));
      } on Object catch (e) {
        debugPrint('Skipped unreadable lance file ${entity.path}: $e');
      }
    }
    return _sortByName(lances);
  }

  /// Writes a temporary file and renames it over the old one, so a failed
  /// write never leaves a half-written lance.
  @override
  Future<void> save(Lance lance) async {
    final file = await _file(lance.id);
    await file.parent.create(recursive: true);
    final temp = File('${file.path}.tmp');
    await temp.writeAsString(
      const JsonEncoder.withIndent('  ').convert(lance.toJson()),
      flush: true,
    );
    await temp.rename(file.path);
  }

  @override
  Future<void> delete(String id) async {
    final file = await _file(id);
    if (await file.exists()) await file.delete();
  }
}

/// Keeps lances in memory only. Used by tests in place of the file system.
class MemoryLanceRepository implements LanceRepository {
  MemoryLanceRepository([Iterable<Lance> lances = const []])
    : _lances = {for (final l in lances) l.id: l};

  final Map<String, Lance> _lances;

  @override
  Future<List<Lance>> loadAll() async => _sortByName(_lances.values);

  @override
  Future<void> save(Lance lance) async => _lances[lance.id] = lance;

  @override
  Future<void> delete(String id) async => _lances.remove(id);
}

List<Lance> _sortByName(Iterable<Lance> lances) =>
    lances.toList()
      ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));

/// Where lances are saved. Tests override this with a MemoryLanceRepository.
final lanceRepositoryProvider = Provider<LanceRepository>(
  (ref) => FileLanceRepository.appSupport(),
);

/// The saved lances, sorted by name. Save and delete through the notifier so
/// every screen that watches the list sees the change.
class SavedLances extends AsyncNotifier<List<Lance>> {
  @override
  Future<List<Lance>> build() => ref.watch(lanceRepositoryProvider).loadAll();

  Future<void> save(Lance lance) async {
    await ref.read(lanceRepositoryProvider).save(lance);
    ref.invalidateSelf();
    await future;
  }

  Future<void> delete(String id) async {
    await ref.read(lanceRepositoryProvider).delete(id);
    ref.invalidateSelf();
    await future;
  }
}

final savedLancesProvider = AsyncNotifierProvider<SavedLances, List<Lance>>(
  SavedLances.new,
);
