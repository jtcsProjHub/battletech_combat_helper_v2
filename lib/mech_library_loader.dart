// File: lib/mech_library_loader.dart
// Loads the bundled mech data into a MechLibrary and provides it to the app.
// Kept apart from mech_library.dart so the model stays pure Dart.

import 'package:flutter/foundation.dart' show compute;
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'mech_data.dart';
import 'mech_library.dart';

const mechDataAsset = 'assets/base_data/mechs_clean.json';

/// Loads the bundled mech data. The JSON is parsed on a background isolate so the UI doesn't stall at startup.
Future<MechLibrary> loadMechLibrary({String assetPath = mechDataAsset}) async {
  final jsonString = await rootBundle.loadString(assetPath);
  return MechLibrary(await compute(mechsFromJsonString, jsonString));
}

/// The mech data, loaded once on first read and cached for the life of the app. Watch it as an AsyncValue;
/// tests can override it with a library built from a fixture.
final mechLibraryProvider = FutureProvider<MechLibrary>(
  (ref) => loadMechLibrary(),
);
