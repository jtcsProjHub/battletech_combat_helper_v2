// File: lib/settings/settings_repository.dart
// Saving and loading the app settings: one JSON file, settings.json, in the
// app support directory (~/.local/share/<app id> on Linux). Screens read
// and save through appSettingsProvider.

import 'dart:io';

import 'package:battletech_logic/battletech_logic.dart';
import 'package:flutter/foundation.dart' show debugPrint;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';

import '../server/hotspot.dart';

abstract interface class SettingsRepository {
  /// The saved settings, or the defaults when none are saved.
  Future<AppSettings> load();

  Future<void> save(AppSettings settings);
}

class FileSettingsRepository implements SettingsRepository {
  /// [file] is resolved on first use, so building the repository does no
  /// I/O.
  FileSettingsRepository(this._file);

  factory FileSettingsRepository.appSupport() => FileSettingsRepository(
    () async => File(
      '${(await getApplicationSupportDirectory()).path}'
      '${Platform.pathSeparator}settings.json',
    ),
  );

  final Future<File> Function() _file;

  /// A file that can't be read gives the defaults and is left on disk until
  /// the next save replaces it.
  @override
  Future<AppSettings> load() async {
    try {
      final file = await _file();
      if (!await file.exists()) return const AppSettings();
      return AppSettings.decode(await file.readAsString());
    } on Object catch (e) {
      debugPrint('Using default settings; could not read them: $e');
      return const AppSettings();
    }
  }

  /// Writes a temporary file and renames it over the old one.
  @override
  Future<void> save(AppSettings settings) async {
    final file = await _file();
    await file.parent.create(recursive: true);
    final temp = File('${file.path}.tmp');
    await temp.writeAsString(settings.encode(), flush: true);
    await temp.rename(file.path);
  }
}

/// Keeps the settings in memory only. Used by tests.
class MemorySettingsRepository implements SettingsRepository {
  MemorySettingsRepository([this.saved = const AppSettings()]);

  AppSettings saved;
  int saves = 0;

  @override
  Future<AppSettings> load() async => saved;

  @override
  Future<void> save(AppSettings settings) async {
    saved = settings;
    saves++;
  }
}

/// Where the settings are saved. Tests override this with a
/// MemorySettingsRepository.
final settingsRepositoryProvider = Provider<SettingsRepository>(
  (ref) => FileSettingsRepository.appSupport(),
);

class AppSettingsNotifier extends AsyncNotifier<AppSettings> {
  @override
  Future<AppSettings> build() => ref.watch(settingsRepositoryProvider).load();

  Future<void> save(AppSettings settings) async {
    await ref.read(settingsRepositoryProvider).save(settings);
    state = AsyncData(settings);
  }
}

/// The app settings. Save through the notifier.
final appSettingsProvider =
    AsyncNotifierProvider<AppSettingsNotifier, AppSettings>(
      AppSettingsNotifier.new,
    );

/// Reads and writes the hotspot's network name and password, which live in
/// the NetworkManager profile rather than the settings file. Tests override
/// this with a fake.
final hotspotProfilesProvider = Provider<HotspotProfiles>(
  (ref) => HotspotProfiles.forPlatform(),
);
