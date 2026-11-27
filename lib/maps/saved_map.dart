// File: lib/maps/saved_map.dart
// A saved map sheet and its id. Kept apart from map_repository.dart, which
// does the file I/O, so models such as Skirmish can use it without
// pulling in dart:io.

import 'map_model.dart';
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
