// File: lib/widgets/skirmish/skirmish_map_inspector.dart
// Inspector for the skirmish map editor. Edits this skirmish's overlay on
// the selected hexes, never the printed sheet. Three independent layers:
//   - Level: an absolute level, uniform across the selection.
//   - Building: a placed building with its height in levels; the hex
//     plays as empty level 0 ground under it.
//   - Environment: woods, water, and features.
// Each edit goes through [onEdit] with a short label, so the screen can
// record it for undo.

import 'package:flutter/material.dart';
import '../../maps/map_model.dart';

import '../../app_theme.dart';
import '../../maps/hex_selection.dart';
import '../../skirmish/skirmish_map.dart';
import '../hud.dart';
import '../map/inspector_controls.dart';
import 'skirmish_map_view.dart';

const _body = TextStyle(
  fontSize: 14,
  height: 1.45,
  color: AppColors.textSecondary,
);
const _hint = TextStyle(fontSize: 13, height: 1.4, color: AppColors.textDim);

/// Features offered in the environment section. Buildings have their own
/// layer.
final _environmentFeatures = [
  for (final f in TerrainFeature.values)
    if (f != TerrainFeature.building) f,
];

/// Applies [change] to the map and records it under [label].
typedef SkirmishMapEdit =
    void Function(String label, void Function(SkirmishMap map) change);

class SkirmishMapInspector extends StatelessWidget {
  const SkirmishMapInspector({
    super.key,
    required this.map,
    required this.selection,
    required this.onEdit,
  });

  final SkirmishMap map;
  final HexSelection selection;
  final SkirmishMapEdit onEdit;

  /// The level layer: the override, or the printed level.
  /// Highest building height the stepper offers.
  static const maxBuildingHeight = 20;

  static int levelOf(SkirmishMap map, HexCoord hex) =>
      map.overlayAt(hex).level ?? map.source.sheet.terrainAt(hex).level;

  @override
  Widget build(BuildContext context) {
    final hexes = selection.hexes.toList()..sort();
    final primary = selection.primary;
    if (hexes.isEmpty || primary == null) return _empty();

    final multi = hexes.length > 1;
    final where = multi ? '${hexes.length} hexes' : primary.id;
    void edit(String what, void Function(SkirmishMap) change) =>
        onEdit('$what · $where', change);

    final overlays = [for (final h in hexes) map.overlayAt(h)];
    final printed = [for (final h in hexes) map.source.sheet.terrainAt(h)];
    final envs = [for (final h in hexes) map.environmentAt(h)];
    final levels = [for (final h in hexes) levelOf(map, h)];
    T? common<T>(List<T> values) =>
        values.every((v) => v == values.first) ? values.first : null;

    final changed = overlays.where((o) => !o.isEmpty).length;
    final allBuilding = overlays.every((o) => o.building);
    final someBuilding = overlays.any((o) => o.building);
    final buildingHexes = [
      for (final h in hexes)
        if (map.overlayAt(h).building) h,
    ];
    final heights = [for (final h in buildingHexes) map.buildingHeightAt(h)!];
    final height = heights.isEmpty ? null : common(heights);
    final level = common(levels);
    final printedLevel = common([for (final t in printed) t.level]);
    final woods = common([for (final e in envs) e.woods]);
    final depth = common([for (final e in envs) e.waterDepth]);

    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        const Text('HEX INSPECTOR', style: HudText.sectionLabel),
        const SizedBox(height: 12),
        Text(
          multi ? '${hexes.length} HEXES' : 'HEX ${primary.id}',
          style: const TextStyle(
            fontSize: 26,
            fontWeight: FontWeight.w700,
            letterSpacing: 1,
            color: AppColors.accent,
          ),
        ),
        if (multi)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              hexes.length <= 12
                  ? hexes.map((h) => h.id).join(', ')
                  : '${hexes.take(12).map((h) => h.id).join(', ')} ...',
              style: _hint,
            ),
          ),
        Padding(
          padding: const EdgeInsets.only(top: 6),
          child: Text(
            changed == 0
                ? 'As printed.'
                : multi
                ? '$changed changed for this skirmish.'
                : 'Changed for this skirmish.',
            style: TextStyle(
              fontSize: 13,
              color: changed == 0 ? AppColors.textDim : overlayMarkColorLight,
            ),
          ),
        ),

        // --- Level --------------------------------------------------------
        const SizedBox(height: 20),
        _SectionHeader(
          title: 'Level',
          onReset: overlays.any((o) => o.level != null)
              ? () => edit('Printed level', (m) => m.setLevel(hexes, null))
              : null,
        ),
        InspectorStepper(
          label: 'Level',
          value: level ?? levelOf(map, primary),
          mixed: level == null,
          min: -6,
          max: 10,
          onChanged: allBuilding
              ? null
              : (v) => edit('Level $v', (m) => m.setLevel(hexes, v)),
        ),
        Text(
          allBuilding
              ? 'A building stands on level 0 ground.'
              : printedLevel == null
              ? 'Printed levels differ.'
              : 'Printed level $printedLevel.',
          style: _hint,
        ),

        // --- Building -----------------------------------------------------
        const SizedBox(height: 20),
        const InspectorLabel('Building'),
        FilterChip(
          label: Text(
            someBuilding && !allBuilding ? 'Building (some)' : 'Building',
          ),
          avatar: Icon(
            Icons.apartment,
            size: 18,
            color: allBuilding ? AppColors.accent : AppColors.textSecondary,
          ),
          selected: allBuilding,
          showCheckmark: false,
          onSelected: (_) => edit(
            allBuilding ? 'Remove building' : 'Place building',
            (m) => m.setBuilding(hexes, !allBuilding),
          ),
          shape: mapButtonShape,
          side: BorderSide(
            color: allBuilding ? AppColors.accent : AppColors.chipBorder,
          ),
          backgroundColor: AppColors.panelRaised,
          selectedColor: AppColors.accent.withAlpha(48),
          labelStyle: TextStyle(
            fontSize: 13,
            color: allBuilding ? AppColors.accent : AppColors.textSecondary,
          ),
        ),
        if (someBuilding) ...[
          const SizedBox(height: 12),
          InspectorStepper(
            label: 'Building height',
            value: height ?? heights.first,
            mixed: height == null,
            min: 1,
            max: SkirmishMapInspector.maxBuildingHeight,
            onChanged: (v) => onEdit(
              'Height $v · ${buildingHexes.length > 1 ? '${buildingHexes.length} buildings' : buildingHexes.single.id}',
              (m) => m.setBuildingHeight(buildingHexes, v),
            ),
          ),
          Text(
            allBuilding
                ? 'Levels the building rises above the ground.'
                : 'Applies to the ${buildingHexes.length} selected '
                      'building ${buildingHexes.length == 1 ? 'hex' : 'hexes'}.',
            style: _hint,
          ),
        ],
        const SizedBox(height: 6),
        const Text(
          'The hex plays as empty level 0 ground with the building on it. '
          'Removing the building brings back the terrain below.',
          style: _hint,
        ),

        // --- Environment --------------------------------------------------
        const SizedBox(height: 20),
        _SectionHeader(
          title: woods == null ? 'Woods (mixed)' : 'Woods',
          onReset: overlays.any((o) => o.environment != null)
              ? () => edit(
                  'Printed terrain',
                  (m) => m.setEnvironment(hexes, null),
                )
              : null,
          resetLabel: 'PRINTED TERRAIN',
        ),
        if (allBuilding)
          const Padding(
            padding: EdgeInsets.only(bottom: 8),
            child: Text(
              'Covered by a building. Remove it to change the terrain.',
              style: _hint,
            ),
          ),
        WoodsSelector(
          value: woods,
          onChanged: allBuilding
              ? null
              : (w) => edit(
                  'Woods ${w.name}',
                  (m) =>
                      m.updateEnvironment(hexes, (e) => e.copyWith(woods: w)),
                ),
        ),
        const SizedBox(height: 16),
        InspectorStepper(
          label: 'Water depth',
          value: depth ?? map.environmentAt(primary).waterDepth,
          mixed: depth == null,
          min: 0,
          max: 6,
          onChanged: allBuilding
              ? null
              : (v) => edit(
                  'Water depth $v',
                  (m) => m.updateEnvironment(
                    hexes,
                    (e) => e.copyWith(waterDepth: v),
                  ),
                ),
        ),
        const SizedBox(height: 12),
        const InspectorLabel('Features'),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: [
            for (final f in _environmentFeatures)
              FeatureChip(
                feature: f,
                all: envs.every((e) => e.features.contains(f)),
                some: envs.any((e) => e.features.contains(f)),
                onToggle: allBuilding
                    ? null
                    : (all) => edit(
                        '${all ? 'Remove' : 'Add'} ${f.name}',
                        (m) => m.updateEnvironment(
                          hexes,
                          (e) => e.copyWith(
                            features: all
                                ? ({...e.features}..remove(f))
                                : {...e.features, f},
                          ),
                        ),
                      ),
              ),
          ],
        ),

        const SizedBox(height: 24),
        OutlinedButton.icon(
          onPressed: changed == 0
              ? null
              : () => edit('Reset to printed', (m) => m.clear(hexes)),
          style: OutlinedButton.styleFrom(
            minimumSize: const Size.fromHeight(40),
            shape: mapButtonShape,
            foregroundColor: AppColors.textSecondary,
            side: const BorderSide(color: AppColors.borderStrong),
          ),
          icon: const Icon(Icons.restart_alt, size: 18),
          label: Text(
            multi ? 'RESET ALL TO PRINTED' : 'RESET TO PRINTED',
            style: mapButtonText,
          ),
        ),
      ],
    );
  }

  Widget _empty() => ListView(
    padding: const EdgeInsets.all(20),
    children: const [
      Text('HEX INSPECTOR', style: HudText.sectionLabel),
      SizedBox(height: 12),
      Text(
        'Select hexes to change them for this skirmish: place buildings, '
        'set levels, or change woods and water to match the table. The '
        'saved map is not changed.',
        style: _body,
      ),
      SizedBox(height: 12),
      Text(
        'Click selects one hex. Ctrl+click adds or removes a hex. '
        'Shift+click selects the block from the last clicked hex. '
        'Use the box or brush tool to drag a selection. '
        'Ctrl+A selects all. Esc clears.',
        style: _hint,
      ),
      SizedBox(height: 12),
      Text(
        '+ and − set the level, or the height when only buildings are '
        'selected. Delete resets the selection to printed. '
        'Ctrl+Z undoes, Ctrl+Shift+Z or Ctrl+Y redoes.',
        style: _hint,
      ),
    ],
  );
}

/// A section label with an optional reset-to-printed button on the right.
class _SectionHeader extends StatelessWidget {
  const _SectionHeader({
    required this.title,
    required this.onReset,
    this.resetLabel = 'PRINTED',
  });

  final String title;
  final VoidCallback? onReset;
  final String resetLabel;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(child: InspectorLabel(title)),
        if (onReset != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: TextButton(
              onPressed: onReset,
              style: TextButton.styleFrom(
                shape: mapButtonShape,
                foregroundColor: AppColors.textDim,
                visualDensity: VisualDensity.compact,
              ),
              child: Text(resetLabel, style: const TextStyle(fontSize: 12)),
            ),
          ),
      ],
    );
  }
}
