// File: lib/mech_columns.dart
// The optional columns of the mech list, and the filter the list applies.
// The Mech column (name and variant) is always shown and is not listed here.

import 'era.dart';
import 'mech_data.dart';
import 'mech_labels.dart';

enum MechColumn {
  tons('Tons', 68, numeric: true),
  weightClass('Class', 84),
  role('Role', 112),
  battleValue('BV', 76, numeric: true),
  move('Move', 76),
  armor('Armor', 76, numeric: true),
  structure('Struct', 84, numeric: true),
  heat('Heat G/S', 100, numeric: true),
  techBase('Tech', 108),
  intro('Intro', 76, numeric: true);

  const MechColumn(this.label, this.width, {this.numeric = false});

  final String label;
  final double width;

  /// Numeric columns align right and sort high to low first.
  final bool numeric;

  static const defaults = <MechColumn>[
    tons,
    weightClass,
    role,
    battleValue,
    move,
    armor,
  ];

  String text(Mech m) => switch (this) {
    MechColumn.tons => m.tonnage.round().toString(),
    MechColumn.weightClass => m.weightClassString,
    MechColumn.role => m.role.label,
    MechColumn.battleValue => m.bv.toString(),
    MechColumn.move => m.moveText,
    MechColumn.armor => m.armorTotal.toString(),
    MechColumn.structure => m.structureTotal.toString(),
    MechColumn.heat => '${m.totalWeaponHeat}/${m.heatDissipation}',
    MechColumn.techBase => m.techBase.label,
    MechColumn.intro => m.introYear > 0 ? m.introYear.toString() : '—',
  };

  /// Sorts by weight class through tonnage, move through walk then jump,
  /// and heat through the margin of dissipation over generated heat.
  Comparable<Object> sortValue(Mech m) => switch (this) {
    MechColumn.tons || MechColumn.weightClass => m.tonnage,
    MechColumn.role => m.role.label,
    MechColumn.battleValue => m.bv,
    MechColumn.move => m.walk * 100 + m.jump,
    MechColumn.armor => m.armorTotal,
    MechColumn.structure => m.structureTotal,
    MechColumn.heat => m.heatDissipation - m.totalWeaponHeat,
    MechColumn.techBase => m.techBase.label,
    MechColumn.intro => m.introYear,
  };
}

/// Keeps the mechs that match every filter that is set. A null filter means
/// "any". With a faction but no era, the faction must field the mech in at
/// least one era.
List<Mech> filterMechs(
  Iterable<Mech> mechs, {
  String query = '',
  Era? era,
  String? faction,
  TechBase? techBase,
  WeightClass? weightClass,
}) {
  final q = query.trim().toLowerCase();
  return mechs.where((m) {
    if (q.isNotEmpty && !'${m.name} ${m.variant}'.toLowerCase().contains(q)) {
      return false;
    }
    if (techBase != null && m.techBase != techBase) return false;
    if (weightClass != null && m.weightClass != weightClass) return false;
    if (era != null) {
      final factions = m.availability[era];
      if (factions == null) return false;
      if (faction != null && !factions.contains(faction)) return false;
    } else if (faction != null) {
      if (!m.availability.values.any((fs) => fs.contains(faction))) {
        return false;
      }
    }
    return true;
  }).toList();
}
