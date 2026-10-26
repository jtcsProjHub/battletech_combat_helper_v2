// File: lib/location.dart
// The body locations of a BattleMech, in the order they are listed on a record sheet. Each location carries the
// short code used in equipment 'location' fields, its key in the JSON data, and the name
// shown to the user. Look locations up here instead of comparing raw strings elsewhere in the application.

enum Location {
  invalid('--', 'invalid', 'invalid'),
  head('HD', 'head', 'Head'),
  centerTorso('CT', 'center_torso', 'Center Torso'),
  leftTorso('LT', 'left_torso', 'Left Torso'),
  rightTorso('RT', 'right_torso', 'Right Torso'),
  leftArm('LA', 'left_arm', 'Left Arm'),
  rightArm('RA', 'right_arm', 'Right Arm'),
  leftLeg('LL', 'left_leg', 'Left Leg'),
  rightLeg('RL', 'right_leg', 'Right Leg'),
  rearLeftTorso('RLT', 'rear_left_torso', 'Rear Left Torso'),
  rearRightTorso('RRT', 'rear_right_torso', 'Rear Right Torso'),
  rearCenterTorso('RCT', 'rear_center_torso', 'Rear Center Torso');

  const Location(this.code, this.jsonKey, this.label);

  /// The short code used by equipment 'location' fields, e.g. 'LA'.
  final String code;

  /// The key identifying this location in the JSON data, e.g. 'left_arm'.
  final String jsonKey;

  /// The display name, e.g. 'Left Arm'.
  final String label;

  /// The critTable key holding this location's critical slots, e.g. 'crit_left_arm'.
  String get critKey => 'crit_$jsonKey';

  /// The location whose JSON key is this, or invalid when the key is unknown.
  static Location fromJsonKey(String? key) {
    for (final location in values) {
      if (location.jsonKey == key) return location;
    }
    return Location.invalid;
  }

  /// The location with this short code, or null when the code is empty or unknown. Case-insensitive.
  static Location fromCode(String? code) {
    if (code == null) return Location.invalid;
    final upper = code.trim().toUpperCase();
    for (final location in values) {
      if (location.code == upper) return location;
    }
    return Location.invalid;
  }

  /// The location whose critTable entry is this key, or null when the key is unknown.
  static Location fromCritKey(String? critKey) {
    for (final location in values) {
      if (location.critKey == critKey) return location;
    }
    return Location.invalid;
  }

  /// The location with this display name, or null when the name is empty or unknown.
  static Location fromLabel(String? label) {
    for (final location in values) {
      if (location.label == label) return location;
    }
    return Location.invalid;
  }
}
