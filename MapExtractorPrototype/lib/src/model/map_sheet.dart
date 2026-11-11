import 'dart:convert';

import 'hex_coord.dart';
import 'hex_terrain.dart';

/// The size and numbering of a map sheet.
///
/// A standard quad-fold sheet is 15 columns by 17 rows. Other sheets use
/// other sizes, so the size is always stored with the map.
class GridSpec {
  const GridSpec({required this.columns, required this.rows});

  static const standard = GridSpec(columns: 15, rows: 17);

  final int columns;
  final int rows;

  /// Numbering scheme: two-digit column then two-digit row.
  static const numbering = 'CCRR';

  /// Even-numbered columns sit half a hex lower than odd ones.
  static const layout = 'evenColumnsDown';

  int get hexCount => columns * rows;

  Iterable<HexCoord> get allHexes sync* {
    for (var c = 1; c <= columns; c++) {
      for (var r = 1; r <= rows; r++) {
        yield HexCoord(c, r);
      }
    }
  }

  Map<String, Object?> toJson() => {
        'columns': columns,
        'rows': rows,
        'numbering': numbering,
        'layout': layout,
      };

  factory GridSpec.fromJson(Map<String, Object?> json) => GridSpec(
        columns: (json['columns'] as num).toInt(),
        rows: (json['rows'] as num).toInt(),
      );

  @override
  bool operator ==(Object other) =>
      other is GridSpec && other.columns == columns && other.rows == rows;

  @override
  int get hashCode => Object.hash(columns, rows);
}

/// Immutable, saved form of one printed map sheet.
///
/// Only hexes that are not Clear appear in [hexes].
class MapSheet {
  MapSheet({
    required this.name,
    required this.grid,
    required Map<HexCoord, HexTerrain> hexes,
    Set<HexCoord> unverified = const {},
  })  : hexes = Map.unmodifiable({
          for (final e in hexes.entries)
            if (!e.value.isClear && e.key.isInside(grid.columns, grid.rows))
              e.key: e.value,
        }),
        unverified = Set.unmodifiable(unverified);

  static const formatName = 'btmap';
  static const formatVersion = 1;

  final String name;
  final GridSpec grid;
  final Map<HexCoord, HexTerrain> hexes;

  /// Hexes that the extractor flagged and nobody has checked yet. A map
  /// with an empty set is fully verified.
  final Set<HexCoord> unverified;

  HexTerrain terrainAt(HexCoord hex) => hexes[hex] ?? HexTerrain.clear;

  Map<String, Object?> toJson() {
    final sorted = hexes.keys.toList()..sort();
    final review = unverified.toList()..sort();
    return {
      'format': formatName,
      'version': formatVersion,
      'name': name,
      'grid': grid.toJson(),
      'hexes': {for (final h in sorted) h.id: hexes[h]!.toJson()},
      if (review.isNotEmpty) 'unverified': [for (final h in review) h.id],
    };
  }

  String toJsonString() => const JsonEncoder.withIndent('  ').convert(toJson());

  factory MapSheet.fromJson(Map<String, Object?> json) {
    if (json['format'] != formatName) {
      throw const FormatException('Not a btmap file.');
    }
    final version = (json['version'] as num?)?.toInt() ?? 0;
    if (version > formatVersion) {
      throw FormatException('btmap version $version is newer than this app.');
    }
    final hexJson = (json['hexes'] as Map?)?.cast<String, Object?>() ?? {};
    return MapSheet(
      name: (json['name'] as String?) ?? '',
      grid: GridSpec.fromJson((json['grid'] as Map).cast<String, Object?>()),
      hexes: {
        for (final e in hexJson.entries)
          HexCoord.tryParse(e.key)!:
              HexTerrain.fromJson((e.value as Map).cast<String, Object?>()),
      },
      unverified: {
        for (final id in (json['unverified'] as List?) ?? const [])
          HexCoord.tryParse(id as String)!,
      },
    );
  }

  factory MapSheet.fromJsonString(String s) =>
      MapSheet.fromJson((jsonDecode(s) as Map).cast<String, Object?>());
}
