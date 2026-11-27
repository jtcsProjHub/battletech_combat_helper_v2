// File: lib/maps/extractor_bridge.dart
// Converts between the Map Extractor prototype's map types and the app's own
// (map_model.dart). Only the server-side map import flow uses this; the rest
// of the app never sees the extractor's types. Both sides share the btmap
// JSON, so terrain converts through it.

import 'package:map_extractor_prototype/map_extractor.dart' as ext;

import 'map_model.dart';

extension ExtractorHexCoordToApp on ext.HexCoord {
  HexCoord toApp() => HexCoord(col, row);
}

extension AppHexCoordToExtractor on HexCoord {
  ext.HexCoord toExtractor() => ext.HexCoord(col, row);
}

extension ExtractorHexTerrainToApp on ext.HexTerrain {
  HexTerrain toApp() => HexTerrain.fromJson(toJson());
}

extension ExtractorGridSpecToApp on ext.GridSpec {
  GridSpec toApp() => GridSpec(columns: columns, rows: rows);
}
