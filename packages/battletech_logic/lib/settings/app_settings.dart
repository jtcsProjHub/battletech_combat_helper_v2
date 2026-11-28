// File: lib/settings/app_settings.dart
// The app-level settings the host edits in the settings menu. Server only:
// they may hold the hotspot password and are never sent to the phones as a
// whole.
//
// Categories:
// - Server, not skirmish specific: [HostConfig] (hotspot profile, port).
// - Server, skirmish specific: [SkirmishServerSettings]. Copied into each
//   skirmish when it is confirmed.
// - Client facing: [GameplaySettings], the defaults each player's own
//   settings start from when a skirmish is confirmed.
//
// A skirmish keeps its own copy of the skirmish settings from the moment it
// is confirmed (see skirmish_settings.dart), so changing these
// later never changes a game in progress.

import 'dart:convert';

import 'host_config.dart';
import 'player_settings.dart';

/// Server-only options that apply to one skirmish. None yet; this is where
/// they go, so they are snapshotted with the rest when a skirmish starts.
class SkirmishServerSettings {
  const SkirmishServerSettings();

  Map<String, Object?> toJson() => const {};

  factory SkirmishServerSettings.fromJson(Object? json) =>
      const SkirmishServerSettings();

  @override
  bool operator ==(Object other) => other is SkirmishServerSettings;

  @override
  int get hashCode => 0;
}

class AppSettings {
  const AppSettings({
    this.host = const HostConfig(),
    this.skirmishServer = const SkirmishServerSettings(),
    this.gameplay = const GameplaySettings(),
  });

  static const formatName = 'btsettings';
  static const formatVersion = 1;

  final HostConfig host;
  final SkirmishServerSettings skirmishServer;
  final GameplaySettings gameplay;

  AppSettings copyWith({
    HostConfig? host,
    SkirmishServerSettings? skirmishServer,
    GameplaySettings? gameplay,
  }) => AppSettings(
    host: host ?? this.host,
    skirmishServer: skirmishServer ?? this.skirmishServer,
    gameplay: gameplay ?? this.gameplay,
  );

  Map<String, Object?> toJson() => {
    'format': formatName,
    'version': formatVersion,
    'host': host.toJson(),
    'skirmishServer': skirmishServer.toJson(),
    'gameplay': gameplay.toJson(),
  };

  /// The settings file's text.
  String encode() => const JsonEncoder.withIndent('  ').convert(toJson());

  /// Parses a settings file's text. Throws a [FormatException] when it is
  /// not a JSON object.
  factory AppSettings.decode(String text) {
    final json = jsonDecode(text);
    if (json is! Map<String, Object?>) {
      throw const FormatException('Settings file is not a JSON object');
    }
    return AppSettings.fromJson(json);
  }

  /// Missing or unreadable sections fall back to their defaults.
  factory AppSettings.fromJson(Map<String, Object?> json) => AppSettings(
    host: HostConfig.fromJson(json['host']),
    skirmishServer: SkirmishServerSettings.fromJson(json['skirmishServer']),
    gameplay: GameplaySettings.fromJson(json['gameplay']),
  );

  @override
  bool operator ==(Object other) =>
      other is AppSettings &&
      other.host == host &&
      other.skirmishServer == skirmishServer &&
      other.gameplay == gameplay;

  @override
  int get hashCode => Object.hash(host, skirmishServer, gameplay);
}
