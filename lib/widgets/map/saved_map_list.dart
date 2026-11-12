// File: lib/widgets/map/saved_map_list.dart
// Pick one saved map: a row per map with a small thumbnail, its size, and
// its terrain and review counts. Used by Edit Map, and later by New
// Skirmish for map selection.

import 'package:flutter/material.dart';

import '../../app_theme.dart';
import '../../maps/hex_layout.dart';
import '../../maps/map_repository.dart';
import 'hex_map_view.dart';

class SavedMapList extends StatelessWidget {
  const SavedMapList({
    super.key,
    required this.maps,
    required this.onSelect,
    this.selectedId,
    this.emptyText = 'No saved maps yet.',
  });

  final List<SavedMap> maps;
  final ValueChanged<SavedMap> onSelect;
  final String? selectedId;
  final String emptyText;

  @override
  Widget build(BuildContext context) {
    if (maps.isEmpty) {
      return Text(
        emptyText,
        style: const TextStyle(fontSize: 16, color: AppColors.textSecondary),
      );
    }
    return ListView.separated(
      itemCount: maps.length,
      separatorBuilder: (_, _) => const SizedBox(height: 8),
      itemBuilder: (context, i) => _MapRow(
        map: maps[i],
        selected: maps[i].id == selectedId,
        onTap: () => onSelect(maps[i]),
      ),
    );
  }
}

/// One-line summary of a map's contents, shared by the list and the
/// detail view.
String mapSummary(SavedMap map) {
  final s = map.sheet;
  final review = s.unverified.length;
  return '${s.grid.columns} × ${s.grid.rows} hexes · '
      '${s.hexes.length} with terrain'
      '${review > 0 ? ' · $review to review' : ''}';
}

class _MapRow extends StatelessWidget {
  const _MapRow({
    required this.map,
    required this.selected,
    required this.onTap,
  });

  final SavedMap map;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final edge = selected ? AppColors.borderStrong : AppColors.border;
    final review = map.sheet.unverified.length;
    return Semantics(
      button: true,
      selected: selected,
      child: Material(
        color: selected ? AppColors.panelActive : AppColors.panelRaised,
        child: InkWell(
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
            decoration: BoxDecoration(
              border: Border(
                left: BorderSide(
                  color: selected ? AppColors.accent : edge,
                  width: 4,
                ),
                top: BorderSide(color: edge),
                right: BorderSide(color: edge),
                bottom: BorderSide(color: edge),
              ),
            ),
            child: Row(
              children: [
                SizedBox(
                  width: 56,
                  height: 56,
                  child: MapThumbnail(sheet: map.sheet, showLabels: false),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        map.name.isEmpty
                            ? 'UNTITLED MAP'
                            : map.name.toUpperCase(),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.7,
                          color: AppColors.text,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text.rich(
                        TextSpan(
                          children: [
                            TextSpan(
                              text:
                                  '${map.sheet.grid.columns} × '
                                  '${map.sheet.grid.rows} hexes · '
                                  '${map.sheet.hexes.length} with terrain',
                            ),
                            if (review > 0)
                              TextSpan(
                                text: ' · $review to review',
                                style: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                  color: TerrainStyle.review,
                                ),
                              ),
                          ],
                        ),
                        style: const TextStyle(
                          fontSize: 13,
                          color: AppColors.textDim,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(
                  Icons.chevron_right,
                  color: selected ? AppColors.accent : AppColors.iconDim,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
