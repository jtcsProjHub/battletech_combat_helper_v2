// File: lib/widgets/skirmish/skirmish_panels.dart
// Column contents shared by the skirmish setup steps: a player's chosen
// lance, the chosen map, and the strip of saved maps to pick from.

import 'package:flutter/material.dart';

import '../../app_theme.dart';
import '../../lance.dart';
import '../../maps/map_repository.dart';
import '../../mech_library.dart';
import '../hud.dart';
import '../lance_roster_detail.dart';
import '../map/hex_map_view.dart';
import '../map/saved_map_list.dart' show mapSummary;

const _bodyText = TextStyle(
  fontSize: 16,
  height: 1.5,
  color: AppColors.textSecondary,
);

/// Column heading: "PLAYER 1" over a line of help text.
class SkirmishColumnHeader extends StatelessWidget {
  const SkirmishColumnHeader({super.key, required this.label, this.help});

  final String label;
  final String? help;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(label.toUpperCase(), style: HudText.sectionLabel),
        if (help != null) ...[
          const SizedBox(height: 4),
          Text(
            help!,
            style: const TextStyle(fontSize: 14, color: AppColors.textDim),
          ),
        ],
      ],
    );
  }
}

/// A player's chosen lance in full, or a note that it is not chosen yet.
class PlayerLancePanel extends StatelessWidget {
  const PlayerLancePanel({
    super.key,
    required this.label,
    required this.lance,
    required this.library,
    this.emptyText = 'No lance chosen yet.',
  });

  final String label;
  final Lance? lance;
  final MechLibrary? library;
  final String emptyText;

  @override
  Widget build(BuildContext context) {
    final l = lance;
    final lib = library;
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        SkirmishColumnHeader(label: label),
        const SizedBox(height: 16),
        if (l == null)
          Text(emptyText, style: _bodyText)
        else if (lib == null)
          const Center(child: CircularProgressIndicator())
        else
          LanceRosterDetail(lance: l, library: lib),
      ],
    );
  }
}

/// The chosen map: name, size, and a thumbnail filling the space.
class MapPreview extends StatelessWidget {
  const MapPreview({super.key, required this.map});

  final SavedMap map;

  @override
  Widget build(BuildContext context) {
    final review = map.sheet.unverified.length;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          map.name.isEmpty ? 'UNTITLED MAP' : map.name.toUpperCase(),
          style: HudText.panelTitle,
        ),
        const SizedBox(height: 4),
        Text(
          mapSummary(map),
          style: const TextStyle(fontSize: 15, color: AppColors.textDim),
        ),
        if (review > 0)
          const Padding(
            padding: EdgeInsets.only(top: 4),
            child: Text(
              'Some hexes were never reviewed. Check them against the '
              'table before play.',
              style: TextStyle(fontSize: 14, color: AppColors.overBudget),
            ),
          ),
        const SizedBox(height: 16),
        Expanded(
          child: Container(
            padding: const EdgeInsets.all(12),
            color: AppColors.background,
            child: MapThumbnail(sheet: map.sheet),
          ),
        ),
      ],
    );
  }
}

/// Horizontal strip of saved maps with a fixed New tile on the right.
class MapGallery extends StatelessWidget {
  const MapGallery({
    super.key,
    required this.maps,
    required this.selectedId,
    required this.onSelect,
    required this.creating,
    required this.onNew,
  });

  final List<SavedMap> maps;
  final String? selectedId;
  final ValueChanged<SavedMap> onSelect;
  final bool creating;
  final VoidCallback onNew;

  static const double height = 148;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: height,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: maps.isEmpty
                ? const Center(
                    child: Text(
                      'No saved maps yet. Choose New to make one.',
                      style: TextStyle(fontSize: 15, color: AppColors.textDim),
                    ),
                  )
                : ListView.separated(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.all(12),
                    itemCount: maps.length,
                    separatorBuilder: (_, _) => const SizedBox(width: 10),
                    itemBuilder: (context, i) => _MapTile(
                      map: maps[i],
                      selected: !creating && maps[i].id == selectedId,
                      onTap: () => onSelect(maps[i]),
                    ),
                  ),
          ),
          const VerticalDivider(width: 1),
          Padding(
            padding: const EdgeInsets.all(12),
            child: _NewTile(label: 'NEW MAP', active: creating, onTap: onNew),
          ),
        ],
      ),
    );
  }
}

class _MapTile extends StatelessWidget {
  const _MapTile({
    required this.map,
    required this.selected,
    required this.onTap,
  });

  final SavedMap map;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: selected,
      label: map.name,
      child: Material(
        color: selected ? AppColors.panelActive : AppColors.panelRaised,
        child: InkWell(
          onTap: onTap,
          child: Container(
            width: 112,
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              border: Border.all(
                color: selected ? AppColors.accent : AppColors.border,
                width: selected ? 2 : 1,
              ),
            ),
            child: Column(
              children: [
                Expanded(
                  child: MapThumbnail(sheet: map.sheet, showLabels: false),
                ),
                const SizedBox(height: 6),
                Text(
                  map.name.isEmpty ? 'UNTITLED' : map.name.toUpperCase(),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.6,
                    color: selected ? AppColors.accent : AppColors.text,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Dashed "+ NEW" tile, used for New Lance and New Map.
class SkirmishNewTile extends StatelessWidget {
  const SkirmishNewTile({
    super.key,
    required this.label,
    required this.active,
    required this.onTap,
    this.height = 64,
  });

  final String label;
  final bool active;
  final VoidCallback onTap;
  final double height;

  @override
  Widget build(BuildContext context) => SizedBox(
    height: height,
    child: _NewTile(label: label, active: active, onTap: onTap),
  );
}

class _NewTile extends StatelessWidget {
  const _NewTile({
    required this.label,
    required this.active,
    required this.onTap,
  });

  final String label;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: active,
      child: Material(
        color: active ? AppColors.panelActive : Colors.transparent,
        child: InkWell(
          onTap: onTap,
          child: DashedOutline(
            child: Container(
              constraints: const BoxConstraints(minWidth: 112),
              alignment: Alignment.center,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Text(
                '+ $label',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.6,
                  color: active ? AppColors.accent : AppColors.textDim,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
