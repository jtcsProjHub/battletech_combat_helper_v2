# Reads saved Master Unit List (masterunitlist.battletech.com) unit pages and uses them to fill in or correct
# MUL slug, tonnage, battle value, intro year, role and tech base in the extracted mech JSON, plus intro era.
# Every unit page also lists all variants of its chassis, but only with tonnage, intro year, tech base, BV and role.
# The intro era and the faction/era availability are read from the page of the unit itself, so each variant needs its own
# saved page for them.
# The site sits behind a Cloudflare challenge, so pages have to be saved from a browser; this script only reads them.
#
# Usage:
#   python mul_lookup.py parse <page.html | folder> ... [--cache mul_cache.json]
#   python mul_lookup.py merge [mechs.json] [--cache mul_cache.json] [--write]
#   python mul_lookup.py needed [mechs.json] [--cache mul_cache.json] > mul_pages_needed.md

import argparse
import difflib
import json
import re
import sys
from pathlib import Path

from bs4 import BeautifulSoup

DEFAULT_CACHE = Path(__file__).parent.parent / "assets" / "base_data" / "mul_cache.json"
DEFAULT_MECHS = Path(__file__).parent.parent / "assets" / "base_data" / "mechs_clean.json"

# Mirrors the Role and TechBase enums in mech_data.dart (and ROLE_MAP/TECH_BASE_MAP in extract_mech_data.py).
ROLE_INDEX = {"ambusher": 1, "brawler": 2, "juggernaut": 3, "missile boat": 4, "scout": 5, "skirmisher": 6, "sniper": 7, "striker": 8}
TECH_BASE_INDEX = {"inner sphere": 1, "clan": 2, "mixed": 3, "pirate": 4}
# A fuzzy variant suggestion is only offered above this similarity; suggestions are never applied automatically.
SUGGESTION_CUTOFF = 0.7


def loose(text: str) -> str:
    """Lowercase and strip everything but letters and digits."""
    return re.sub(r"[^a-z0-9]", "", str(text).lower())


def clean_chassis(name: str) -> str:
    """Repairs known OCR damage in a chassis name: '||' for 'II', and a variant that leaked into the name ('Crab CRB-2')."""
    name = re.sub(r"^V+arhawk", "Warhawk", name.replace("||", "II"))            # 'VVarhawk' is a misread 'Warhawk'
    return re.sub(r"\s+[A-Z]{2,4}-\w+$", "", name).strip()


def chassis_keys(name: str) -> set[str]:
    """Lookup keys for a chassis name. 'Fire Moth (Dasher)' also matches 'Dasher (Fire Moth)' or either name alone.
    Stray brackets from OCR ('Arctic Cheetah (Hankyu]}') are ignored."""
    outer, inner = (re.split(r"[(\[{]", clean_chassis(name), maxsplit=1) + [""])[:2]
    outer, inner = outer.strip(), re.sub(r"[\]})]", "", inner).strip()
    keys = {loose(outer + inner)}
    if inner:
        keys |= {loose(outer), loose(inner), loose(inner + outer)}
    keys.discard("")
    return keys


def variant_keys(label: str) -> list[str]:
    """Keys for a variant label, most specific first: 'COM-7Y2 "Blazing Inferno"' also matches 'COM-7Y2'."""
    base = re.sub(r"\s*(\".*?\"|\(.*?\))", "", label).strip()
    return [k for k in dict.fromkeys([loose(label), loose(base)]) if k]


def plain_dash(text: str) -> str:
    """The MUL writes era names with an en dash ('Late Succession War – LosTech'); a hyphen is easier to type and lint."""
    return text.replace("\u2013", "-")


def to_int(text: str) -> int | None:
    digits = re.sub(r"[^\d]", "", text or "")
    return int(digits) if digits else None


def parse_row(chassis: str, variant: str, slug: str, tonnage: str, intro: str, tech: str, bv: str, role: str) -> dict:
    return {
        "chassis": chassis, "variant": variant, "slug": slug,
        "tonnage": to_int(tonnage), "introYear": to_int(intro), "introEra": None, "availability": None,
        "techBase": tech.strip() or None,
        "battleValue": to_int(bv), "role": None if role.strip() in ("", "None") else role.strip(),
    }


def parse_intro_era(soup: BeautifulSoup) -> str | None:
    """Returns the era label after the intro year on the page of the unit being viewed ('Star League'), if it has one."""
    for key in soup.select(".u-kv .k"):
        if key.get_text(strip=True) == "Intro Year":
            label = re.search(r"\(([^)]*)\)", key.find_next_sibling("span").get_text(" ", strip=True))
            return plain_dash(label.group(1).strip()) if label else None
    return None


def parse_availability(soup: BeautifulSoup) -> dict[str, list[str]] | None:
    """Returns the factions that can field the unit in each era, from the page's availability table, as
    {era name: [faction, ...]} in timeline order. Eras nobody has availability in are left out; None if the page has no table.
    A table cell holds a link (whose title is 'Faction · Era Name') where the faction has availability, and a dash where not."""
    table = soup.select_one("table.amx")
    if table is None:
        return None
    availability: dict[str, list[str]] = {}
    for row in table.select("tbody tr"):
        faction = row.td.get_text(" ", strip=True)
        for column, cell in enumerate(row.find_all("td")[1:]):
            link = cell.find("a")
            if link is not None:
                availability.setdefault((column, plain_dash(link.get("title", "").split("·")[-1].strip())), []).append(faction)
    return {era: factions for (_, era), factions in sorted(availability.items())}


def parse_page(html: str) -> list[dict]:
    """Returns one record per variant listed on a unit page (including the unit being viewed)."""
    soup = BeautifulSoup(html, "html.parser")
    heads = [h.get_text(" ", strip=True) for h in soup.select(".bar-head") if "Related Variants" in h.get_text()]
    if not heads:
        return []
    chassis = heads[0].split("·", 1)[-1].strip()
    records = []
    for row in soup.select("table.vmx tbody tr"):
        cells = row.find_all("td")
        link = cells[0].find("a") if cells else None
        if link is None or len(cells) < 7:
            continue
        viewing = any(b.get_text(strip=True) == "Viewing" for b in link.select(".vbadge"))
        for badge in link.select(".vbadge"):
            badge.decompose()
        slug = link["href"].rstrip("/").rsplit("/", 1)[-1]
        tonnage, intro, tech, bv, _pv, role = (c.get_text(strip=True) for c in cells[1:7])
        records.append(parse_row(chassis, link.get_text(" ", strip=True), slug, tonnage, intro, tech, bv, role))
        if viewing:
            records[-1]["introEra"] = parse_intro_era(soup)
            records[-1]["availability"] = parse_availability(soup)
    return records


def command_parse(args) -> int:
    cache = json.loads(args.cache.read_text(encoding="utf-8")) if args.cache.exists() else {}
    files = [f for path in args.pages for f in (sorted(path.glob("*.html")) if path.is_dir() else [path])]
    for file in files:
        records = parse_page(file.read_text(encoding="utf-8", errors="replace"))
        if not records:
            print(f"{file.name}: no variant table found, skipped")
            continue
        for record in records:
            previous = cache.get(record["slug"], {})
            for field in ("introEra", "availability"):  # another variant's page must not erase these
                record[field] = record[field] or previous.get(field)
            cache[record["slug"]] = record
        print(f"{file.name}: {len(records)} variants of {records[0]['chassis']}")
    args.cache.write_text(json.dumps(cache, indent=2, ensure_ascii=False), encoding="utf-8")
    print(f"{len(cache)} units in {args.cache}")
    return 0


# Characters OCR commonly confuses; a variant is compared to MUL variants with each of these folded together.
CONFUSABLE = str.maketrans({"O": "0", "Q": "0", "o": "0", "S": "5", "s": "5", "/": "7", "l": "1", "I": "1", "|": "1", "B": "8", "G": "6"})
BASE_LABEL = "(Base)"  # how the MUL labels the first variant of a chassis


def suggestions(mech: dict, candidates: list[dict]) -> str:
    """Names the MUL variants closest to an unmatched variant, ranked with OCR confusions in mind and limited to the
    mech's tonnage when that is valid. These are hints for manual review and are never applied."""
    tonnage = mech.get("tonnage")
    pool = [r for r in candidates if r["tonnage"] == tonnage] or candidates
    fold = lambda text: re.sub(r"[^A-Z0-9]", "", text.translate(CONFUSABLE).upper())
    ranked = sorted(((difflib.SequenceMatcher(None, fold(mech.get("variant", "")), fold(r["variant"])).ratio(), r) for r in pool),
                    key=lambda pair: -pair[0])
    best = [f"{r['variant']} ({r['tonnage']}t, BV {r['battleValue']})" for score, r in ranked[:3] if score >= SUGGESTION_CUTOFF]
    return f"; closest MUL variants: {', '.join(best)}" if best else ""


def find_record(mech: dict, by_chassis: dict[str, list[dict]]) -> tuple[dict | None, str]:
    """Returns (record, note). Only exact chassis and variant matches are returned as records.
    The MUL labels a chassis's first variant '(Base)', which is how a blank variant or one that is really the other
    half of the name ('Howler' + 'Baboon', 'Hunchback' + 'IIC') is matched."""
    name, variant = mech.get("name", ""), mech.get("variant", "").strip()
    joined = loose(clean_chassis(name) + variant)
    candidates = {r["slug"]: r for key in chassis_keys(name) | {joined} for r in by_chassis.get(key, [])}
    if not candidates:
        return None, "no MUL page cached for this chassis"
    leaked = re.search(r"\s+([A-Z]{2,4}-\w+)$", name)  # 'Crab CRB-2' + '7' is the variant CRB-27
    wanted = loose((leaked.group(1) if leaked else "") + variant)
    for pass_index in (0, 1):
        # Pass 0 compares full labels; pass 1 also allows the label without its nickname, when that is unambiguous.
        matches = [r for r in candidates.values() if wanted in variant_keys(r["variant"])[:pass_index + 1]]
        if wanted and len(matches) == 1:
            return matches[0], ""
    bases = [r for r in candidates.values() if r["variant"] == BASE_LABEL and (not variant or joined in chassis_keys(r["chassis"]))]
    if len(bases) == 1:
        return bases[0], ""
    variants = sorted({r["variant"] for r in candidates.values()})
    return None, f"variant {variant!r} not found among {len(variants)} MUL variants{suggestions(mech, list(candidates.values()))}"


def merge_record(mech: dict, record: dict) -> list[str]:
    """Applies MUL values to the mech and returns a description of each change.
    Tonnage and BV take the MUL value (BV was checked against the printed manuals); MUL slug, intro year, era,
    role and tech base only fill in missing values, and a disagreement is reported but left for manual review."""
    notes = []
    for field in ("tonnage", "battleValue"):
        value = record[field]
        if value is not None and mech.get(field) != value and mech.get(field) != float(value):
            notes.append(f"{field} {mech.get(field)!r} -> {value}")
            mech[field] = float(value) if field == "tonnage" else value
    wanted = {"mulSlug": record["slug"], "introYear": record["introYear"], "introEra": record["introEra"],
              "role": ROLE_INDEX.get((record["role"] or "").lower()),
              "techBase": TECH_BASE_INDEX.get((record["techBase"] or "").lower())}
    for field, value in wanted.items():
        if value is None:
            continue
        if not mech.get(field):
            notes.append(f"{field} {mech.get(field)!r} -> {value}")
            mech[field] = value
        elif mech[field] != value:
            notes.append(f"{field} is {mech[field]!r} but MUL says {value} (left unchanged, review)")
    return notes


def command_merge(args) -> int:
    cache = json.loads(args.cache.read_text(encoding="utf-8"))
    by_chassis: dict[str, list[dict]] = {}
    for record in cache.values():
        for key in chassis_keys(record["chassis"]):
            by_chassis.setdefault(key, []).append(record)

    mechs = json.loads(args.mechs_json.read_text(encoding="utf-8"))
    changed = unmatched = 0
    missing_chassis: dict[str, int] = {}
    for mech in mechs:
        record, note = find_record(mech, by_chassis)
        if record is None:
            unmatched += 1
            if note.startswith("no MUL page"):
                missing_chassis[mech.get("name", "")] = missing_chassis.get(mech.get("name", ""), 0) + 1
            else:
                print(f"{mech.get('id')}: {note}")
            continue
        notes = merge_record(mech, record)
        if notes:
            changed += 1
            print(f"{mech.get('id')} <- {record['slug']}")
            for line in notes:
                print(f"  - {line}")
    if missing_chassis:
        print("\nSave a MUL page for each of these chassis to cover the rest:")
        for name, count in sorted(missing_chassis.items()):
            print(f"  {name} ({count} mechs)")
    print(f"\n{changed} mechs changed, {unmatched} of {len(mechs)} not matched")
    if args.write:
        args.mechs_json.write_text(json.dumps(mechs, indent=2, ensure_ascii=False), encoding="utf-8")
        print(f"{args.mechs_json} was rewritten")
    else:
        print("dry run; pass --write to update the file")
    return 0


def slugify(text: str) -> str:
    return re.sub(r"[^a-z0-9]+", "-", text.lower()).strip("-")


def suspect(mech: dict) -> int:
    """Rough count of OCR damage in a mech's name and variant; the lowest-scoring mech of a chassis makes the most
    reliable page to look up, because its slug is the most likely to match the real one."""
    variant = mech.get("variant", "")
    score = 0
    score += 5 * bool(re.search(r"[^A-Za-z0-9\- ]", variant))                   # stray symbols ('JR/-D', 'BSW-X\u20181')
    score += 3 * bool(re.search(r"[\]}|]", mech.get("name", "")))           # leftover brackets in the name
    score += 2 * bool(re.search(r"[OQo]", variant) and variant != "Prime")       # O/Q/o are often a misread 0
    score += 2 * bool(re.search(r"[a-z]", variant.replace("Prime", "")))       # lower case where a variant is upper case
    return score


def command_needed(args) -> int:
    """Lists every variant as a checklist: [x] where its own page is already in the cache (it has an intro era), [ ] where
    one still has to be saved. A variant the cache already knows from another variant's page gets its exact MUL URL;
    otherwise the URL comes from the mech's id, which is the slugified name and variant as the MUL builds its own URLs."""
    cache = json.loads(args.cache.read_text(encoding="utf-8")) if args.cache.exists() else {}
    by_chassis: dict[str, list[dict]] = {}
    for record in cache.values():
        for key in chassis_keys(record["chassis"]):
            by_chassis.setdefault(key, []).append(record)
    mechs = json.loads(args.mechs_json.read_text(encoding="utf-8"))
    groups: dict[str, list[tuple[dict, dict | None]]] = {}
    for mech in mechs:
        record, _ = find_record(mech, by_chassis)
        name = clean_chassis(mech.get("name", ""))
        groups.setdefault(loose(re.split(r"[(\[{]", name)[0]), []).append((mech, record))
    have = lambda record: bool(record and record["introEra"])
    saved = sum(have(record) for group in groups.values() for _, record in group)
    print(f"# MUL pages to save: {len(mechs) - saved} of {len(mechs)} (one per variant; intro year and era are per variant)\n")
    print(f"{saved} variants are already saved ([x]).\n")
    print("Open the URL and save the page as HTML. If it 404s, search the MUL for the unit.")
    print("A '?' marks a URL built from OCR-damaged text (stray symbols in the variant or name), so it may not exist.")
    print("No mark means the URL is the exact MUL link, taken from another variant's page.\n")
    for _, group in sorted(groups.items()):
        names = sorted({clean_chassis(m["name"]) for m, _ in group}, key=len, reverse=True)
        title = re.sub(r"[\]}]+$", ")" if "(" in names[0] else "", names[0]).replace("))", ")")
        todo = sum(not have(record) for _, record in group)
        print(f"- {title} ({todo} of {len(group)} still to save)")
        for mech, record in sorted(group, key=lambda pair: (have(pair[1]), pair[1] is None, suspect(pair[0]))):
            slug = record["slug"] if record else slugify(mech["id"])
            doubt = "?" if record is None and suspect(mech) else " "
            print(f"  - [{'x' if have(record) else ' '}] {doubt} https://masterunitlist.battletech.com/units/{slug}   (variant {mech.get('variant', '')!r})")
    return 0


def main() -> int:
    parser = argparse.ArgumentParser(description="Fill in mech data from saved Master Unit List pages")
    commands = parser.add_subparsers(dest="command", required=True)
    parse = commands.add_parser("parse", help="read saved unit pages into the cache")
    parse.add_argument("pages", type=Path, nargs="+", help="saved .html files or folders of them")
    parse.add_argument("--cache", type=Path, default=DEFAULT_CACHE)
    needed = commands.add_parser("needed", help="list the fewest pages still to save, as a markdown checklist")
    needed.add_argument("mechs_json", type=Path, nargs="?", default=DEFAULT_MECHS)
    needed.add_argument("--cache", type=Path, default=DEFAULT_CACHE)
    merge = commands.add_parser("merge", help="apply the cache to the mech JSON")
    merge.add_argument("mechs_json", type=Path, nargs="?", default=DEFAULT_MECHS)
    merge.add_argument("--cache", type=Path, default=DEFAULT_CACHE)
    merge.add_argument("--write", action="store_true", help="rewrite the mech JSON (default is a dry run)")
    args = parser.parse_args()
    return {"parse": command_parse, "merge": command_merge, "needed": command_needed}[args.command](args)


if __name__ == "__main__":
    sys.exit(main())
