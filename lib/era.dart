// File: lib/era.dart
// The BattleTech eras in timeline order, as named by the Master Unit List. The declaration order is the timeline,
// so eras compare by index (era >= Era.starLeague); the label is the name used in the JSON data.
// Years are deliberately not stored: a unit's intro year can fall slightly outside its era's nominal span.

enum Era {
  ageOfWar('Age of War'),
  starLeague('Star League'),
  earlySuccessionWar('Early Succession War'),
  lateSuccessionWarLosTech('Late Succession War - LosTech'),
  lateSuccessionWarRenaissance('Late Succession War - Renaissance'),
  clanInvasion('Clan Invasion'),
  civilWar('Civil War'),
  jihad('Jihad'),
  earlyRepublic('Early Republic'),
  lateRepublic('Late Republic'),
  darkAge('Dark Age'),
  ilClan('ilClan');

  const Era(this.label);

  final String label;

  bool operator <(Era other) => index < other.index;
  bool operator <=(Era other) => index <= other.index;
  bool operator >(Era other) => index > other.index;
  bool operator >=(Era other) => index >= other.index;

  /// The era with this MUL name, or null when the name is empty or unknown.
  static Era? fromLabel(String? label) {
    for (final era in values) {
      if (era.label == label) return era;
    }
    return null;
  }
}
