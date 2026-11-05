// File: lib/era.dart
// The BattleTech eras in timeline order, as named by the Master Unit List. The declaration order is the timeline,
// so eras compare by index (era >= Era.starLeague); the label is the name used in the JSON data.
// The start year is the MUL's nominal one, for display only: a unit's intro year can fall slightly outside its
// era's nominal span, so never classify units by year.

enum Era {
  ageOfWar('Age of War', 2005),
  starLeague('Star League', 2571),
  earlySuccessionWar('Early Succession War', 2781),
  lateSuccessionWarLosTech('Late Succession War - LosTech', 2901),
  lateSuccessionWarRenaissance('Late Succession War - Renaissance', 3020),
  clanInvasion('Clan Invasion', 3050),
  civilWar('Civil War', 3062),
  jihad('Jihad', 3068),
  earlyRepublic('Early Republic', 3081),
  lateRepublic('Late Republic', 3101),
  darkAge('Dark Age', 3131),
  ilClan('ilClan', 3151);

  const Era(this.label, this.startYear);

  final String label;
  final int startYear;

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
