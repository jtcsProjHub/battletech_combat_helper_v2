// File: lib/settings/dice_rolls.dart
// The dice rolls the app can make for the players, and which of them a
// player wants automated. Rolls are grouped in a tree that follows the
// sequence of play (BattleMech Manual, Playing the Game onward). A roll is
// automated only when it and every group above it are checked, so
// unchecking a group hands all of its rolls back to the players.
//
// Ids are saved in settings and skirmish files: rename a label freely, but
// never change an id.

/// One roll, or a group of rolls, in [rollCatalog].
class RollOption {
  const RollOption(
    this.id,
    this.label, {
    this.detail,
    this.children = const [],
  });

  final String id;
  final String label;

  /// When the roll is made, for the settings list.
  final String? detail;
  final List<RollOption> children;

  /// The option with [id], or null when the catalog has none.
  static RollOption? byId(String id) => _index[id];

  /// [id]'s option and every group above it, outermost first. Empty when
  /// the catalog has no such id.
  static List<RollOption> pathTo(String id) {
    final path = <RollOption>[];
    for (RollOption? o = _index[id]; o != null; o = _parents[o.id]) {
      path.insert(0, o);
    }
    return path;
  }

  /// This option and everything below it, depth first.
  Iterable<RollOption> get selfAndDescendants sync* {
    yield this;
    for (final c in children) {
      yield* c.selfAndDescendants;
    }
  }
}

/// Every roll the app knows, in sequence-of-play order.
const List<RollOption> rollCatalog = [
  RollOption(
    'initiative',
    'Initiative',
    children: [
      RollOption(
        'initiative.roll',
        'Initiative roll',
        detail:
            '2D6 per side each turn; ties are re-rolled. Also decides '
            'deployment sides.',
      ),
    ],
  ),
  RollOption(
    'movement',
    'Movement',
    children: [
      RollOption(
        'movement.psr',
        'Movement Piloting Skill Rolls',
        detail:
            'Running or jumping with gyro, hip or leg damage, changing '
            'levels, rubble, water and ice.',
      ),
      RollOption(
        'movement.standing',
        'Standing up',
        detail: 'Piloting Skill Roll when a prone ’Mech tries to stand.',
      ),
      RollOption(
        'movement.skid',
        'Skidding',
        detail:
            'Piloting Skill Roll when running ’Mechs turn on pavement or ice.',
      ),
      RollOption(
        'movement.masc',
        'MASC and supercharger',
        detail: 'Activation roll each turn the system is engaged.',
      ),
      RollOption(
        'movement.building',
        'Entering buildings',
        detail:
            'Piloting Skill Roll to avoid damage when moving into a building.',
      ),
    ],
  ),
  RollOption(
    'weapons',
    'Weapon attacks',
    children: [
      RollOption(
        'weapons.toHit',
        'To-hit rolls',
        detail: '2D6 against the modified Target Number for each weapon.',
      ),
      RollOption(
        'weapons.cluster',
        'Cluster hits',
        detail:
            'How many missiles or pellets hit, from the Cluster Hits Table.',
      ),
      RollOption(
        'weapons.location',
        'Hit location',
        detail: '2D6 on the Hit Location Table for each hit or cluster group.',
        children: [
          RollOption(
            'weapons.aimed',
            'Aimed shots',
            detail: '2D6 to see if an aimed shot strikes the chosen location.',
          ),
        ],
      ),
    ],
  ),
  RollOption(
    'physical',
    'Physical attacks',
    children: [
      RollOption(
        'physical.toHit',
        'To-hit rolls',
        detail: 'Punches, kicks, charges, death from above, clubs and pushes.',
      ),
      RollOption(
        'physical.location',
        'Hit location',
        detail:
            'Punch and Kick Location Tables (1D6), and the Hit Location '
            'Table for charges, death from above and clubs.',
      ),
      RollOption(
        'physical.psr',
        'Piloting Skill Rolls',
        detail:
            'For a ’Mech that is kicked, pushed, charged or hit by death '
            'from above, and for an attacker whose kick, charge or death '
            'from above misses.',
      ),
    ],
  ),
  RollOption(
    'damage',
    'Damage',
    children: [
      RollOption(
        'damage.critical',
        'Critical hit checks',
        detail:
            '2D6 on the Determining Critical Hits Table, including '
            'through-armor criticals.',
        children: [
          RollOption(
            'damage.criticalSlot',
            'Critical slot',
            detail: '1D6 rolls that pick the block and slot that is hit.',
          ),
        ],
      ),
      RollOption(
        'damage.psr',
        'Damage Piloting Skill Rolls',
        detail:
            '20 or more damage in one phase, and gyro, hip, leg and '
            'actuator critical hits.',
      ),
    ],
  ),
  RollOption(
    'falls',
    'Falls',
    children: [
      RollOption(
        'falls.facing',
        'Facing after a fall',
        detail: '1D6 on the Facing After Fall Table.',
      ),
      RollOption(
        'falls.location',
        'Falling damage location',
        detail: 'Hit Location Table roll for each 5-point group of damage.',
      ),
      RollOption(
        'falls.pilot',
        'MechWarrior damage',
        detail:
            'Piloting Skill Roll to keep the MechWarrior from being hurt '
            'in the fall.',
      ),
    ],
  ),
  RollOption(
    'pilot',
    'MechWarrior',
    children: [
      RollOption(
        'pilot.consciousness',
        'Consciousness rolls',
        detail: 'After each hit the MechWarrior takes.',
      ),
      RollOption(
        'pilot.recovery',
        'Recovering consciousness',
        detail: 'End Phase roll for an unconscious MechWarrior.',
      ),
    ],
  ),
  RollOption(
    'heat',
    'Heat',
    children: [
      RollOption(
        'heat.shutdown',
        'Shutdown avoidance',
        detail: 'Heat Phase roll at 14 or more heat.',
      ),
      RollOption(
        'heat.restart',
        'Restart',
        detail: 'Heat Phase roll to restart a ’Mech shut down by heat.',
      ),
      RollOption(
        'heat.ammo',
        'Ammunition explosion avoidance',
        detail: 'Heat Phase roll at 19 or more heat.',
      ),
    ],
  ),
];

final Map<String, RollOption> _index = {
  for (final top in rollCatalog)
    for (final o in top.selfAndDescendants) o.id: o,
};

final Map<String, RollOption> _parents = {
  for (final o in _index.values)
    for (final c in o.children) c.id: o,
};

/// Which rolls a player wants the app to make. Everything is automated
/// unless unchecked, so rolls added in later versions start automated.
class RollPreferences {
  const RollPreferences([this.unchecked = const {}]);

  /// Every roll automated.
  static const automated = RollPreferences();

  /// Ids of the options turned off. A group's id here turns off all the
  /// rolls below it while keeping their own checks for later.
  final Set<String> unchecked;

  /// The option's own check, ignoring the groups above it.
  bool isChecked(String id) => !unchecked.contains(id);

  /// True when the app makes this roll: it and every group above it are
  /// checked.
  bool isAutomated(String id) {
    final path = RollOption.pathTo(id);
    return path.isEmpty ? isChecked(id) : path.every((o) => isChecked(o.id));
  }

  RollPreferences withChecked(String id, {required bool checked}) =>
      RollPreferences(
        Set.unmodifiable(
          checked ? (unchecked.toSet()..remove(id)) : {...unchecked, id},
        ),
      );

  bool get isAllAutomated => unchecked.isEmpty;

  Map<String, Object?> toJson() => {'unchecked': unchecked.toList()..sort()};

  /// Ids the catalog no longer has are dropped.
  factory RollPreferences.fromJson(Object? json) {
    final list = json is Map ? json['unchecked'] : null;
    if (list is! List) return automated;
    return RollPreferences(
      Set.unmodifiable({
        for (final id in list)
          if (id is String && _index.containsKey(id)) id,
      }),
    );
  }

  @override
  bool operator ==(Object other) =>
      other is RollPreferences &&
      other.unchecked.length == unchecked.length &&
      other.unchecked.containsAll(unchecked);

  @override
  int get hashCode => Object.hashAllUnordered(unchecked);
}
