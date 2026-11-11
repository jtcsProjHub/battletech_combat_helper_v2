import 'package:flutter/material.dart';

import '../model/hex_coord.dart';
import '../model/hex_terrain.dart';
import 'extractor_controller.dart';
import 'hex_photo_crop.dart';
import 'hex_selection.dart';
import 'map_sheet_draft.dart';

/// Editor for the selected hexes. With several hexes selected, every edit
/// applies to all of them. Photos and OCR evidence show the primary hex.
///
/// The setup editor in the main app can reuse this panel, with a second
/// section for per-skirmish items such as buildings.
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
    final theme = Theme.of(context);
    final toReview = draft.unverified.length;
    final next = FilledButton.tonalIcon(
      onPressed: toReview == 0 ? null : onNextToReview,
      icon: const Icon(Icons.skip_next),
      label: Text('Next to review ($toReview)'),
    );
    final hexes = selection.hexes.toList()..sort();
    final primary = selection.primary;
    if (hexes.isEmpty || primary == null) {
      return Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            next,
            const SizedBox(height: 16),
            Text('Select hexes on the map or on a photo to edit them.',
                style: theme.textTheme.bodyMedium),
            const SizedBox(height: 12),
            Text(
                'Click selects one hex. Ctrl+click adds or removes a hex. '
                'Shift+click selects the block from the last clicked hex. '
                'Use the box or brush tool to drag a selection. '
                'Ctrl+A selects all. Esc clears.',
                style: theme.textTheme.bodySmall),
          ],
        ),
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
    void edit(HexTerrain Function(HexTerrain) f) => draft.updateTerrain(hexes, f);

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        next,
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: Text(
                multi ? '${hexes.length} hexes' : 'Hex ${primary.id}',
                style: theme.textTheme.headlineSmall,
              ),
            ),
            if (anyReview)
              FilledButton.icon(
                onPressed: onAccept,
                icon: const Icon(Icons.check),
                label: const Text('Looks right'),
              )
            else
              TextButton(
                onPressed: () => draft.setVerifiedAll(hexes, false),
                child: const Text('Flag'),
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
              style: theme.textTheme.bodySmall,
            ),
          ),
        if (anyReview)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
                multi
                    ? 'The extractor was not sure about some of these hexes.'
                    : 'The extractor was not sure about this hex.',
                style: TextStyle(color: theme.colorScheme.tertiary)),
          ),
        const SizedBox(height: 16),
        Text(woods == null ? 'Woods (mixed)' : 'Woods',
            style: theme.textTheme.titleSmall),
        const SizedBox(height: 6),
        SegmentedButton<Woods>(
          segments: const [
            ButtonSegment(value: Woods.none, label: Text('None')),
            ButtonSegment(value: Woods.light, label: Text('Light')),
            ButtonSegment(value: Woods.heavy, label: Text('Heavy')),
            ButtonSegment(value: Woods.ultraHeavy, label: Text('Ultra')),
          ],
          selected: {if (woods != null) woods},
          emptySelectionAllowed: true,
          onSelectionChanged: (s) {
            if (s.isNotEmpty) edit((t) => t.copyWith(woods: s.first));
          },
          showSelectedIcon: false,
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
        Text('Features', style: theme.textTheme.titleSmall),
        const SizedBox(height: 6),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: [
            for (final f in TerrainFeature.values)
              () {
                final all = terrains.every((t) => t.features.contains(f));
                final some = terrains.any((t) => t.features.contains(f));
                return FilterChip(
                  label: Text(f.name[0].toUpperCase() + f.name.substring(1) +
                      (some && !all ? ' (some)' : '')),
                  selected: all,
                  onSelected: (_) => edit((t) => t.copyWith(
                      features: all
                          ? ({...t.features}..remove(f))
                          : {...t.features, f})),
                );
              }(),
          ],
        ),
        const SizedBox(height: 12),
        OutlinedButton.icon(
          onPressed: terrains.every((t) => t.isClear)
              ? null
              : () => edit((_) => HexTerrain.clear),
          icon: const Icon(Icons.layers_clear),
          label: Text(multi ? 'Set all to Clear' : 'Set to Clear'),
        ),
        const SizedBox(height: 20),
        ..._photoEvidence(context, primary, multi),
      ],
    );
  }

  /// One section per photo that shows [hex]: a close-up and the OCR lines
  /// read from that photo.
  List<Widget> _photoEvidence(BuildContext context, HexCoord hex, bool multi) {
    final theme = Theme.of(context);
    final evidence = draft.evidenceFor(hex);
    final mono = theme.textTheme.bodySmall?.copyWith(fontFamily: 'monospace');
    final out = <Widget>[
      Text(multi ? 'Photos and OCR evidence for ${hex.id}' : 'Photos and OCR evidence',
          style: theme.textTheme.titleSmall),
      const SizedBox(height: 8),
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
        ..add(Text('Photo $photo  ·  ${s.name}',
            style: theme.textTheme.labelLarge, overflow: TextOverflow.ellipsis))
        ..add(const SizedBox(height: 6));
      if (covered) {
        out
          ..add(HexPhotoCrop(source: s, hex: hex))
          ..add(const SizedBox(height: 6));
      }
      if (lines.isEmpty) {
        out.add(Text('No label text read in this hex.', style: theme.textTheme.bodySmall));
      } else {
        for (final e in lines) {
          out.add(Padding(
            padding: const EdgeInsets.only(bottom: 2),
            child: Text(e.line, style: mono),
          ));
        }
      }
      out.add(const SizedBox(height: 16));
    }
    if (shown == 0) {
      out.add(Text('No photo covers this hex.', style: theme.textTheme.bodySmall));
    }
    return out;
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
        Expanded(child: Text(mixed ? '$label (mixed)' : label)),
        IconButton(
          onPressed: value > min ? () => onChanged(value - 1) : null,
          icon: const Icon(Icons.remove),
        ),
        SizedBox(
          width: 32,
          child: Text(mixed ? '–' : '$value',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleMedium),
        ),
        IconButton(
          onPressed: value < max ? () => onChanged(value + 1) : null,
          icon: const Icon(Icons.add),
        ),
      ],
    );
  }
}
