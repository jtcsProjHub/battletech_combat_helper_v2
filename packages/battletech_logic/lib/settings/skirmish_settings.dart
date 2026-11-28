// File: lib/settings/skirmish_settings.dart
// A skirmish's own settings: a snapshot of the app settings taken when the
// skirmish is confirmed, plus each player's settings. Later changes in the
// settings menu don't reach a skirmish already started.
//
// The hotspot settings (HostConfig) are not part of the snapshot: they
// belong to the laptop, not the game.

import 'app_settings.dart';
import 'player_settings.dart';

class SkirmishSettings {
  SkirmishSettings({
    this.server = const SkirmishServerSettings(),
    this.defaults = const GameplaySettings(),
    List<PlayerSettings>? players,
  }) : players = players != null && players.length == 2
           ? List.of(players)
           : [
               PlayerSettings.fromDefaults(defaults),
               PlayerSettings.fromDefaults(defaults),
             ];

  /// Copies what a skirmish needs from [app]. Both players start from the
  /// host's default roll preferences, with no name.
  factory SkirmishSettings.snapshot(AppSettings app) =>
      SkirmishSettings(server: app.skirmishServer, defaults: app.gameplay);

  final SkirmishServerSettings server;

  /// The host's client-facing defaults when the skirmish started. A player
  /// who resets their settings goes back to these.
  final GameplaySettings defaults;

  /// Per player (from 0). Replace an entry to change it.
  final List<PlayerSettings> players;

  Map<String, Object?> toJson() => {
    'server': server.toJson(),
    'defaults': defaults.toJson(),
    'players': [for (final p in players) p.toJson()],
  };

  factory SkirmishSettings.fromJson(Object? json) {
    final m = json is Map ? json : const {};
    final players = m['players'];
    return SkirmishSettings(
      server: SkirmishServerSettings.fromJson(m['server']),
      defaults: GameplaySettings.fromJson(m['defaults']),
      players: players is List
          ? [for (final p in players) PlayerSettings.fromJson(p)]
          : null,
    );
  }
}
