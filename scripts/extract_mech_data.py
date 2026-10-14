#!/usr/bin/env python3
"""Extract Battletech mech data from a PDF into JSON.

This script assumes each page is an image-based page with a repeated layout.
It uses OCR via Tesseract and PDF-to-image conversion via poppler.

Install dependencies:
    pip install pdf2image pytesseract pillow
Install system packages:
    sudo apt-get install poppler-utils tesseract-ocr

Usage:
    python scripts/extract_mech_data.py input.pdf output.json
"""

from __future__ import annotations

import argparse
from ast import Tuple
import json
import re
import sys
from dataclasses import dataclass
from pathlib import Path
from PIL import Image

try:
    from pdf2image import convert_from_path, pdfinfo_from_path
except ImportError as exc:
    raise SystemExit(
        "Missing Python dependency pdf2image. Install it with: pip install pdf2image"
    ) from exc

try:
    import pytesseract
except ImportError as exc:
    raise SystemExit(
        "Missing Python dependency pytesseract. Install it with: pip install pytesseract"
    ) from exc

try:
    from PIL import Image, ImageDraw
except ImportError as exc:
    raise SystemExit(
        "Missing Python dependency pillow. Install it with: pip install pillow"
    ) from exc

TECH_BASE_MAP = {
    "unknown": 0,
    "inner sphere": 1,
    "clan": 2,
    "mixed": 3,
    "pirate": 4,
}

ROLE_MAP = {
    "unknown": 0,
    "ambusher": 1,
    "brawler": 2,
    "juggernaut": 3,
    "missile boat": 4,
    "scout": 5,
    "skirmisher": 6,
    "sniper": 7,
    "striker": 8,
}

# Global data and variables
# All ROI coordinates below are in pixels of the "waveone" layout rendered at 300 DPI (2725x3475 page).
# They are mapped onto each page via the detected sheet bounds, so they work at any DPI and for sheets with different margins.
DEFAULT_DPI = 900
REFERENCE_DPI = 300
# Bounds of the printed sheet (ink only, crop marks excluded) on a waveone page at 300 DPI: left, top, right, bottom.
REFERENCE_CONTENT_BOX = (247, 189, 2473, 3208)
# A row/column counts as sheet content when at least this fraction of it is dark. Crop marks fall below it.
CONTENT_INK_FRACTION = 0.05
# Auto-detection warns when the sheet size is further than this from every known layout.
LAYOUT_MATCH_TOLERANCE = 0.03
json_data_file = Path("/home/chief/StudioProjects/battletech_combat_helper_v2/scripts/battletech_weapons.json")
weapons_database: list[dict[str, object | None]] = []

def normalize_text(text: str) -> str:
    return re.sub(r"[ \t]+", " ", text).strip()


def slugify(value: str) -> str:
    return re.sub(r"[^a-z0-9]+", "_", value.lower()).strip("_")


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
    values = [part.strip() for part in re.split(r"\s{2,}", line.strip()) if part.strip()]
    return values

def match_key(name: object) -> str:
    # OCR drops or adds spaces and punctuation ("ERSmall Laser", "SRM6"), so match on letters and digits only.
    return re.sub(r"[^a-z0-9]", "", str(name).lower())


# Mech techBase enum (1 = Inner Sphere, 2 = Clan) to the weapon database's techBase (0 = Inner Sphere, 1 = Clan).
MECH_TO_WEAPON_TECH_BASE = {1: 0, 2: 1}


def grab_weapon_extended_data(weapon_entry: dict[str, object | None], mech_tech_base: int = 0) -> dict[str, object | None]:
    key = match_key(weapon_entry.get("type", ""))
    matches = [entry for entry in weapons_database if match_key(entry.get("type", "")) == key]
    if not matches:
        return weapon_entry
    # Most weapons exist in both tech bases with different stats, so prefer the mech's own.
    preferred_tech = MECH_TO_WEAPON_TECH_BASE.get(mech_tech_base)
    database_entry = next((entry for entry in matches if entry.get("techBase") == preferred_tech), matches[0])
    # The database values, including the weapon name, win over the OCR text.
    return {**weapon_entry, **{k: v for k, v in database_entry.items() if v is not None}}


def parse_weapon_rows(rows: list[str], lookup_extended: bool = False, mech_tech_base: int = 0) -> list[dict[str, object | None]]:
    if not rows:
        return []

    parsed: list[dict[str, object | None]] = []
    for row in rows:
        item: dict[str, object | None] = {
            "type": "",
            "location": None,
            "quantity": 1,
            "heat": None,
            "heatType": None,
            'damage': None,
            'damageType': None,
            'minRange': None,
            'shortRange': None,
            'mediumRange': None,
            'longRange': None,
            'tons': None,
        }
        # The last two characters in the row form the location tag, e.g., "LA" for left arm, "CT" for center torso.
        if len(row) >= 3:
            item["location"] = row[-2:].strip()
            row = row[:-2].strip()
        tokens = row.split(" ")
        if tokens:
            # If the first token is a number, treat it as the quantity. OCR sometimes adds punctuation, e.g. "1.".
            quantity_match = re.fullmatch(r"(\d+)\W*", tokens[0])
            if quantity_match:
                item["quantity"] = parse_number(quantity_match.group(1), integer=True) or 1
                tokens = tokens[1:]
            item["type"] = " ".join(tokens).strip()
        
        if item["type"]:
            if lookup_extended:
                item = grab_weapon_extended_data(item, mech_tech_base)
            parsed.append(item)
    return parsed

def parse_crit_table(crit_text_sections: dict[str, str]) -> dict[str, object | None]:
    crit_table: dict[str, object | None] = {}
    for section_name, section_text in crit_text_sections.items():
        lines = [normalize_text(line) for line in section_text.splitlines() if normalize_text(line)]
        if not lines:
            continue
        crit_table[section_name] = lines
    return crit_table

def parse_ammo_list(ammo_text: str) -> dict[str, int | None]:
    ammo_list: dict[str, int | None] = {}
    # Entries look like "(LRM 10) 12". OCR sometimes reads the brackets as [ or {,
    # and picks up stray characters after the last count, so match each entry directly.
    for match in re.finditer(r"[(\[{]\s*([^)\]}]+?)\s*[)\]}]\s*(\d[\d,]*)", ammo_text.split("BV")[0]):
        ammo_list[normalize_text(match.group(1))] = parse_number(match.group(2), integer=True)
    return ammo_list

def parse_armor_data(armor_data: dict[str, int], type: str) -> dict[str, int]:
    armor_by_location: dict[str, int] = {}
    for location, value in armor_data.items():
        armor_text = "".join([ele for ele in value if ele.isdigit()])
        armor_value = parse_number(armor_text, integer=True) or 0
        armor_by_location[location.split(type, 1)[1]] = armor_value
    return armor_by_location, sum(armor_by_location.values())

def parse_heat_sink_data(heat_sinks: str) -> Tuple[int, int]:
    if (heat_sinks.find("(") == -1 and heat_sinks.find(")") == -1):
        number_sinks = parse_number(heat_sinks, integer=True) or 0
        return (1, number_sinks)
    else:
        number_sinks_text = "".join([ele for ele in heat_sinks.split("(", 1)[1] if ele.isdigit()])
        number_sinks = parse_number(number_sinks_text, integer=True) or 0
        return (2, number_sinks)

def parse_mech_text(text: dict[str, str]) -> dict[str, object | None]:
    joined_mech_data: dict[str, str] = {}
    weapon_lookup = len(weapons_database) > 0
    for block, content in text.items():
        normalized = re.sub(r"\r\n?", "\n", content)
        lines = [normalize_text(line) for line in normalized.splitlines() if normalize_text(line)]
        joined_mech_data[block] = "\n".join(lines)

    def find(patterns: list[str], default: str = "", block: str = None) -> str:
        for pattern in patterns:
            match = re.search(pattern, joined_mech_data.get(block, ""), re.IGNORECASE)
            if match:
                try:
                    return match.group(1).strip()
                except:
                    pass
        return default

    nameAndModel = find([
        r"Type\s*[:\-]\s*(.+?)(?:\n|$)",
    ], block="base_data")
    name = nameAndModel.rsplit(" ", 1)[0] if " " in nameAndModel else nameAndModel
    model = nameAndModel.rsplit(" ", 1)[1] if " " in nameAndModel else ""
    tonnage_text = find([
        r"(\d+(?:\.\d+)?)\s*tons?",
        r"Tonnage\s*[:\-]\s*(\d+(?:\.\d+)?)",
    ], block="base_data")
    tonnage = parse_number(tonnage_text, integer=False) or 0.0
    tech_base = parse_enum(find([r"Tech\s*Base\s*[:\-]\s*(.+?)(?:\n|$)"], block="base_data"), TECH_BASE_MAP, default=0)

    walk = parse_number(find([r"Walking\s*[:\-]?\s*(\d+)"], block="base_data")) or 0
    run = parse_number(find([r"Running\s*[:\-]?\s*(\d+)"], block="base_data")) or 0
    jump = parse_number(find([r"Jumping\s*[:\-]?\s*(\d+)"], block="base_data")) or 0
    battle_value = parse_number(find([r"Battle\s*Value\s*[:\-]?\s*(?=.)(\d{1,3}(,\d{3})*)?(\.\d+)?\b", r"BV\s*[:\-]?\s*(?=.)(\d{1,3}(,\d{3})*)?(\.\d+)?\b"], block="ammo_and_bv")) or 0
    role = parse_enum(find([r"Role\s*[:\-]\s*(.+?)(?:\n|$)"], block="base_data"), ROLE_MAP, default=0)

    crit_text_sections = dict(filter(lambda item: item[0].startswith("crit_"), joined_mech_data.items()))
    crit_table = parse_crit_table(crit_text_sections)
    engineType = crit_table.get("crit_center_torso", [])[0] if crit_table.get("crit_center_torso") else ""
    ammo = parse_ammo_list(joined_mech_data.get("ammo_and_bv", ""))

    era_text = find([r"Era\s*[:\-]\s*(\d{4})", r"(30\d{2})\b"], block="base_data")
    era = parse_number(era_text) or 0

    # Attempt to parse weapons and equipment tables.
    weapons: list[dict[str, object | None]] = []
    weapons = parse_weapon_rows(rows=joined_mech_data.get("weapons_table", "").splitlines(), lookup_extended=weapon_lookup, mech_tech_base=tech_base)

    armor_by_location: dict[str, int] = {}
    structure_by_location: dict[str, int] = {}
    armor_by_location, armor_total = parse_armor_data(dict(filter(lambda item: item[0].startswith("armor_"), joined_mech_data.items())), "armor_")
    structure_by_location, structure_total = parse_armor_data(dict(filter(lambda item: item[0].startswith("struct_"), joined_mech_data.items())), "struct_")
    heat_sink_type_and_number = parse_heat_sink_data(joined_mech_data.get("heat_sinks", ""))

    mech_id = slugify(f"{name} {model}") if name and model else None
    if not mech_id:
        mech_id = slugify(name or "mech")

    return {
        "id": mech_id,
        "name": name,
        "model": model,
        "techBase": tech_base,
        "tonnage": tonnage,
        "era": era,
        "role": role,
        "engineType": engineType,
        "walk": walk,
        "run": run,
        "jump": jump,
        "armorTotal": armor_total,
        "armorByLocation": armor_by_location,
        "structureTotal": structure_total,
        "structureByLocation": structure_by_location,
        "heatSinkTypeAndNumber": heat_sink_type_and_number,
        "maxHeat": heat_sink_type_and_number[0] * heat_sink_type_and_number[1],
        "weapons": weapons,
        "battleValue": battle_value,
        "critTable": crit_table,
        "ammo": ammo
    }


def ocr_page(image: Image.Image, config: str) -> str:
    return pytesseract.image_to_string(image, lang="eng", config=config)


def convert_pdf_page_to_image(pdf_path: Path, page: int, dpi: int, grayscale: bool) -> Image.Image:
    # Rendering a single page at a time keeps memory use flat. A page at 900 DPI is hundreds of MB.
    return convert_from_path(str(pdf_path), dpi=dpi, first_page=page, last_page=page, grayscale=grayscale)[0]


def write_mechs(output_json: Path, mechs: list[dict[str, object | None]]) -> None:
    output_json.parent.mkdir(parents=True, exist_ok=True)
    with output_json.open("w", encoding="utf-8") as fp:
        json.dump(mechs, fp, indent=2, ensure_ascii=False)


def add_supt_box_to_data_boxes(data_boxes: dict[str, tuple[int, int, int, int]], name: str, supt_box: tuple[int, int]) -> None:
    data_boxes[name] = [supt_box[0], supt_box[1], supt_box[0] + 60, supt_box[1] + 40]

Box = tuple[float, float, float, float]


def find_content_box(image: Image.Image, dpi: int) -> Box | None:
    """Bounds of the printed sheet on the page, in pixels. Margins and corner crop marks are ignored."""
    # Detection doesn't need full resolution, so work on a ~300 DPI copy and scale the result back up.
    reduction = max(1, dpi // REFERENCE_DPI)
    dark = image.convert("L").reduce(reduction).point(lambda value: 255 if value < 128 else 0)
    width, height = dark.size
    column_ink = list(dark.resize((width, 1), Image.BOX).tobytes())
    row_ink = list(dark.resize((1, height), Image.BOX).tobytes())
    threshold = 255 * CONTENT_INK_FRACTION
    columns = [i for i, ink in enumerate(column_ink) if ink >= threshold]
    rows = [i for i, ink in enumerate(row_ink) if ink >= threshold]
    if not columns or not rows:
        return None
    return (columns[0] * reduction, rows[0] * reduction, (columns[-1] + 1) * reduction, (rows[-1] + 1) * reduction)


def stretch_boxes(boxes: dict[str, Box], ref_content_box: Box, content_box: Box) -> dict[str, tuple[int, int, int, int]]:
    """Map boxes from a reference sheet's coordinates onto a page by stretching the reference sheet bounds to the detected ones."""
    ref_left, ref_top, ref_right, ref_bottom = ref_content_box
    left, top, right, bottom = content_box
    scale_x = (right - left) / (ref_right - ref_left)
    scale_y = (bottom - top) / (ref_bottom - ref_top)
    return {
        name: (
            round(left + (x0 - ref_left) * scale_x),
            round(top + (y0 - ref_top) * scale_y),
            round(left + (x1 - ref_left) * scale_x),
            round(top + (y1 - ref_top) * scale_y),
        )
        for name, (x0, y0, x1, y1) in boxes.items()
    }


def map_boxes_to_page(layouts: list[Layout], layout: Layout, content_box: Box | None, dpi: int) -> dict[str, tuple[int, int, int, int]]:
    """The boxes for a page: the first layout's boxes, overridden by any the page's own layout defines."""
    if content_box is None:
        # Nothing detected (blank page?): assume the layout's reference sheet, scaled to the DPI.
        content_box = tuple(value * dpi / REFERENCE_DPI for value in layout.content_box)
    page_boxes = stretch_boxes(layouts[0].boxes, layouts[0].content_box, content_box)
    if layout is not layouts[0]:
        page_boxes.update(stretch_boxes(layout.boxes, layout.content_box, content_box))
    return page_boxes


def save_roi_overlay(image: Image.Image, page_boxes: dict[str, tuple[int, int, int, int]], content_box: Box | None, out_path: Path) -> None:
    # Draw on a reduced copy; a full-size 900 DPI page is huge.
    reduction = max(1, min(image.size) // 1000)
    overlay = image.convert("RGB").reduce(reduction)
    draw = ImageDraw.Draw(overlay)
    if content_box is not None:
        draw.rectangle([value / reduction for value in content_box], outline="blue", width=3)
    for name, box in page_boxes.items():
        draw.rectangle([value / reduction for value in box], outline="red", width=1)
        draw.text((box[0] / reduction + 2, box[1] / reduction + 2), name, fill="red")
    overlay.save(out_path)


def build_waveone_boxes() -> dict[str, Box]:
    # This felt dumb to do overall, but the text in the PDF as a whole is structureed in such a way that
    # you need to be very targeted in how it gets extracted. Otherwise it comes out as a confusing mess.
    data_boxes = {
        "base_data": (260, 555, 1095, 760),
        "weapons_table": (260, 865, 635, 1390),
        "ammo_and_bv": (260, 1410, 1095, 1560),
        "crit_left_arm": (380, 1750, 730, 2200),
        "crit_left_torso": (380, 2320, 730, 2760),
        "crit_left_leg": (380, 2890, 730, 3100),
        "crit_right_side": (1350, 1750, 1700, 2200),
        "crit_right_torso": (1350, 2320, 1700, 2760),
        "crit_right_leg": (1350, 2890, 1700, 3100),
        "crit_head": (865, 1720, 1100, 1950),
        "crit_center_torso": (865, 2000, 1100, 2450),
        "heat_sinks": (2190, 2530, 2340, 2580),
        "mech_image": (1130, 838, 1740, 1640),
    }
    # The armor and structure data was the worst to extract in any sort of larger sub-image,
    # so I just made a bunch of small sub-images for each armor/structure value location.
    # The name for each value wasn't really necessary since I'm explicitly targeting the individual values themselves.
    # This was super tedious but it ended up being the only way to get the data out reliably.
    add_supt_box_to_data_boxes(data_boxes, "armor_left_torso", (1930, 310))
    add_supt_box_to_data_boxes(data_boxes, "armor_right_torso", (2200, 311))
    add_supt_box_to_data_boxes(data_boxes, "armor_left_arm", (1779, 955))
    add_supt_box_to_data_boxes(data_boxes, "armor_right_arm", (2386, 956))
    add_supt_box_to_data_boxes(data_boxes, "armor_left_leg", (1745, 1179))
    add_supt_box_to_data_boxes(data_boxes, "armor_right_leg", (2411, 1179))
    add_supt_box_to_data_boxes(data_boxes, "armor_head", (2112, 256))
    add_supt_box_to_data_boxes(data_boxes, "armor_center_torso", (2079, 965))
    add_supt_box_to_data_boxes(data_boxes, "armor_rear_left_torso", (1789, 1563))
    add_supt_box_to_data_boxes(data_boxes, "armor_rear_right_torso", (2368, 1563))
    add_supt_box_to_data_boxes(data_boxes, "armor_rear_center_torso", (2079, 1209))

    add_supt_box_to_data_boxes(data_boxes, "struct_left_torso", (1881, 1732))
    add_supt_box_to_data_boxes(data_boxes, "struct_right_torso", (2300, 1732))
    add_supt_box_to_data_boxes(data_boxes, "struct_left_arm", (1738, 2052))
    add_supt_box_to_data_boxes(data_boxes, "struct_right_arm", (2317, 2052))
    add_supt_box_to_data_boxes(data_boxes, "struct_left_leg", (1799, 2293))
    add_supt_box_to_data_boxes(data_boxes, "struct_right_leg", (2268, 2294))
    add_supt_box_to_data_boxes(data_boxes, "struct_center_torso", (2028, 2174))
    return data_boxes


# The wave two sheets are a different layout: their sheet is bigger and a few elements sit differently inside it,
# so a stretch of the wave one boxes misses these. Coordinates are pixels of a wave two page at 300 DPI (2550x3300).
# Boxes not listed here fall back to the stretched wave one boxes.
# This was very frustrating. Way more annoyingly complicated than I originally thought it would have been.
def build_wavetwo_boxes() -> dict[str, Box]:
    data_boxes: dict[str, Box] = {
        "base_data": (85, 440, 1000, 655),
        "weapons_table": (90, 746, 490, 1320),
        "ammo_and_bv": (90, 1425, 1000, 1585),
        "crit_left_arm": (212, 1778, 560, 2202),
        "crit_right_side": (1170, 1778, 1520, 2202),
        "crit_left_torso": (212, 2330, 560, 2760),
        "crit_right_torso": (1170, 2330, 1520, 2760),
        "crit_left_leg": (212, 2888, 560, 3100),
        "crit_right_leg": (1170, 2888, 1520, 3100),
        "crit_head": (690, 1730, 880, 1940),
        "crit_center_torso": (690, 2044, 880, 2470),
        "heat_sinks": (2180, 2475, 2335, 2535),
    }
    add_supt_box_to_data_boxes(data_boxes, "armor_left_torso", (1884, 201))
    add_supt_box_to_data_boxes(data_boxes, "armor_right_torso", (2163, 201))
    add_supt_box_to_data_boxes(data_boxes, "armor_left_arm", (1729, 862))
    add_supt_box_to_data_boxes(data_boxes, "armor_right_arm", (2352, 862))
    add_supt_box_to_data_boxes(data_boxes, "armor_left_leg", (1695, 1086))
    add_supt_box_to_data_boxes(data_boxes, "armor_right_leg", (2379, 1086))
    add_supt_box_to_data_boxes(data_boxes, "armor_head", (2069, 143))
    add_supt_box_to_data_boxes(data_boxes, "armor_center_torso", (2038, 871))
    add_supt_box_to_data_boxes(data_boxes, "armor_rear_left_torso", (1740, 1485))
    add_supt_box_to_data_boxes(data_boxes, "armor_rear_right_torso", (2335, 1485))
    add_supt_box_to_data_boxes(data_boxes, "armor_rear_center_torso", (2038, 1121))

    add_supt_box_to_data_boxes(data_boxes, "struct_left_torso", (1853, 1693))
    add_supt_box_to_data_boxes(data_boxes, "struct_right_torso", (2273, 1693))
    add_supt_box_to_data_boxes(data_boxes, "struct_left_arm", (1712, 2014))
    add_supt_box_to_data_boxes(data_boxes, "struct_right_arm", (2294, 2014))
    add_supt_box_to_data_boxes(data_boxes, "struct_left_leg", (1773, 2257))
    add_supt_box_to_data_boxes(data_boxes, "struct_right_leg", (2245, 2257))
    add_supt_box_to_data_boxes(data_boxes, "struct_center_torso", (2005, 2137))
    return data_boxes


@dataclass(frozen=True)
class Layout:
    name: str
    content_box: Box  # Sheet bounds on a page of this layout at 300 DPI, as find_content_box reports them.
    boxes: dict[str, Box]


def build_layouts() -> list[Layout]:
    waveone = Layout("waveone", REFERENCE_CONTENT_BOX, build_waveone_boxes())
    wavetwo = Layout("wavetwo", (71, 75, 2465, 3225), build_wavetwo_boxes())
    return [waveone, wavetwo]


def pick_layout(layouts: list[Layout], content_box: Box | None, dpi: int) -> tuple[Layout, float]:
    """The layout whose sheet size is closest to the detected one, and how far off it is (0.05 = 5%)."""
    if content_box is None:
        return layouts[0], 0.0
    scale = REFERENCE_DPI / dpi
    width = (content_box[2] - content_box[0]) * scale
    height = (content_box[3] - content_box[1]) * scale

    def distance(layout: Layout) -> float:
        ref_width = layout.content_box[2] - layout.content_box[0]
        ref_height = layout.content_box[3] - layout.content_box[1]
        return max(abs(width - ref_width) / ref_width, abs(height - ref_height) / ref_height)

    best = min(layouts, key=distance)
    return best, distance(best)


def main() -> int:
    parser = argparse.ArgumentParser(description="Extract Battletech mech data from a PDF into JSON")
    parser.add_argument("--input_pdf", type=Path, default=Path("/home/chief/Downloads/ForcePackRecordsWaveTwoMechsOnly.pdf"), help="Path to the input Battletech mech PDF")
    parser.add_argument("--output_json", type=Path, default=Path("/home/chief/StudioProjects/battletech_combat_helper_v2/scripts/mechs.json"), help="Path to write the output JSON file")
    parser.add_argument("--dpi", type=int, default=DEFAULT_DPI, help="DPI for PDF-to-image conversion")
    parser.add_argument("--save-images", action="store_true", default=False, help="Save page images for debugging")
    parser.add_argument("--layout", default="auto", help="Sheet layout to use: auto (detect from the sheet size), waveone or wavetwo")
    parser.add_argument("--start-page", type=int, default=1, help="First PDF page to process (1-based)")
    parser.add_argument("--end-page", type=int, default=None, help="Last PDF page to process (default: last page)")
    parser.add_argument("--append", action="store_true", default=True, help="Merge into the existing output JSON instead of overwriting it. Mechs with a matching id are replaced.")
    parser.add_argument("--save-every", type=int, default=10, help="Write the output JSON after this many pages, so a crash doesn't lose everything")
    parser.add_argument("--color", action="store_true", default=False, help="Render pages in color instead of grayscale (grayscale uses less memory)")
    try:
        args = parser.parse_args()
    except SystemExit:
        print(parser.error())
        return 2

    if not args.input_pdf.exists():
        print(f"Error: input PDF does not exist: {args.input_pdf}", file=sys.stderr)
        return 1

    global weapons_database
    try:
        file = open(json_data_file, 'r', encoding='utf-8')
        weapons_database = json.load(file)
        file.close()
        # Weapon tonnage is stored as text in the database; the Dart model expects a number.
        for entry in weapons_database:
            if isinstance(entry.get("tons"), str):
                entry["tons"] = parse_number(entry["tons"], integer=False)
    except OSError:
        print(f"Unable to open file {file}, skipping")

    layouts = build_layouts()
    layouts_by_name = {layout.name: layout for layout in layouts}
    if args.layout != "auto" and args.layout not in layouts_by_name:
        print(f"Error: unknown layout {args.layout!r}, expected auto or one of {', '.join(layouts_by_name)}", file=sys.stderr)
        return 1

    total_pages = int(pdfinfo_from_path(str(args.input_pdf))["Pages"])
    start_page = max(args.start_page, 1)
    end_page = min(args.end_page or total_pages, total_pages)
    if start_page > end_page:
        print(f"Error: page range {start_page}-{end_page} is empty (PDF has {total_pages} pages)", file=sys.stderr)
        return 1

    mechs: list[dict[str, object | None]] = []
    if args.append and args.output_json.exists():
        with args.output_json.open("r", encoding="utf-8") as fp:
            mechs = json.load(fp)
        print(f"Loaded {len(mechs)} existing mechs from {args.output_json}")
    mech_index_by_id = {existing.get("id"): i for i, existing in enumerate(mechs)}

    (args.output_json.parent / "thumbnails").mkdir(parents=True, exist_ok=True)
    pages_since_save = 0

    for index in range(start_page, end_page + 1):
        image = convert_pdf_page_to_image(args.input_pdf, index, args.dpi, grayscale=not args.color)
        if args.save_images:
            out_image = args.output_json.parent / f"page_{index:03d}.png"
            image.save(out_image)
            print(f"Saved page image: {out_image}")

        content_box = find_content_box(image, args.dpi)
        if content_box is None:
            print(f"Warning: no sheet content detected on page {index}, using the reference layout", file=sys.stderr)
        if args.layout == "auto":
            layout, mismatch = pick_layout(layouts, content_box, args.dpi)
            if mismatch > LAYOUT_MATCH_TOLERANCE:
                print(f"Warning: page {index} sheet size is {mismatch:.0%} off the closest layout ({layout.name}); ROIs may be misaligned", file=sys.stderr)
        else:
            layout = layouts_by_name[args.layout]
        print(f"Page {index} layout: {layout.name}")
        page_boxes = map_boxes_to_page(layouts, layout, content_box, args.dpi)
        if args.save_images:
            out_overlay = args.output_json.parent / f"page_{index:03d}_overlay.png"
            save_roi_overlay(image, page_boxes, content_box, out_overlay)
            print(f"Saved ROI overlay: {out_overlay}")

        mech_data: dict[str, str] = {}
        mech_thumbnail: Image.Image = None
        for box_name, box_coords in page_boxes.items():
            cropped_image = image.crop(box_coords)
            if args.save_images:
                out_cropped = args.output_json.parent / f"page_{index:03d}_{box_name}.png"
                cropped_image.save(out_cropped)
                print(f"Saved cropped image: {out_cropped}")
            if box_name.find("armor_") == -1 and box_name.find("struct_") == -1 and box_name != "mech_image":
                mech_data[box_name] = ocr_page(cropped_image, config="--psm 6")
            elif box_name != "mech_image":
                mech_data[box_name] = ocr_page(cropped_image, config="--psm 7")
            else:
                mech_thumbnail = cropped_image

        mech = parse_mech_text(mech_data)
        if mech["id"] in mech_index_by_id:
            mechs[mech_index_by_id[mech["id"]]] = mech
        else:
            mech_index_by_id[mech["id"]] = len(mechs)
            mechs.append(mech)
        if mech_thumbnail:
            thumbnail_save = args.output_json.parent / f"thumbnails/{mech['id'] or f'mech_{index}'}.png"
            mech_thumbnail.save(thumbnail_save)
        print(f"Parsed page {index}/{end_page}: {mech['id'] or 'unknown'}")

        del image, mech_thumbnail
        pages_since_save += 1
        if args.save_every > 0 and pages_since_save >= args.save_every:
            write_mechs(args.output_json, mechs)
            pages_since_save = 0

    write_mechs(args.output_json, mechs)
    print(f"Wrote {len(mechs)} mechs to {args.output_json}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
