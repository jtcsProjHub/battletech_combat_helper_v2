// File: lib/mech_library.dart
// The loaded mech data set with the lookups the Lance Builder needs. Built once after loading; the data set is
// small enough that every query is a cheap scan or a prebuilt map lookup.

import 'package:flutter/foundation.dart' show compute;
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'era.dart';
import 'mech_data.dart';

class MechLibrary {
  MechLibrary(List<Mech> mechs)
      : mechs = List.unmodifiable(mechs),
        _byId = {for (final m in mechs) m.id: m},
        _byIntroEra = _groupByIntroEra(mechs),
        _byAvailability = _groupByAvailability(mechs);

  final List<Mech> mechs;
  final Map<String, Mech> _byId;
  final Map<Era, List<Mech>> _byIntroEra;
  final Map<Era, Map<String, List<Mech>>> _byAvailability; // era -> faction -> mechs

  Mech? byId(String id) => _byId[id];

  /// Mechs introduced during [era]. Mechs with no known era are in no era.
  List<Mech> introducedIn(Era era) => _byIntroEra[era] ?? const [];

  /// Mechs introduced in or before [era], i.e. the ones that exist by then.
  List<Mech> introducedBy(Era era) =>
      mechs.where((m) => m.era != null && m.era! <= era).toList();

  /// Mechs introduced in or before [year].
  List<Mech> introducedByYear(int year) =>
      mechs.where((m) => m.introYear > 0 && m.introYear <= year).toList();

  /// Mechs some faction can field in [era]; with [faction], only the ones that faction can field.
  List<Mech> availableIn(Era era, {String? faction}) {
    final byFaction = _byAvailability[era];
    if (byFaction == null) return const [];
    if (faction != null) return byFaction[faction] ?? const [];
    return mechs.where((m) => m.availability.containsKey(era)).toList();
  }

  /// Factions with at least one mech available in [era], or in any era when omitted, sorted by name.
  List<String> factions({Era? era}) {
    final names = era != null
        ? (_byAvailability[era]?.keys ?? const <String>[])
        : _byAvailability.values.expand((byFaction) => byFaction.keys);
    return names.toSet().toList()..sort();
  }

  /// The eras at least one mech is available in, in timeline order.
  List<Era> eras() => (_byAvailability.keys.toList()..sort((a, b) => a.index - b.index));

  static Map<Era, List<Mech>> _groupByIntroEra(List<Mech> mechs) {
    final result = <Era, List<Mech>>{};
    for (final m in mechs) {
      final era = m.era;
      if (era != null) result.putIfAbsent(era, () => []).add(m);
    }
    return result;
  }

  static Map<Era, Map<String, List<Mech>>> _groupByAvailability(List<Mech> mechs) {
    final result = <Era, Map<String, List<Mech>>>{};
    for (final m in mechs) {
      m.availability.forEach((era, factions) {
        final byFaction = result.putIfAbsent(era, () => {});
        for (final faction in factions) {
          byFaction.putIfAbsent(faction, () => []).add(m);
        }
      });
    }
    return result;
  }
}

const mechDataAsset = 'assets/base_data/mechs_clean.json';

/// Loads the bundled mech data. The JSON is parsed on a background isolate so the UI doesn't stall at startup.
Future<MechLibrary> loadMechLibrary({String assetPath = mechDataAsset}) async {
  final jsonString = await rootBundle.loadString(assetPath);
  return MechLibrary(await compute(mechsFromJsonString, jsonString));
}

/// The mech data, loaded once on first read and cached for the life of the app. Watch it as an AsyncValue;
/// tests can override it with a library built from a fixture.
final mechLibraryProvider = FutureProvider<MechLibrary>((ref) => loadMechLibrary());
