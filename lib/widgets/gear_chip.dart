// File: lib/widgets/gear_chip.dart
// One weapon or piece of equipment with its count, e.g. "4× Medium Laser".
// The roster cards show plain chips; the balancing variant list tints them
// to show what a swap removes or adds.

import 'package:flutter/material.dart';

import '../app_theme.dart';

enum GearChipTone { plain, removed, added }

class GearChip extends StatelessWidget {
  const GearChip({
    super.key,
    required this.quantity,
    required this.name,
    this.tone = GearChipTone.plain,
  });

  final int quantity;
  final String name;
  final GearChipTone tone;

  @override
  Widget build(BuildContext context) {
    final (fill, edge, count) = switch (tone) {
      GearChipTone.plain => (
        AppColors.panelActive,
        AppColors.chipBorder,
        AppColors.accent,
      ),
      GearChipTone.removed => (
        AppColors.removedFill,
        AppColors.removed,
        AppColors.removed,
      ),
      GearChipTone.added => (
        AppColors.addedFill,
        AppColors.added,
        AppColors.added,
      ),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: fill,
        border: Border.all(color: edge),
      ),
      child: Text.rich(
        TextSpan(
          children: [
            TextSpan(
              text: '$quantity×',
              style: TextStyle(fontWeight: FontWeight.w700, color: count),
            ),
            TextSpan(text: ' $name'),
          ],
        ),
        style: const TextStyle(fontSize: 13, color: AppColors.text),
      ),
    );
  }
}
