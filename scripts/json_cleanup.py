# I noticed a bunch of random characters at the beginning and end of entries in the mech database
# from the initial extraction, so this quick script handles those easy cleanup steps.
# Also everything is more complicated than you think it will be.

import difflib
import json
import re
import sys
from pathlib import Path

from check_mech_data import NO_HEAT_EQUIPMENT, WEAPONS_DATABASE_FILE, load_weapons_database, loose

AMMO_PREFIX = re.compile(r"ammo\b", re.IGNORECASE)
# Values under these keys are left as they are: "name" is already clean, and the intro era comes from the MUL, not OCR.
UNTOUCHED_KEYS = {"name", "introEra"}


def strip_non_alnum(text, allowed_end=""):
    """Remove leading and trailing characters that are not letters or numbers.

    Characters in allowed_end are also kept when they appear at the end.
    """
    start = 0
    end = len(text)
    while start < end and not text[start].isalnum():
        start += 1
    while end > start and not (text[end - 1].isalnum() or text[end - 1] in allowed_end):
        end -= 1
    return text[start:end]


def clean_value(text):
    """Clean a string value; values starting with the word "ammo" may end with a single ')'."""
    cleaned = strip_non_alnum(text)
    if AMMO_PREFIX.match(cleaned):
        return re.sub(r"\)+$", ")", strip_non_alnum(text, allowed_end=")"))
    return cleaned


def clean(node):
    """Recursively clean every key and string value in a nested JSON structure.

    Values under an UNTOUCHED_KEYS key are left untouched (the key itself is still cleaned).
    """
    if isinstance(node, dict):
        return {
            strip_non_alnum(k): v if k in UNTOUCHED_KEYS else clean(v)
            for k, v in node.items()
        }
    if isinstance(node, list):
        return [clean(item) for item in node]
    if isinstance(node, str):
        return clean_value(node)
    return node


# Which critTable entries describe the equipment mounted at a weapon's location.
LOCATION_CRIT_TABLES = {
    "LA": ["crit_left_arm", "crit_left_side"], "RA": ["crit_right_arm", "crit_right_side"],
    "LT": ["crit_left_torso"], "RT": ["crit_right_torso"], "CT": ["crit_center_torso"],
    "HD": ["crit_head"], "LL": ["crit_left_leg"], "RL": ["crit_right_leg"],
}
WEAPON_ALIASES = [(r"^AC/(\d+)", r"Autocannon/\1")]
AMMO_SUFFIX = re.compile(r"\s+(?:(?:Narc|Naro|Artemis)-capable|Cluster)$", re.IGNORECASE)
# A fuzzy match is only used when it is this similar and clearly better than the runner-up.
MATCH_CUTOFF = 0.55
AMMO_CUTOFF = 0.7
MATCH_MARGIN = 0.15


def normalize_weapon_name(name: str) -> str:
    """Removes what the record sheet adds around a weapon name: a rear-facing marker '(R', a location suffix,
    a vendor in brackets ('(Beagle'), and writes AC/5 as Autocannon/5 like the weapon database does."""
    name = re.sub(r"\s*[({\[]\s*R\)?\s*$", "", name.strip())
    name = re.sub(r"\s+(LT|RT|CT|LA|RA|HD|LL|RL)$", "", name)
    name = re.sub(r"\s*\((Beagle|Guardian|Angel|Bloodhound|Light|Clan|IS)\b.*$", "", name)
    for pattern, replacement in WEAPON_ALIASES:
        name = re.sub(pattern, replacement, name)
    return name.strip()


def fix_weapon_names(mech: dict, known: set[str]) -> list[str]:
    """Renames weapons whose name is not in the weapon database, first by cleaning up the name and then by
    comparing it with the equipment in the critTable at the same location. Returns what was changed."""
    changes = []
    for weapon in mech.get("weapons") or []:
        name = weapon.get("type", "")
        if loose(name) in known:
            continue
        fixed = normalize_weapon_name(name)
        if loose(fixed) not in known:
            crit = {normalize_weapon_name(entry) for table in LOCATION_CRIT_TABLES.get(weapon.get("location"), [])
                    for entry in (mech.get("critTable") or {}).get(table, []) if not entry.startswith("Ammo")}
            ranked = sorted(((difflib.SequenceMatcher(None, loose(fixed), loose(entry)).ratio(), entry)
                             for entry in crit if loose(entry) in known), reverse=True)
            if not ranked or ranked[0][0] < MATCH_CUTOFF or (len(ranked) > 1 and ranked[0][0] - ranked[1][0] < MATCH_MARGIN):
                continue
            fixed = ranked[0][1]
        changes.append(f"weapon {name!r} -> {fixed!r}")
        weapon["type"] = fixed
    return changes


def fix_ammo_names(mech: dict) -> list[str]:
    """Renames ammo that does not match any weapon on the mech to the closest weapon name, keeping a 'Cluster' or
    '-capable' suffix. Ammo for weapons that are themselves unrecognised is left for the checker to flag."""
    weapon_names = {weapon.get("type", "") for weapon in mech.get("weapons") or []}
    weapon_keys = {loose(name) for name in weapon_names}
    changes, ammo = [], {}
    for ammo_name, count in (mech.get("ammo") or {}).items():
        suffix = AMMO_SUFFIX.search(ammo_name)
        base = ammo_name[:suffix.start()] if suffix else ammo_name
        base = re.sub(r"^AG/", "AC/", base)
        if loose(base) not in weapon_keys and loose(normalize_weapon_name(base)) in weapon_keys:
            base = normalize_weapon_name(base)
        elif loose(base) not in weapon_keys:
            ranked = sorted(((difflib.SequenceMatcher(None, loose(normalize_weapon_name(base)), loose(name)).ratio(), name)
                             for name in weapon_names), reverse=True)
            if ranked and ranked[0][0] >= AMMO_CUTOFF and (len(ranked) == 1 or ranked[0][0] - ranked[1][0] >= 0.1 or ranked[0][1] == ranked[1][1]):
                base = ranked[0][1]
        fixed = base + (suffix.group(0).replace("Naro", "Narc") if suffix else "")
        if fixed != ammo_name:
            changes.append(f"ammo {ammo_name!r} -> {fixed!r}")
        ammo[fixed] = count
    mech["ammo"] = ammo
    return changes


def fix_equipment_names(mechs: list[dict]) -> int:
    """Applies the weapon and ammo name fixes to every mech and prints each change. Returns how many changed."""
    database = load_weapons_database(WEAPONS_DATABASE_FILE)
    known = {loose(entry.get("type", "")) for entry in database} | NO_HEAT_EQUIPMENT
    changed = 0
    for mech in mechs:
        changes = fix_weapon_names(mech, known) + fix_ammo_names(mech)
        if changes:
            changed += 1
            print(f"{mech.get('id')}: " + "; ".join(changes))
    return changed


def main():
    in_path = sys.argv[1] if len(sys.argv) > 1 else str(Path(__file__).parent.parent / "assets" / "base_data" / "mechs_clean.json")
    out_path = sys.argv[2] if len(sys.argv) > 2 else in_path

    with open(in_path, "r", encoding="utf-8") as file:
        mechs_db = json.load(file)

    mechs_db = clean(mechs_db)
    changed = fix_equipment_names(mechs_db)
    print(f"{changed} mechs had weapon or ammo names corrected")

    with open(out_path, "w", encoding="utf-8") as file:
        json.dump(mechs_db, file, indent=2, ensure_ascii=False)


if __name__ == "__main__":
    main()
