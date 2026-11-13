// File: lib/skirmish/skirmish_repository.dart
// Saving and loading skirmishes. Each skirmish is one JSON file named by its
// id, under the app support directory (~/.local/share/<app id>/skirmishes on
// Linux). Same layout and safety rules as the lance repository. Load
// Skirmish reads the list through savedSkirmishesProvider.

import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart' show debugPrint;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';

import 'skirmish.dart';

abstract interface class SkirmishRepository {
  /// Every saved skirmish, most recently saved first.
  Future<List<Skirmish>> loadAll();

  /// Adds the skirmish, or replaces the saved one with the same id.
  Future<void> save(Skirmish skirmish);

  /// Does nothing when no skirmish has this id.
  Future<void> delete(String id);
}

class FileSkirmishRepository implements SkirmishRepository {
  /// [directory] is resolved on first use, so building the repository does
  /// no I/O.
  FileSkirmishRepository(this._directory);

  /// The skirmishes folder under the app support directory.
  factory FileSkirmishRepository.appSupport() => FileSkirmishRepository(
    () async => Directory(
      '${(await getApplicationSupportDirectory()).path}'
      '${Platform.pathSeparator}skirmishes',
    ),
  );

  final Future<Directory> Function() _directory;

  static final _safeId = RegExp(r'^[A-Za-z0-9_-]+$');

  Future<File> _file(String id) async {
    if (!_safeId.hasMatch(id)) {
      throw ArgumentError.value(id, 'id', 'Not usable as a file name');
    }
    final dir = await _directory();
    return File('${dir.path}${Platform.pathSeparator}$id.json');
  }

  /// A file that does not parse is skipped and left on disk.
  @override
  Future<List<Skirmish>> loadAll() async {
    final dir = await _directory();
    if (!await dir.exists()) return [];
    final skirmishes = <Skirmish>[];
    await for (final entity in dir.list()) {
      if (entity is! File || !entity.path.endsWith('.json')) continue;
      try {
        final json = jsonDecode(await entity.readAsString());
        skirmishes.add(Skirmish.fromJson(json as Map<String, dynamic>));
      } on Object catch (e) {
        debugPrint('Skipped unreadable skirmish file ${entity.path}: $e');
      }
    }
    return _sortByRecent(skirmishes);
  }

  /// Writes a temporary file and renames it over the old one.
  @override
  Future<void> save(Skirmish skirmish) async {
    final file = await _file(skirmish.id);
    await file.parent.create(recursive: true);
    final temp = File('${file.path}.tmp');
    await temp.writeAsString(
      const JsonEncoder.withIndent('  ').convert(skirmish.toJson()),
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

/// Keeps skirmishes in memory only, as JSON so that a loaded skirmish is
/// never the same object a screen is still changing. Used by tests.
class MemorySkirmishRepository implements SkirmishRepository {
  final Map<String, Map<String, dynamic>> _json = {};

  @override
  Future<List<Skirmish>> loadAll() async => _sortByRecent([
    for (final j in _json.values) Skirmish.fromJson(jsonDecode(jsonEncode(j))),
  ]);

  @override
  Future<void> save(Skirmish skirmish) async =>
      _json[skirmish.id] = skirmish.toJson();

  @override
  Future<void> delete(String id) async => _json.remove(id);
}

List<Skirmish> _sortByRecent(Iterable<Skirmish> skirmishes) =>
    skirmishes.toList()..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));

/// Where skirmishes are saved. Tests override this with a
/// MemorySkirmishRepository.
final skirmishRepositoryProvider = Provider<SkirmishRepository>(
  (ref) => FileSkirmishRepository.appSupport(),
);

/// The saved skirmishes, most recent first. Save and delete through the
/// notifier so Load Skirmish sees the change.
class SavedSkirmishes extends AsyncNotifier<List<Skirmish>> {
  @override
  Future<List<Skirmish>> build() =>
      ref.watch(skirmishRepositoryProvider).loadAll();

  /// Stamps [Skirmish.updatedAt] and writes the skirmish.
  Future<void> save(Skirmish skirmish) async {
    skirmish.updatedAt = DateTime.now();
    await ref.read(skirmishRepositoryProvider).save(skirmish);
    ref.invalidateSelf();
  }

  Future<void> delete(String id) async {
    await ref.read(skirmishRepositoryProvider).delete(id);
    ref.invalidateSelf();
    await future;
  }
}

final savedSkirmishesProvider =
    AsyncNotifierProvider<SavedSkirmishes, List<Skirmish>>(SavedSkirmishes.new);
