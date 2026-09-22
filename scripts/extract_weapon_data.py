#!/usr/bin/env python3
"""Extract Battletech weapon data from a copied block of text lines into JSON.

This script makes certain assumptions about the structure and order of the text,
so as a result it doesn't actually extract all of the data from the Battletech Technical Manual.
I manually removed the "header" lines and "section" entries, as well as the more "equipment focused"
blocks of entries since they didn't comply with the pattern the other entries did. Since my
personal focus is on supporting app functionality for Force Packs and stock mech builds, it
seemed like a reasonable compromise.

Usage:
    python scripts/extract_weapon_data.py
"""

from typing import Tuple
import json
import re
import sys
from pathlib import Path

TECH_BASE_MAP = {
    "inner sphere": 0,
    "clan": 1,
    "mixed": 2,
    "pirate": 3,
    "unknown": 4,
}

TYPE_MAP = {
    "standard": 0,
    "shot": 1,
    "msl": 2,
}

ENTRY_RE = re.compile(
    r"^(.*?)\s+"
    r"([\d./A-Za-z-]+\s+\(\d+(?:/\d+)?\))\s+"  # heat
    r"([\d./A-Za-z-]+\s+\(\d+(?:/\d+)?\))\s+"  # damage
    r"(\S+\s+\([A-Za-z]+\))"                  # range
    r"(?:\s+(.*))?$"                          # remaining columns
)

def normalize_text(text: str) -> str:
    return re.sub(r"[ \t]+", " ", text).strip()


def parse_number(value: str, integer: bool = True):
    if not value:
        return None
    value = value.replace(",", "").replace("_", "")
    try:
        return int(value) if integer else float(value)
    except ValueError:
        try:
            return float(value) if not integer else int(float(value))
        except ValueError:
            return None


def parse_enum(value: str, mapping: dict[str, int], default: int = 0) -> int:
    if not value:
        return default
    normalized = value.lower().strip()
    if normalized in mapping:
        return mapping[normalized]
    for key in mapping:
        if key in normalized:
            return mapping[key]
    return default


def split_columns(line: str) -> list[str]:
    match = ENTRY_RE.match(line.strip())
    if not match:
        print(f"Unrecognized line: {line}")
        return[]

    name, heat, damage, ranges, remainder = match.groups()

    return [
        name,
        heat,
        damage,
        ranges,
        *(remainder.split() if remainder else []),
    ]

def keep_before_character(text: str, char: str) -> str:
    trimmed = "".join([ele for ele in text.split(char, 1)[0]])
    return trimmed

def parse_heat_and_damage(text: str) -> Tuple[int, int]:
    key_text = keep_before_character(text, "(")
    key_tokens = key_text.split("/")
    key_val = int(parse_number(key_tokens[0], integer=True)) or int(0)
    key_type = int(0)
    if len(key_tokens) > 1:
        key_type = parse_enum(key_tokens[1], TYPE_MAP, default=0)
    return (key_val, key_type)

def parse_weapon_rows(rows: list[str], tech: int = 0) -> list[dict[str, object | None]]:
    if not rows:
        return []

    parsed: list[dict[str, object | None]] = []
    for row in rows:
        row = normalize_text(row)
        entries = split_columns(row)
        if len(entries) < 6:
            continue
        item: dict[str, object | None] = {
            "type": entries[0],
            "heat": 0,
            "heatType": 0,
            "damage": 0,
            "damageType": 0,
            "minRange": 0,
            "shortRange": 0,
            "mediumRange": 0,
            "longRange": 0,
            "tons": entries[5] if len(entries) > 5 else 0,
            "techBase": tech,
        }

        # Heat and damage entry parsing
        item["heat"], item["heatType"] = parse_heat_and_damage(entries[1])
        item["damage"], item["damageType"] = parse_heat_and_damage(entries[2])

        # Range data
        range_text = keep_before_character(entries[3], "(")
        range_tokens = range_text.split('/')
        try:
            item["minRange"] = parse_number(range_tokens[0])
            item["shortRange"] = parse_number(range_tokens[1])
            item["mediumRange"] = parse_number(range_tokens[2])
            item["longRange"] = parse_number(range_tokens[3])
        except IndexError:
            print(item[0] + " had fewer than 4 range entries.")
        
        if item["type"]:
            parsed.append(item)
    return parsed


def main() -> int:
    output_json = Path('/home/chief/StudioProjects/battletech_combat_helper_v2/scripts/battletech_weapons.json')
    
    files_to_process = [
        '/home/chief/StudioProjects/battletech_combat_helper_v2/scripts/innersphereweapons.txt',
        '/home/chief/StudioProjects/battletech_combat_helper_v2/scripts/clantechweapons.txt',
    ]
    weapons: list[dict[str, object | None]] = []

    for filename, index in zip(files_to_process, range(len(files_to_process))):
        entry_lines = [];
        try:
            file = open(filename, 'r', encoding='utf-8')
        except OSError:
            print(f"Unable to open file {filename}, skipping")
            continue
        
        entry_lines = file.readlines()
        file.close()

        weapons_era = parse_weapon_rows(entry_lines, index)
        print(f"Parsed file {index}: {file.name} contained {len(weapons_era)} entries.")
        weapons.extend(weapons_era)

    output_json.parent.mkdir(parents=True, exist_ok=True)
    with output_json.open("w", encoding="utf-8") as fp:
        json.dump(weapons, fp, indent=2, ensure_ascii=False)

    print(f"Wrote {len(weapons)} weapon entries to {output_json}")
    return 0

if __name__ == "__main__":
    raise SystemExit(main())
