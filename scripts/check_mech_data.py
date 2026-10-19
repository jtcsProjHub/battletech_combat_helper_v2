# Flags extracted mech records that are likely to contain OCR errors, so manual review
# can focus on specific values instead of re-reading every record sheet.
# Usage: python check_mech_data.py [path/to/mechs.json]

import argparse
import json
import math
import re
import sys
from collections import Counter
from pathlib import Path

# Standard internal structure by tonnage: (center torso, side torso, arm, leg). Head is always 3.
STRUCTURE_TABLE = {
    20: (6, 5, 3, 4), 25: (8, 6, 4, 6), 30: (10, 7, 5, 7), 35: (11, 8, 6, 8),
    40: (12, 10, 6, 10), 45: (14, 11, 7, 11), 50: (16, 12, 8, 12), 55: (18, 13, 9, 13),
    60: (20, 14, 10, 14), 65: (21, 15, 10, 15), 70: (22, 15, 11, 15), 75: (23, 16, 12, 16),
    80: (25, 17, 13, 17), 85: (27, 18, 14, 18), 90: (29, 19, 15, 19), 95: (30, 20, 16, 20),
    100: (31, 21, 17, 21),
}
STRUCTURE_INDEX = {
    "center_torso": 0, "left_torso": 1, "right_torso": 1,
    "left_arm": 2, "right_arm": 2, "left_leg": 3, "right_leg": 3,
}
MAX_HEAD_ARMOR = 9
# Structure follows from tonnage, so a wrong value is corrected. If more locations than this disagree with the table,
# the tonnage is more likely to be the wrong value, and nothing is corrected.
MAX_STRUCTURE_CORRECTIONS = 2
# Engine rating is tonnage * walk, and no engine is rated above 400.
MAX_ENGINE_RATING = 400
# Walk for each possible run (run = ceil(walk * 1.5)); other run values cannot occur.
RUN_TO_WALK = {math.ceil(w * 1.5): w for w in range(1, 13)}
# Equipment that the record sheet lists among the weapons; it generates no heat, so a missing heat is expected.
NO_HEAT_EQUIPMENT = {"activeprobe", "apod", "tag", "targetingcomputer", "antimissilesystem", "ecmsuite", "narc", "hatchet", "ewequipment"}
# Ammo names that differ from the name of the weapon that uses them.
AMMO_WEAPON_ALIASES = {"ams": "antimissilesystem", "lb5x": "lb5xac", "lb2x": "lb2xac", "lb10x": "lb10xac", "gauss": "gaussrifle"}
# Ammo for a weapon that can use Artemis or Narc, or LB-X cluster ammo, is listed with a suffix; it is still ammo for that weapon.
AMMO_VARIANT_SUFFIX = re.compile(r"\s*(?:(?:narc|artemis)-capable|\s+cluster)$", re.IGNORECASE)
WEAPONS_DATABASE_FILE = Path(__file__).parent.parent / "assets" / "base_data" / "battletech_weapons.json"
weapons_database: list[dict[str, object | None]] = []


def load_weapons_database(path: Path) -> list[dict[str, object | None]]:
    """Loads the weapon database; its tonnage is stored as text, but the Dart model expects a number."""
    database = json.loads(path.read_text(encoding="utf-8"))
    for entry in database:
        if isinstance(entry.get("tons"), str):
            try:
                entry["tons"] = float(entry["tons"].replace(",", ""))
            except ValueError:
                entry["tons"] = None
    return database


def fill_from_database(weapon: dict, mech_tech_base) -> bool:
    """Fills missing heat/tons data from the database entry with the same name and the mech's tech base.
    Returns True if a matching entry exists (the weapon is then updated in place)."""
    match = next((entry for entry in weapons_database
                  if loose(entry.get("type", "")) == loose(weapon.get("type", "")) and entry.get("techBase") == mech_tech_base), None)
    if match is None:
        return False
    for field, value in match.items():
        if field == "type" or value is None:
            continue
        if weapon.get(field) is None or (field == "tons" and not is_number(weapon[field])):
            weapon[field] = value
    return True


def loose(name: str) -> str:
    """Lowercase and strip everything but letters and digits, so 'SRM 6' matches 'SRM6'."""
    return re.sub(r"[^a-z0-9]", "", str(name).lower())


def is_number(value) -> bool:
    return isinstance(value, (int, float)) and not isinstance(value, bool)


def key(name: str) -> str:
    """Search text that finds a JSON key in the pretty-printed file."""
    return f'"{name}":'


def check_mech(mech: dict) -> list[tuple[str, tuple[str, ...]]]:
    """Returns (message, path) pairs; path is a chain of search strings that locates the value in the file."""
    issues: list[tuple[str, tuple[str, ...]]] = []

    if not mech.get("variant"):
        issues.append(("variant is empty (id falls back to name only)", (key("variant"),)))

    tonnage = mech.get("tonnage")
    if not is_number(tonnage) or tonnage < 20 or tonnage > 100 or tonnage % 5:
        issues.append((f"tonnage {tonnage!r} is not a multiple of 5 between 20 and 100", (key("tonnage"),)))
        tonnage = None
    else:
        tonnage = int(tonnage)

    if mech.get("techBase", 0) == 0:
        issues.append(("techBase is unknown", (key("techBase"),)))
    if mech.get("role", 0) == 0:
        issues.append(("role is unknown", (key("role"),)))
    if not mech.get("engineType"):
        issues.append(("engineType is empty", (key("engineType"),)))
    if not mech.get("battleValue"):
        issues.append(("battleValue is missing or 0", (key("battleValue"),)))

    walk, run = mech.get("walk", 0), mech.get("run", 0)
    if not walk and run and tonnage is not None:
        inferred = RUN_TO_WALK.get(run)
        if inferred is None:
            issues.append((f"run {run} is not a possible run speed, so walk cannot be inferred", (key("run"),)))
        elif tonnage * inferred > MAX_ENGINE_RATING:
            issues.append((f"run {run} implies walk {inferred}, an engine rating over {MAX_ENGINE_RATING} at {tonnage} tons; walk not filled", (key("walk"),)))
        else:
            mech["walk"] = walk = inferred
            issues.append((f"walk was 0; inferred {inferred} from run {run} (review)", (key("walk"),)))
    elif walk and not run and tonnage is not None and tonnage * walk <= MAX_ENGINE_RATING:
        mech["run"] = run = math.ceil(walk * 1.5)
        issues.append((f"run was 0; inferred {run} from walk {walk} (review)", (key("run"),)))
    if not walk:
        issues.append(("walk is 0", (key("walk"),)))
    else:
        if run != math.ceil(walk * 1.5):
            issues.append((f"run {run} should be {math.ceil(walk * 1.5)} for walk {walk}", (key("run"),)))
        if tonnage is not None and tonnage * walk > MAX_ENGINE_RATING:
            issues.append((f"walk {walk} needs an engine rating of {tonnage * walk}, over {MAX_ENGINE_RATING}, at {tonnage} tons", (key("walk"),)))

    # Each jump jet adds one jump point, so the value should equal the number of Jump Jet entries in the crit table.
    crit_entries = [entry for entries in (mech.get("critTable") or {}).values() for entry in entries]
    jump_jets = sum("jump jet" in entry.lower() for entry in crit_entries)
    jump = mech.get("jump", 0)
    if not any("jump booster" in entry.lower() for entry in crit_entries):
        if not jump and jump_jets:
            mech["jump"] = jump_jets
            issues.append((f"jump was 0; filled {jump_jets} from the jump jets in critTable (review)", (key("jump"),)))
        elif jump != jump_jets:
            issues.append((f"jump {jump} but critTable lists {jump_jets} jump jets", (key("jump"),)))

    armor = mech.get("armorByLocation") or {}
    structure = mech.get("structureByLocation") or {}
    if tonnage is not None:
        expected = STRUCTURE_TABLE[tonnage]
        wrong = [location for location in STRUCTURE_INDEX if structure.get(location) != expected[STRUCTURE_INDEX[location]]]
        if wrong and (len(wrong) <= MAX_STRUCTURE_CORRECTIONS or not structure):
            mech["structureByLocation"] = structure = dict(structure)
            for location in wrong:
                issues.append((f"structure {location} was {structure.get(location)}; corrected to {expected[STRUCTURE_INDEX[location]]} for {tonnage} tons (review)",
                               (key("structureByLocation"), key(location),)))
                structure[location] = expected[STRUCTURE_INDEX[location]]
            if mech.get("structureTotal") != sum(structure.values()):
                issues.append((f"structureTotal was {mech.get('structureTotal')}; recalculated as {sum(structure.values())} (review)", (key("structureTotal"),)))
                mech["structureTotal"] = sum(structure.values())
    if mech.get("armorTotal") != sum(armor.values()):
        issues.append((f"armorTotal {mech.get('armorTotal')} != sum of locations {sum(armor.values())}", (key("armorTotal"),)))
    if mech.get("structureTotal") != sum(structure.values()):
        issues.append((f"structureTotal {mech.get('structureTotal')} != sum of locations {sum(structure.values())}", (key("structureTotal"),)))

    if tonnage is not None:
        for location, value in structure.items():
            if location in STRUCTURE_INDEX and value != expected[STRUCTURE_INDEX[location]]:
                issues.append((f"structure {location} {value} should be {expected[STRUCTURE_INDEX[location]]} for {tonnage} tons", (key("structureByLocation"), key(location),)))

    if armor.get("head", 0) > MAX_HEAD_ARMOR:
        issues.append((f"armor head {armor['head']} exceeds max {MAX_HEAD_ARMOR}", (key("armorByLocation"), key("head"),)))
    for location, value in structure.items():
        # Armor can be at most twice structure; torso front and rear share that limit.
        total = armor.get(location, 0) + armor.get(f"rear_{location}", 0)
        if total > 2 * value:
            issues.append((f"armor {location} {total} exceeds 2x structure ({2 * value})", (key("armorByLocation"), key(location),)))

    heat_sinks = mech.get("heatSinkTypeAndNumber") or [0, 0]
    hs_type, hs_count = heat_sinks if len(heat_sinks) == 2 else (0, 0)
    if hs_type == 0:
        issues.append(("heat sink type is unknown", (key("heatSinkTypeAndNumber"),)))
    if hs_count < 10:
        issues.append((f"heat sink count {hs_count} is below 10", (key("heatSinkTypeAndNumber"),)))
    if hs_type in (1, 2) and mech.get("maxHeat") != hs_type * hs_count:
        issues.append((f"maxHeat {mech.get('maxHeat')} should be {hs_type * hs_count}", (key("maxHeat"),)))

    # The engine holds up to one heat sink per 25 of its rating (tonnage * walk) without using crit slots. Any other sink
    # has entries in the crit table: one per single sink, three per Inner Sphere double sink, two per Clan double sink.
    # A designer may put sinks in slots that the engine could have held, so the crit table can list more than it must,
    # but never so few that the engine would have to hold more than its capacity, or more sinks than exist.
    slots = 1 if hs_type == 1 else {1: 3, 2: 2}.get(mech.get("techBase")) if hs_type == 2 else None
    if tonnage is not None and walk and slots:
        sink_name = "heat sink" if hs_type == 1 else "double heat sink"
        listed = sum(entry.lower() == sink_name for entry in crit_entries)
        capacity = (tonnage * walk) // 25
        in_engine = hs_count - listed / slots
        if listed % slots or in_engine < 0 or in_engine > capacity:
            issues.append((f"{hs_count} heat sinks with {listed} {sink_name} entries in critTable leaves {in_engine:g} in the engine, "
                           f"but a rating {tonnage * walk} engine holds at most {capacity}", (key("heatSinkTypeAndNumber"),)))

    weapons = mech.get("weapons") or []
    if not weapons:
        issues.append(("no weapons", (key("weapons"),)))
    for weapon in weapons:
        name = weapon.get("type", "")
        weapon_key = f'"type": {json.dumps(name, ensure_ascii=False)}'
        if re.match(r"^\W*\d+\.", name):
            issues.append((f"weapon {name!r} has a leading list marker", (key("weapons"), weapon_key,)))
        heat_missing = weapon.get("heat") is None and loose(name) not in NO_HEAT_EQUIPMENT
        tons_invalid = weapon.get("tons") is not None and not is_number(weapon.get("tons"))
        if (heat_missing or tons_invalid) and fill_from_database(weapon, mech.get("techBase")):
            heat_missing = weapon.get("heat") is None and loose(name) not in NO_HEAT_EQUIPMENT
            tons_invalid = weapon.get("tons") is not None and not is_number(weapon.get("tons"))
        if heat_missing:
            issues.append((f"weapon {name!r} has no heat (no match in weapon database?)", (key("weapons"), weapon_key,)))
        tons = weapon.get("tons")
        if tons_invalid:
            issues.append((f"weapon {name!r} tons {tons!r} is not a number (Dart loader will reject it)", (key("weapons"), weapon_key,)))

    weapon_names = {loose(w.get("type", "")) for w in weapons}
    for ammo_name, count in (mech.get("ammo") or {}).items():
        if count is None:
            issues.append((f"ammo {ammo_name!r} has no count", (key("ammo"), key(ammo_name),)))
        ammo_key = loose(AMMO_VARIANT_SUFFIX.sub("", ammo_name))
        if AMMO_WEAPON_ALIASES.get(ammo_key, ammo_key) not in weapon_names:
            issues.append((f"ammo {ammo_name!r} does not match any weapon", (key("ammo"), key(ammo_name),)))

    return issues


def mech_start_lines(text: str, expected: int) -> list[int] | None:
    """1-based line where each top-level mech object starts, or None if the file isn't laid out as expected."""
    starts = [number for number, line in enumerate(text.splitlines(), 1) if line == "  {"]
    return starts if len(starts) == expected else None


def locate(lines: list[str], start: int, end: int, path: tuple[str, ...]) -> int:
    """Line of the last search string in path, each searched for after the previous; falls back to the best match."""
    found = start
    for needle in path:
        for number in range(found, end + 1):
            if needle in lines[number - 1]:
                found = number
                break
    return found


def main() -> int:
    parser = argparse.ArgumentParser(description="Flag extracted mech records that need manual review")
    parser.add_argument("mechs_json", type=Path, nargs="?", default=Path(__file__).parent.parent / "assets" / "base_data" / "mechs_clean.json")
    args = parser.parse_args()

    text = args.mechs_json.read_text(encoding="utf-8")
    mechs = json.loads(text)
    lines = text.splitlines()
    starts = mech_start_lines(text, len(mechs))
    if starts is None:
        print("warning: unexpected JSON layout, line numbers unavailable\n", file=sys.stderr)
    ends = [s - 1 for s in starts[1:]] + [len(lines)] if starts else []

    global weapons_database
    try:
        weapons_database = load_weapons_database(WEAPONS_DATABASE_FILE)
    except (OSError, ValueError) as error:
        print(f"Unable to load {WEAPONS_DATABASE_FILE}, weapon data will not be filled in: {error}", file=sys.stderr)

    flagged = 0
    filled = 0
    for id_, count in Counter(m.get("id") for m in mechs).items():
        if count > 1:
            where = ""
            if starts:
                where = " at lines " + ", ".join(str(starts[i]) for i, m in enumerate(mechs) if m.get("id") == id_)
            print(f"Duplicate id {id_!r} used by {count} mechs{where}\n")
            flagged += 1

    for index, mech in enumerate(mechs):
        before = json.dumps(mech, sort_keys=True)
        issues = check_mech(mech)
        if json.dumps(mech, sort_keys=True) != before:
            filled += 1
        if issues:
            flagged += 1
            start = f" [line {starts[index]}]" if starts else ""
            print(f"{mech.get('id')} ({mech.get('name')} {mech.get('variant')}){start}")
            for message, path in issues:
                line = f"line {locate(lines, starts[index], ends[index], path)}: " if starts else ""
                print(f"  - {line}{message}")
            print()

    if filled:
        # Line numbers reported above refer to the file before this rewrite; filling in a missing key can shift them.
        args.mechs_json.write_text(json.dumps(mechs, indent=2, ensure_ascii=False), encoding="utf-8")
        print(f"{filled} mechs had data filled in (weapon database, inferred walk/run); {args.mechs_json} was rewritten")
    print(f"{flagged} of {len(mechs)} mechs flagged for review")
    return 1 if flagged else 0


if __name__ == "__main__":
    sys.exit(main())
