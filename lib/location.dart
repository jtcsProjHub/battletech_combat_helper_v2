// File: lib/location.dart
// The body locations of a BattleMech, in the order they are listed on a record sheet. Each location carries the
// short code used in equipment 'location' fields, the key of its critTable entry in the JSON data, and the name
// shown to the user. Look locations up here instead of comparing raw strings elsewhere in the application.

enum Location {
  head('HD', 'crit_head', 'Head'),
  centerTorso('CT', 'crit_center_torso', 'Center Torso'),
  leftTorso('LT', 'crit_left_torso', 'Left Torso'),
  rightTorso('RT', 'crit_right_torso', 'Right Torso'),
  leftArm('LA', 'crit_left_arm', 'Left Arm'),
  rightArm('RA', 'crit_right_arm', 'Right Arm'),
  leftLeg('LL', 'crit_left_leg', 'Left Leg'),
  rightLeg('RL', 'crit_right_leg', 'Right Leg');

  const Location(this.code, this.critKey, this.label);

  /// The short code used by equipment 'location' fields, e.g. 'LA'.
  final String code;

  /// The critTable key holding this location's critical slots, e.g. 'crit_left_arm'.
  final String critKey;

  /// The display name, e.g. 'Left Arm'.
  final String label;

  /// The location with this short code, or null when the code is empty or unknown. Case-insensitive.
  static Location? fromCode(String? code) {
    if (code == null) return null;
    final upper = code.trim().toUpperCase();
    for (final location in values) {
      if (location.code == upper) return location;
    }
    return null;
  }

  /// The location whose critTable entry is this key, or null when the key is unknown.
  static Location? fromCritKey(String? critKey) {
    for (final location in values) {
      if (location.critKey == critKey) return location;
    }
    return null;
  }

  /// The location with this display name, or null when the name is empty or unknown.
  static Location? fromLabel(String? label) {
    for (final location in values) {
      if (location.label == label) return location;
    }
    return null;
  }
}
