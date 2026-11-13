// File: lib/mech_columns.dart
// The optional columns of the mech list, the per-column filters, and the
// filter the list applies. The Mech column (name and variant) is always
// shown and is not listed here.

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

  /// The numbers a range filter on this column can test. Move filters on
  /// walk, run, and jump separately; heat on weapon heat and dissipation.
  List<NumericField> get numericFields => switch (this) {
    MechColumn.tons => [NumericField('Tons', (m) => m.tonnage)],
    MechColumn.battleValue => [NumericField('BV', (m) => m.bv)],
    MechColumn.move => [
      NumericField('Walk', (m) => m.walk),
      NumericField('Run', (m) => m.run),
      NumericField('Jump', (m) => m.jump),
    ],
    MechColumn.armor => [NumericField('Armor', (m) => m.armorTotal)],
    MechColumn.structure => [
      NumericField('Structure', (m) => m.structureTotal),
    ],
    MechColumn.heat => [
      NumericField('Weapon heat', (m) => m.totalWeaponHeat),
      NumericField('Dissipation', (m) => m.heatDissipation),
    ],
    MechColumn.intro => [NumericField('Intro year', (m) => m.introYear)],
    _ => const [],
  };

  /// The value a checklist filter on this column tests, or null when the
  /// column has no checklist. Weight class and tech base have their own
  /// filters above the list, so they are not repeated here.
  String? category(Mech m) => switch (this) {
    MechColumn.role => m.role.label,
    _ => null,
  };

  bool get hasCategories => this == MechColumn.role;

  bool get filterable => hasCategories || numericFields.isNotEmpty;

  static List<MechColumn> get filterableColumns =>
      values.where((c) => c.filterable).toList();

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

/// One number of a mech that a range filter can test.
class NumericField {
  const NumericField(this.label, this.value);

  final String label;
  final num Function(Mech) value;
}

/// An inclusive range. A null end is open.
typedef NumRange = ({int? min, int? max});

/// The filter set on one column: a checklist of allowed values (any of
/// them), ranges keyed by NumericField label (all of them), or both.
class ColumnFilter {
  const ColumnFilter({this.values = const {}, this.ranges = const {}});

  static const none = ColumnFilter();

  final Set<String> values;
  final Map<String, NumRange> ranges;

  bool get isEmpty =>
      values.isEmpty &&
      ranges.values.every((r) => r.min == null && r.max == null);

  bool matches(MechColumn column, Mech m) {
    if (values.isNotEmpty && !values.contains(column.category(m))) {
      return false;
    }
    for (final field in column.numericFields) {
      final range = ranges[field.label];
      if (range == null) continue;
      final v = field.value(m);
      if (range.min != null && v < range.min!) return false;
      if (range.max != null && v > range.max!) return false;
    }
    return true;
  }

  /// Short text for the active-filter chip, e.g. "Role: Brawler, Sniper"
  /// or "Walk ≥ 5 · Jump 3–5".
  String describe(MechColumn column) {
    final parts = <String>[
      if (values.isNotEmpty)
        '${column.label}: ${(values.toList()..sort()).join(', ')}',
      for (final field in column.numericFields)
        if (ranges[field.label] case (
          :final min,
          :final max,
        ) when min != null || max != null)
          '${field.label} ${_rangeText(min, max)}',
    ];
    return parts.join(' · ');
  }

  static String _rangeText(int? min, int? max) {
    if (min != null && max != null) return min == max ? '$min' : '$min–$max';
    if (min != null) return '≥ $min';
    return '≤ $max';
  }

  @override
  bool operator ==(Object other) =>
      other is ColumnFilter &&
      other.values.length == values.length &&
      other.values.containsAll(values) &&
      other.ranges.length == ranges.length &&
      ranges.entries.every((e) => other.ranges[e.key] == e.value);

  @override
  int get hashCode => Object.hash(
    Object.hashAllUnordered(values),
    Object.hashAllUnordered(
      ranges.entries.map((e) => Object.hash(e.key, e.value)),
    ),
  );
}

/// Keeps the mechs that match every filter that is set. A null or empty
/// filter means "any". With a faction but no era, the faction must field
/// the mech in at least one era.
List<Mech> filterMechs(
  Iterable<Mech> mechs, {
  String query = '',
  Era? era,
  String? faction,
  TechBase? techBase,
  Set<WeightClass> weightClasses = const {},
  Map<MechColumn, ColumnFilter> columnFilters = const {},
}) {
  final q = query.trim().toLowerCase();
  return mechs.where((m) {
    if (q.isNotEmpty && !'${m.name} ${m.variant}'.toLowerCase().contains(q)) {
      return false;
    }
    if (techBase != null && m.techBase != techBase) return false;
    if (weightClasses.isNotEmpty && !weightClasses.contains(m.weightClass)) {
      return false;
    }
    for (final MapEntry(key: column, value: filter) in columnFilters.entries) {
      if (!filter.matches(column, m)) return false;
    }
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
