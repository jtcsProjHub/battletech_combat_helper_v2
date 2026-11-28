// File: lib/settings/player_settings.dart
// Client-facing settings. GameplaySettings holds the defaults the host
// sets in the server's settings menu; each player's PlayerSettings start
// from them when a skirmish is confirmed.
//
// What may change when:
// - name: chosen on the player's welcome screen, fixed once play starts.
// - rolls: the player's own roll preferences, changeable during play.

import 'dice_rolls.dart';

/// The host's defaults for the client-facing settings.
class GameplaySettings {
  const GameplaySettings({this.rolls = RollPreferences.automated});

  /// Starting roll preferences for every player.
  final RollPreferences rolls;

  GameplaySettings copyWith({RollPreferences? rolls}) =>
      GameplaySettings(rolls: rolls ?? this.rolls);

  Map<String, Object?> toJson() => {'rolls': rolls.toJson()};

  factory GameplaySettings.fromJson(Object? json) => GameplaySettings(
    rolls: RollPreferences.fromJson(json is Map ? json['rolls'] : null),
  );

  @override
  bool operator ==(Object other) =>
      other is GameplaySettings && other.rolls == rolls;

  @override
  int get hashCode => rolls.hashCode;
}

/// One player's settings within a skirmish.
class PlayerSettings {
  PlayerSettings({String? name, this.rolls = RollPreferences.automated})
    : name = _clean(name);

  /// A player who has not chosen anything yet: the host's default rolls.
  factory PlayerSettings.fromDefaults(GameplaySettings defaults) =>
      PlayerSettings(rolls: defaults.rolls);

  /// Null until the player gives one; blank names count as none.
  final String? name;

  final RollPreferences rolls;

  /// What to call the player: their name, or else their lance's name.
  String displayName(String lanceName) => name ?? lanceName;

  PlayerSettings copyWith({String? name, RollPreferences? rolls}) =>
      PlayerSettings(name: name ?? this.name, rolls: rolls ?? this.rolls);

  /// A copy with the name removed.
  PlayerSettings withoutName() => PlayerSettings(rolls: rolls);

  Map<String, Object?> toJson() => {
    if (name != null) 'name': name,
    'rolls': rolls.toJson(),
  };

  factory PlayerSettings.fromJson(Object? json) {
    final m = json is Map ? json : const {};
    return PlayerSettings(
      name: m['name'] as String?,
      rolls: RollPreferences.fromJson(m['rolls']),
    );
  }

  static String? _clean(String? name) {
    final t = name?.trim();
    return t == null || t.isEmpty ? null : t;
  }

  @override
  bool operator ==(Object other) =>
      other is PlayerSettings && other.name == name && other.rolls == rolls;

  @override
  int get hashCode => Object.hash(name, rolls);
}
