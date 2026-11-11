import '../model/hex_coord.dart';
import '../model/hex_terrain.dart';
import '../model/map_sheet.dart';
import 'image_extractor.dart';
import 'label_parser.dart';

/// Result of combining one or more image extractions.
class MergedMap {
  MergedMap(this.grid, this.terrain, this.review, this.evidence);

  final GridSpec grid;
  final Map<HexCoord, HexTerrain> terrain;

  /// Hexes the user must check: uncertain digits, conflicts between
  /// images, or WATER without a depth.
  final Set<HexCoord> review;

  /// OCR evidence per hex, for the inspector panel.
  final Map<HexCoord, List<HexEvidence>> evidence;
}

/// One OCR reading that contributed to a hex.
class HexEvidence {
  const HexEvidence({
    required this.photo,
    required this.source,
    required this.rawText,
    required this.token,
    required this.score,
  });

  /// Photo number as shown in the UI, starting at 1.
  final int photo;

  /// File name of the photo.
  final String source;
  final String rawText;
  final LabelToken token;
  final double score;

  /// For example: "LEVELB" -> LEVEL 8 (uncertain) 0.19
  String get line => '"$rawText" -> ${token.key}'
      '${token.certain ? '' : ' (uncertain)'}  ${score.toStringAsFixed(2)}';
}

/// Votes per hex across images, the same way as merge() in
/// tool/reference_pipeline.py.
///
/// Each token gets the sum of its scores, halved for uncertain readings.
/// Each slot (LEVEL, DEPTH, or a plain word) keeps its best token. A hex
/// needs review when its winning token was never read with certainty or
/// when another token for the same slot also got votes.
///
/// [photoNumbers] gives the UI photo number of each result. The default is
/// the position in [results] plus one.
MergedMap mergeExtractions(
  List<ImageExtraction> results, {
  GridSpec? grid,
  List<int>? photoNumbers,
}) {
  var cols = 1, rows = 1;
  for (final r in results) {
    if (r.maxCol > cols) cols = r.maxCol;
    if (r.maxRow > rows) rows = r.maxRow;
  }
  final spec = grid ?? GridSpec(columns: cols, rows: rows);

  // hex -> token key -> (weight, everCertain, token)
  final votes = <HexCoord, Map<String, (double, bool, LabelToken)>>{};
  final evidence = <HexCoord, List<HexEvidence>>{};
  for (var i = 0; i < results.length; i++) {
    final res = results[i];
    final photo = photoNumbers?[i] ?? i + 1;
    for (final entry in res.readings.entries) {
      final hex = entry.key;
      final best = <String, (double, bool, LabelToken)>{};
      for (final reading in entry.value) {
        final t = reading.token;
        final w = t.certain ? reading.score : 0.5 * reading.score;
        final prev = best[t.key];
        if (prev == null || w > prev.$1) best[t.key] = (w, t.certain, t);
        evidence.putIfAbsent(hex, () => []).add(HexEvidence(
              photo: photo,
              source: res.name,
              rawText: reading.rawText,
              token: t,
              score: reading.score,
            ));
      }
      final hv = votes.putIfAbsent(hex, () => {});
      for (final e in best.entries) {
        final prev = hv[e.key];
        hv[e.key] = prev == null
            ? e.value
            : (prev.$1 + e.value.$1, prev.$2 || e.value.$2, prev.$3);
      }
    }
  }

  final terrain = <HexCoord, HexTerrain>{};
  final review = <HexCoord>{};
  for (final entry in votes.entries) {
    final hex = entry.key;
    if (!hex.isInside(spec.columns, spec.rows)) continue;
    final slots = <String, List<(double, bool, LabelToken)>>{};
    for (final v in entry.value.values) {
      slots.putIfAbsent(v.$3.word, () => []).add(v);
    }
    var t = HexTerrain.clear;
    var needsReview = false;
    for (final cands in slots.values) {
      var known = cands.where((c) => !c.$3.isUnknownNumber).toList();
      if (known.isEmpty) known = cands;
      known.sort((a, b) => b.$1.compareTo(a.$1));
      final (_, certain, token) = known.first;
      if (!certain || known.length > 1) needsReview = true;
      t = _apply(t, token);
      if (token.word == 'WATER' && t.waterDepth == 0) needsReview = true;
    }
    if (t.waterDepth == 0 && slots.containsKey('WATER')) {
      t = t.copyWith(waterDepth: 1);
    }
    terrain[hex] = t;
    if (needsReview) review.add(hex);
  }
  return MergedMap(spec, terrain, review, evidence);
}

HexTerrain _apply(HexTerrain t, LabelToken token) {
  switch (token.word) {
    case 'LEVEL':
      return token.number == null ? t : t.copyWith(level: token.number);
    case 'DEPTH':
      return token.number == null ? t : t.copyWith(waterDepth: token.number);
    case 'LIGHT':
      return t.woods == Woods.none ? t.copyWith(woods: Woods.light) : t;
    case 'HEAVY':
      return t.woods == Woods.ultraHeavy ? t : t.copyWith(woods: Woods.heavy);
    case 'ULTRA':
      return t.copyWith(woods: Woods.ultraHeavy);
    case 'ROUGH':
      return t.toggleOn(TerrainFeature.rough);
    case 'RUBBLE':
      return t.toggleOn(TerrainFeature.rubble);
    case 'PAVEMENT':
    case 'PAVED':
      return t.toggleOn(TerrainFeature.pavement);
    case 'ROAD':
      return t.toggleOn(TerrainFeature.road);
    case 'SWAMP':
      return t.toggleOn(TerrainFeature.swamp);
    case 'SAND':
      return t.toggleOn(TerrainFeature.sand);
    case 'ICE':
      return t.toggleOn(TerrainFeature.ice);
    case 'BUILDING':
      return t.toggleOn(TerrainFeature.building);
    case 'BRIDGE':
      return t.toggleOn(TerrainFeature.bridge);
    default:
      return t;
  }
}

extension on HexTerrain {
  HexTerrain toggleOn(TerrainFeature f) =>
      features.contains(f) ? this : copyWith(features: {...features, f});
}
