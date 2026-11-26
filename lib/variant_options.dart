// File: lib/variant_options.dart
// The other variants a lance slot could swap to during balancing: whether
// each one fits the lance's era and faction filters, and which weapons and
// equipment it adds or removes compared with the current variant. Pure
// data, so the balancing widgets only lay it out.

import 'lance.dart';
import 'mech_data.dart';
import 'mech_gear.dart';
import 'mech_labels.dart';
import 'mech_library.dart';

/// The lance filter a mech fails.
enum FilterMiss { era, faction }

extension LanceFilterCheck on LanceParameters {
  /// True when an era or a faction is set, so variants can miss them.
  bool get filtersAvailability => era != null || faction != null;

  /// The filter [m] fails, or null when it fits. Same rules as filterMechs:
  /// with an era, the mech must be fielded in it (by [faction], when set);
  /// with only a faction, that faction must field it in some era.
  FilterMiss? filterMiss(Mech m) {
    final e = era;
    final f = faction;
    if (e != null) {
      final factions = m.availability[e];
      if (factions == null) return FilterMiss.era;
      if (f != null && !factions.contains(f)) return FilterMiss.faction;
      return null;
    }
    if (f != null && !m.availability.values.any((fs) => fs.contains(f))) {
      return FilterMiss.faction;
    }
    return null;
  }

  /// Why [m] fails [miss], e.g. "Era · introduced 3050".
  String describeMiss(FilterMiss miss, Mech m) {
    switch (miss) {
      case FilterMiss.era:
        final e = era!;
        final intro = m.era;
        if (intro != null && intro > e) {
          return 'Era · introduced '
              '${m.introYear > 0 ? m.introYear : intro.label}';
        }
        return 'Era · not fielded in ${e.label}';
      case FilterMiss.faction:
        return 'Faction · not fielded by $faction'
            '${era != null ? ' in this era' : ''}';
    }
  }
}

/// Some number of one weapon or piece of equipment.
class GearChange {
  const GearChange(this.name, this.quantity);

  final String name;
  final int quantity;

  @override
  bool operator ==(Object other) =>
      other is GearChange && other.name == name && other.quantity == quantity;

  @override
  int get hashCode => Object.hash(name, quantity);

  @override
  String toString() => '$quantity× $name';
}

/// Each weapon type with its quantity, then each piece of equipment once.
/// Double heat sinks are left out: the heat sink stat already shows them.
Map<String, int> gearCounts(Mech m) {
  final counts = <String, int>{};
  for (final g in m.weaponGroups) {
    final type = g.weapon.type.trim();
    if (type.isNotEmpty) counts[type] = (counts[type] ?? 0) + g.quantity;
  }
  for (final name in m.gear) {
    if (name != doubleHeatSinks) counts.putIfAbsent(name, () => 1);
  }
  return counts;
}

/// What changes in weapons and equipment going from one variant to another.
/// A changed quantity shows as the difference, e.g. 4 Medium Lasers to 2 is
/// "2× Medium Laser" removed.
class GearDiff {
  const GearDiff({this.removed = const [], this.added = const []});

  factory GearDiff.between(Mech from, Mech to) {
    final a = gearCounts(from);
    final b = gearCounts(to);
    return GearDiff(
      removed: [
        for (final MapEntry(key: name, value: n) in a.entries)
          if (n > (b[name] ?? 0)) GearChange(name, n - (b[name] ?? 0)),
      ],
      added: [
        for (final MapEntry(key: name, value: n) in b.entries)
          if (n > (a[name] ?? 0)) GearChange(name, n - (a[name] ?? 0)),
      ],
    );
  }

  /// In the order the first variant lists them.
  final List<GearChange> removed;

  /// In the order the second variant lists them.
  final List<GearChange> added;

  bool get isEmpty => removed.isEmpty && added.isEmpty;
}

/// One variant a slot could swap to.
class VariantOption {
  const VariantOption({
    required this.mech,
    required this.miss,
    required this.gear,
  });

  final Mech mech;

  /// The lance filter it fails, or null.
  final FilterMiss? miss;

  /// Its gear compared with the slot's current variant.
  final GearDiff gear;

  bool get fitsFilters => miss == null;
}

/// The other variants of [current]'s chassis: the ones that fit
/// [parameters] first, then the rest, each part sorted by BV, cheapest
/// first. The pilot multiplies every variant's BV alike, so base BV sorts
/// the same as piloted BV.
List<VariantOption> variantOptions({
  required Mech current,
  required MechLibrary library,
  required LanceParameters parameters,
}) {
  final options = [
    for (final m in library.variantsOf(current))
      if (m.id != current.id)
        VariantOption(
          mech: m,
          miss: parameters.filterMiss(m),
          gear: GearDiff.between(current, m),
        ),
  ];
  options.sort((a, b) {
    if (a.fitsFilters != b.fitsFilters) return a.fitsFilters ? -1 : 1;
    final byBv = a.mech.bv.compareTo(b.mech.bv);
    return byBv != 0 ? byBv : a.mech.variant.compareTo(b.mech.variant);
  });
  return options;
}
