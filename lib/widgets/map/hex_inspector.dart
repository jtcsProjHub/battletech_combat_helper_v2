// File: lib/widgets/map/hex_inspector.dart
// Editor for the selected hexes. With several hexes selected, every edit
// applies to all of them. Photos and OCR evidence show the primary hex.
// Ported from the Map Extractor prototype. The skirmish setup editor can
// reuse this panel, with a second section for per-skirmish items such as
// placed buildings.

import 'package:flutter/material.dart';
import 'package:map_extractor_prototype/map_extractor.dart';

import '../../app_theme.dart';
import '../../maps/hex_layout.dart';
import '../../maps/hex_selection.dart';
import '../../maps/map_editor_controller.dart';
import '../../maps/map_sheet_draft.dart';
import '../hud.dart';
import 'source_overlay_view.dart';

/// Square-cornered button shape used across the map screens.
const mapButtonShape = RoundedRectangleBorder(
  borderRadius: BorderRadius.all(Radius.circular(2)),
);

const mapButtonText = TextStyle(
  fontSize: 14,
  fontWeight: FontWeight.w700,
  letterSpacing: 1.2,
);

const _body = TextStyle(
  fontSize: 14,
  height: 1.45,
  color: AppColors.textSecondary,
);
const _hint = TextStyle(fontSize: 13, height: 1.4, color: AppColors.textDim);

class HexInspector extends StatelessWidget {
  const HexInspector({
    super.key,
    required this.draft,
    required this.selection,
    required this.sources,
    required this.onNextToReview,
    required this.onAccept,
  });

  final MapSheetDraft draft;
  final HexSelection selection;
  final List<SourceEntry> sources;
  final VoidCallback onNextToReview;
  final VoidCallback onAccept;

  @override
  Widget build(BuildContext context) {
    final toReview = draft.toReviewCount;
    final next = OutlinedButton.icon(
      onPressed: toReview == 0 ? null : onNextToReview,
      style: OutlinedButton.styleFrom(
        minimumSize: const Size.fromHeight(44),
        shape: mapButtonShape,
        foregroundColor: TerrainStyle.review,
        side: BorderSide(
          color: toReview == 0 ? AppColors.border : TerrainStyle.review,
        ),
      ),
      icon: const Icon(Icons.skip_next),
      label: Text('NEXT TO REVIEW ($toReview)', style: mapButtonText),
    );
    final hexes = selection.hexes.toList()..sort();
    final primary = selection.primary;
    if (hexes.isEmpty || primary == null) {
      return ListView(
        padding: const EdgeInsets.all(20),
        children: [
          const Text('HEX INSPECTOR', style: HudText.sectionLabel),
          const SizedBox(height: 12),
          next,
          const SizedBox(height: 20),
          const Text(
            'Select hexes on the map or on a photo to edit them.',
            style: _body,
          ),
          const SizedBox(height: 12),
          const Text(
            'Click selects one hex. Ctrl+click adds or removes a hex. '
            'Shift+click selects the block from the last clicked hex. '
            'Use the box or brush tool to drag a selection. '
            'Ctrl+A selects all. Esc clears.',
            style: _hint,
          ),
        ],
      );
    }

    final terrains = [for (final h in hexes) draft.terrainAt(h)];
    final multi = hexes.length > 1;
    final anyReview = hexes.any(draft.needsReview);
    T? common<T>(T Function(HexTerrain) f) {
      final v = f(terrains.first);
      return terrains.every((t) => f(t) == v) ? v : null;
    }

    final woods = common((t) => t.woods);
    final level = common((t) => t.level);
    final depth = common((t) => t.waterDepth);
    final primaryTerrain = draft.terrainAt(primary);
    void edit(HexTerrain Function(HexTerrain) f) =>
        draft.updateTerrain(hexes, f);

    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        const Text('HEX INSPECTOR', style: HudText.sectionLabel),
        const SizedBox(height: 12),
        next,
        const SizedBox(height: 20),
        Row(
          children: [
            Expanded(
              child: Text(
                multi ? '${hexes.length} HEXES' : 'HEX ${primary.id}',
                style: const TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1,
                  color: AppColors.accent,
                ),
              ),
            ),
            if (anyReview)
              FilledButton.icon(
                onPressed: onAccept,
                style: FilledButton.styleFrom(shape: mapButtonShape),
                icon: const Icon(Icons.check, size: 18),
                label: const Text('LOOKS RIGHT', style: mapButtonText),
              )
            else
              TextButton(
                onPressed: () => draft.setVerifiedAll(hexes, false),
                style: TextButton.styleFrom(
                  shape: mapButtonShape,
                  foregroundColor: AppColors.textDim,
                ),
                child: const Text('FLAG', style: mapButtonText),
              ),
          ],
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
        if (anyReview)
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Text(
              multi
                  ? 'The extractor was not sure about some of these hexes.'
                  : 'The extractor was not sure about this hex.',
              style: const TextStyle(fontSize: 13, color: TerrainStyle.review),
            ),
          ),
        const SizedBox(height: 20),
        _Label(woods == null ? 'Woods (mixed)' : 'Woods'),
        SegmentedButton<Woods>(
          segments: const [
            ButtonSegment(value: Woods.none, label: Text('None')),
            ButtonSegment(value: Woods.light, label: Text('Light')),
            ButtonSegment(value: Woods.heavy, label: Text('Heavy')),
            ButtonSegment(value: Woods.ultraHeavy, label: Text('Ultra')),
          ],
          selected: {?woods},
          emptySelectionAllowed: true,
          onSelectionChanged: (s) {
            if (s.isNotEmpty) edit((t) => t.copyWith(woods: s.first));
          },
          showSelectedIcon: false,
          style: _segmentStyle,
        ),
        const SizedBox(height: 16),
        _Stepper(
          label: 'Level',
          value: level ?? primaryTerrain.level,
          mixed: level == null,
          min: -6,
          max: 10,
          onChanged: (v) => edit((t) => t.copyWith(level: v)),
        ),
        _Stepper(
          label: 'Water depth',
          value: depth ?? primaryTerrain.waterDepth,
          mixed: depth == null,
          min: 0,
          max: 6,
          onChanged: (v) => edit((t) => t.copyWith(waterDepth: v)),
        ),
        const SizedBox(height: 12),
        const _Label('Features'),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: [
            for (final f in TerrainFeature.values)
              _FeatureChip(
                feature: f,
                all: terrains.every((t) => t.features.contains(f)),
                some: terrains.any((t) => t.features.contains(f)),
                onToggle: (all) => edit(
                  (t) => t.copyWith(
                    features: all
                        ? ({...t.features}..remove(f))
                        : {...t.features, f},
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 16),
        OutlinedButton.icon(
          onPressed: terrains.every((t) => t.isClear)
              ? null
              : () => edit((_) => HexTerrain.clear),
          style: OutlinedButton.styleFrom(
            minimumSize: const Size.fromHeight(40),
            shape: mapButtonShape,
            foregroundColor: AppColors.textSecondary,
            side: const BorderSide(color: AppColors.borderStrong),
          ),
          icon: const Icon(Icons.layers_clear, size: 18),
          label: Text(
            multi ? 'SET ALL TO CLEAR' : 'SET TO CLEAR',
            style: mapButtonText,
          ),
        ),
        const SizedBox(height: 24),
        ..._photoEvidence(primary, multi),
      ],
    );
  }

  static final _segmentStyle = SegmentedButton.styleFrom(
    shape: mapButtonShape,
    selectedBackgroundColor: AppColors.accent,
    selectedForegroundColor: AppColors.background,
    foregroundColor: AppColors.textSecondary,
    side: const BorderSide(color: AppColors.borderStrong),
    visualDensity: VisualDensity.compact,
  );

  /// One section per photo that shows [hex]: a close-up and the OCR lines
  /// read from that photo.
  List<Widget> _photoEvidence(HexCoord hex, bool multi) {
    if (sources.isEmpty) return const [];
    final evidence = draft.evidenceFor(hex);
    const mono = TextStyle(
      fontSize: 12,
      fontFamily: 'monospace',
      color: AppColors.textSecondary,
    );
    final out = <Widget>[
      Text(
        multi ? 'PHOTO EVIDENCE · ${hex.id}' : 'PHOTO EVIDENCE',
        style: HudText.sectionLabel,
      ),
      const SizedBox(height: 10),
    ];
    var shown = 0;
    for (var i = 0; i < sources.length; i++) {
      final s = sources[i];
      final photo = i + 1;
      final lines = evidence.where((e) => e.photo == photo).toList();
      final covered = HexPhotoCrop.covers(s, hex);
      if (!covered && lines.isEmpty) continue;
      shown++;
      out
        ..add(
          Text(
            'Photo $photo  ·  ${s.name}',
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: AppColors.text,
            ),
            overflow: TextOverflow.ellipsis,
          ),
        )
        ..add(const SizedBox(height: 6));
      if (covered) {
        out
          ..add(HexPhotoCrop(source: s, hex: hex))
          ..add(const SizedBox(height: 6));
      }
      if (lines.isEmpty) {
        out.add(const Text('No label text read in this hex.', style: _hint));
      } else {
        for (final e in lines) {
          out.add(
            Padding(
              padding: const EdgeInsets.only(bottom: 2),
              child: Text(e.line, style: mono),
            ),
          );
        }
      }
      out.add(const SizedBox(height: 16));
    }
    if (shown == 0) {
      out.add(const Text('No photo covers this hex.', style: _hint));
    }
    return out;
  }
}

class _Label extends StatelessWidget {
  const _Label(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Text(text.toUpperCase(), style: HudText.sectionLabel),
  );
}

class _FeatureChip extends StatelessWidget {
  const _FeatureChip({
    required this.feature,
    required this.all,
    required this.some,
    required this.onToggle,
  });

  final TerrainFeature feature;
  final bool all;
  final bool some;

  /// Called with [all]: true removes the feature, false adds it.
  final ValueChanged<bool> onToggle;

  @override
  Widget build(BuildContext context) {
    final name = feature.name[0].toUpperCase() + feature.name.substring(1);
    return FilterChip(
      label: Text(some && !all ? '$name (some)' : name),
      selected: all,
      showCheckmark: false,
      onSelected: (_) => onToggle(all),
      shape: mapButtonShape,
      side: BorderSide(color: all ? AppColors.accent : AppColors.chipBorder),
      backgroundColor: AppColors.panelRaised,
      selectedColor: AppColors.accent.withAlpha(48),
      labelStyle: TextStyle(
        fontSize: 13,
        color: all ? AppColors.accent : AppColors.textSecondary,
      ),
      visualDensity: VisualDensity.compact,
    );
  }
}

class _Stepper extends StatelessWidget {
  const _Stepper({
    required this.label,
    required this.value,
    required this.mixed,
    required this.min,
    required this.max,
    required this.onChanged,
  });

  final String label;
  final int value;
  final bool mixed;
  final int min;
  final int max;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            (mixed ? '$label (mixed)' : label).toUpperCase(),
            style: HudText.sectionLabel,
          ),
        ),
        IconButton(
          tooltip: 'Decrease $label',
          onPressed: value > min ? () => onChanged(value - 1) : null,
          icon: const Icon(Icons.remove),
        ),
        Container(
          width: 40,
          height: 32,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: AppColors.panelRaised,
            border: Border.all(color: AppColors.cellBorder),
          ),
          child: Text(
            mixed ? '–' : '$value',
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: AppColors.text,
            ),
          ),
        ),
        IconButton(
          tooltip: 'Increase $label',
          onPressed: value < max ? () => onChanged(value + 1) : null,
          icon: const Icon(Icons.add),
        ),
      ],
    );
  }
}
