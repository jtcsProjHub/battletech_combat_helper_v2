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


def loose(name: str) -> str:
    """Lowercase and strip everything but letters and digits, so 'SRM 6' matches 'SRM6'."""
    return re.sub(r"[^a-z0-9]", "", str(name).lower())


def is_number(value) -> bool:
    return isinstance(value, (int, float)) and not isinstance(value, bool)


def check_mech(mech: dict) -> list[str]:
    issues: list[str] = []

    if not mech.get("model"):
        issues.append("model is empty (id falls back to name only)")

    tonnage = mech.get("tonnage")
    if not is_number(tonnage) or tonnage < 20 or tonnage > 100 or tonnage % 5:
        issues.append(f"tonnage {tonnage!r} is not a multiple of 5 between 20 and 100")
        tonnage = None
    else:
        tonnage = int(tonnage)

    if mech.get("techBase", 0) == 0:
        issues.append("techBase is unknown")
    if mech.get("role", 0) == 0:
        issues.append("role is unknown")
    if not mech.get("engineType"):
        issues.append("engineType is empty")
    if not mech.get("battleValue"):
        issues.append("battleValue is missing or 0")

    walk, run = mech.get("walk", 0), mech.get("run", 0)
    if not walk:
        issues.append("walk is 0")
    elif run != math.ceil(walk * 1.5):
        issues.append(f"run {run} should be {math.ceil(walk * 1.5)} for walk {walk}")

    armor = mech.get("armorByLocation") or {}
    structure = mech.get("structureByLocation") or {}
    if mech.get("armorTotal") != sum(armor.values()):
        issues.append(f"armorTotal {mech.get('armorTotal')} != sum of locations {sum(armor.values())}")
    if mech.get("structureTotal") != sum(structure.values()):
        issues.append(f"structureTotal {mech.get('structureTotal')} != sum of locations {sum(structure.values())}")

    if tonnage is not None:
        expected = STRUCTURE_TABLE[tonnage]
        for location, value in structure.items():
            if location in STRUCTURE_INDEX and value != expected[STRUCTURE_INDEX[location]]:
                issues.append(f"structure {location} {value} should be {expected[STRUCTURE_INDEX[location]]} for {tonnage} tons")

    if armor.get("head", 0) > MAX_HEAD_ARMOR:
        issues.append(f"armor head {armor['head']} exceeds max {MAX_HEAD_ARMOR}")
    for location, value in structure.items():
        # Armor can be at most twice structure; torso front and rear share that limit.
        total = armor.get(location, 0) + armor.get(f"rear_{location}", 0)
        if total > 2 * value:
            issues.append(f"armor {location} {total} exceeds 2x structure ({2 * value})")

    heat_sinks = mech.get("heatSinkTypeAndNumber") or [0, 0]
    hs_type, hs_count = heat_sinks if len(heat_sinks) == 2 else (0, 0)
    if hs_type == 0:
        issues.append("heat sink type is unknown")
    if hs_count < 10:
        issues.append(f"heat sink count {hs_count} is below 10")
    if hs_type in (1, 2) and mech.get("maxHeat") != hs_type * hs_count:
        issues.append(f"maxHeat {mech.get('maxHeat')} should be {hs_type * hs_count}")

    weapons = mech.get("weapons") or []
    if not weapons:
        issues.append("no weapons")
    for weapon in weapons:
        name = weapon.get("type", "")
        if re.match(r"^\W*\d+\.", name):
            issues.append(f"weapon {name!r} has a leading list marker")
        if weapon.get("heat") is None:
            issues.append(f"weapon {name!r} has no heat (no match in weapon database?)")
        tons = weapon.get("tons")
        if tons is not None and not is_number(tons):
            issues.append(f"weapon {name!r} tons {tons!r} is not a number (Dart loader will reject it)")

    weapon_names = {loose(w.get("type", "")) for w in weapons}
    for ammo_name, count in (mech.get("ammo") or {}).items():
        if count is None:
            issues.append(f"ammo {ammo_name!r} has no count")
        if loose(ammo_name) not in weapon_names:
            issues.append(f"ammo {ammo_name!r} does not match any weapon")

    return issues


def main() -> int:
    parser = argparse.ArgumentParser(description="Flag extracted mech records that need manual review")
    parser.add_argument("mechs_json", type=Path, nargs="?", default=Path(__file__).parent / "mechs.json")
    args = parser.parse_args()

    mechs = json.loads(args.mechs_json.read_text(encoding="utf-8"))

    flagged = 0
    for id_, count in Counter(m.get("id") for m in mechs).items():
        if count > 1:
            print(f"Duplicate id {id_!r} used by {count} mechs\n")
            flagged += 1

    for mech in mechs:
        issues = check_mech(mech)
        if issues:
            flagged += 1
            print(f"{mech.get('id')} ({mech.get('name')} {mech.get('model')})")
            for issue in issues:
                print(f"  - {issue}")
            print()

    print(f"{flagged} of {len(mechs)} mechs flagged for review")
    return 1 if flagged else 0


if __name__ == "__main__":
    sys.exit(main())
