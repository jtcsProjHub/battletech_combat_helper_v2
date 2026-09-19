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
import json
import re
import sys
from pathlib import Path
from PIL import Image

try:
    from pdf2image import convert_from_path
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
    from PIL import Image
except ImportError as exc:
    raise SystemExit(
        "Missing Python dependency pillow. Install it with: pip install pillow"
    ) from exc

TECH_BASE_MAP = {
    "inner sphere": 0,
    "clan": 1,
    "mixed": 2,
    "pirate": 3,
    "unknown": 4,
}

MOVEMENT_TYPE_MAP = {
    "biped": 0,
    "quad": 1,
    "tracked": 2,
    "wheeled": 3,
    "hover": 4,
    "vtol": 5,
}

factor = 3 # Scale factor for coordinates based on PDF DPI (default 300 DPI)

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


def parse_weapon_rows(rows: list[str]) -> list[dict[str, object | None]]:
    if not rows:
        return []

    headers = ["quantity", "type", "location"]
    parsed: list[dict[str, object | None]] = []
    for row in rows:
        item: dict[str, object | None] = {
            "type": "",
            "location": None,
            "quantity": 1,
        }
        # The last two characters in the row form the location tag, e.g., "LA" for left arm, "CT" for center torso.
        if len(row) >= 3:
            item["location"] = row[-2:].strip()
            row = row[:-2].strip()
        tokens = row.split(" ")
        if tokens:
            # If the first token is a number, treat it as the quantity.
            if tokens[0].isdigit():
                item["quantity"] = parse_number(tokens[0], integer=True) or 1
                tokens = tokens[1:]
            item["type"] = " ".join(tokens).strip()
        
        if item["type"]:
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
    lines = ammo_text.split("BV:")[0].split(",")
    for line in lines:
        normalize_text(line)
        ammo_type = line[line.find("(")+1:line.find(")")]
        quantity = parse_number(normalize_text(line.split(")")[1]), integer=True)
        ammo_list[ammo_type] = quantity
    return ammo_list

def parse_armor_data(armor_data: dict[str, int], type: str) -> dict[str, int]:
    armor_by_location: dict[str, int] = {}
    for location, value in armor_data.items():
        armor_text = "".join([ele for ele in value if ele.isdigit()])
        armor_value = parse_number(armor_text, integer=True) or 0
        armor_by_location[location.split(type, 1)[1]] = armor_value
    return armor_by_location, sum(armor_by_location.values())

def parse_mech_text(text: dict[str, str]) -> dict[str, object | None]:
    joined_mech_data: dict[str, str] = {}
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

    name = find([
        r"Variant\s*[:\-]\s*(.+?)(?:\n|$)",
        r"Type\s*[:\-]\s*(.+?)(?:\n|$)",
    ], block="base_data")
    manufacturer = find([
        r"Manufacturer\s*[:\-]\s*(.+?)(?:\n|$)",
    ], block="base_data")
    tonnage_text = find([
        r"(\d+(?:\.\d+)?)\s*tons?",
        r"Tonnage\s*[:\-]\s*(\d+(?:\.\d+)?)",
    ], block="base_data")
    tonnage = parse_number(tonnage_text, integer=False) or 0.0
    tech_base = parse_enum(find([r"Tech\s*Base\s*[:\-]\s*([^\s]+)"], block="base_data"), TECH_BASE_MAP, default=4)

    walk = parse_number(find([r"Walking\s*[:\-]?\s*(\d+)"], block="base_data")) or 0
    run = parse_number(find([r"Running\s*[:\-]?\s*(\d+)"], block="base_data")) or 0
    jump = parse_number(find([r"Jumping\s*[:\-]?\s*(\d+)"], block="base_data")) or 0
    battle_value = parse_number(find([r"Battle\s*Value\s*[:\-]?\s*(?=.)(\d{1,3}(,\d{3})*)?(\.\d+)?\b", r"BV\s*[:\-]?\s*(?=.)(\d{1,3}(,\d{3})*)?(\.\d+)?\b"], block="ammo_and_bv")) or 0

    crit_text_sections = dict(filter(lambda item: item[0].startswith("crit_"), joined_mech_data.items()))
    crit_table = parse_crit_table(crit_text_sections)
    ammo = parse_ammo_list(joined_mech_data.get("ammo_and_bv", ""))

    era_text = find([r"Era\s*[:\-]\s*(\d{4})", r"(30\d{2})\b"], block="base_data")
    era = parse_number(era_text) or 0
    movement_type = parse_enum(find([r"Movement\s*Type\s*[:\-]\s*(.+?)\n"], block="base_data"), MOVEMENT_TYPE_MAP, default=0)

    # Attempt to parse weapons and equipment tables.
    weapons: list[dict[str, object | None]] = []
    weapons = parse_weapon_rows(rows = joined_mech_data.get("weapons_table", "").splitlines())

    armor_by_location: dict[str, int] = {}
    structure_by_location: dict[str, int] = {}
    armor_by_location, armor_total = parse_armor_data(dict(filter(lambda item: item[0].startswith("armor_"), joined_mech_data.items())), "armor_")
    structure_by_location, structure_total = parse_armor_data(dict(filter(lambda item: item[0].startswith("struct_"), joined_mech_data.items())), "struct_")

    mech_id = slugify(f"{name}")
    if not mech_id:
        mech_id = slugify(name or "mech")

    return {
        "id": mech_id,
        "name": name,
        "manufacturer": manufacturer,
        "techBase": tech_base,
        "tonnage": tonnage,
        "era": era,
        "movementType": movement_type,
        "walk": walk,
        "run": run,
        "jump": jump,
        "armorTotal": armor_total,
        "armorByLocation": armor_by_location,
        "structureTotal": structure_total,
        "structureByLocation": structure_by_location,
        "weapons": weapons,
        "battleValue": battle_value,
        "critTable": crit_table,
        "ammo": ammo
    }


def ocr_page(image: Image.Image, config: str) -> str:
    return pytesseract.image_to_string(image, lang="eng", config=config)


def convert_pdf_to_images(pdf_path: Path, dpi: int = 300) -> list[Image.Image]:
    return convert_from_path(str(pdf_path), dpi=dpi)


def add_supt_box_to_data_boxes(data_boxes: dict[str, tuple[int, int, int, int]], name: str, supt_box: tuple[int, int]) -> None:
    data_boxes[name] = [supt_box[0], supt_box[1], supt_box[0] + factor * 60, supt_box[1] + factor * 40]

def main() -> int:
    # This felt dumb to do overall, but the text in the PDF as a whole is structureed in such a way that
    # you need to be very targeted in how it gets extracted. Otherwise it comes out as a confusing mess.
    data_boxes = {
        "base_data": (factor * 260, factor * 555, factor * 1095, factor * 760),
        "weapons_table": (factor * 260, factor * 865, factor * 635, factor * 1390),
        "ammo_and_bv": (factor * 260, factor * 1410, factor * 1095, factor * 1560),
        "crit_left_arm": (factor * 380, factor * 1750, factor * 730, factor * 2200),
        "crit_left_torso": (factor * 380, factor * 2320, factor * 730, factor * 2760),
        "crit_left_leg": (factor * 380, factor * 2890, factor * 730, factor * 3100),
        "crit_right_side": (factor * 1350, factor * 1750, factor * 1700, factor * 2200),
        "crit_right_torso": (factor * 1350, factor * 2320, factor * 1700, factor * 2760),
        "crit_right_leg": (factor * 1350, factor * 2890, factor * 1700, factor * 3100),
        "crit_head": (factor * 865, factor * 1720, factor * 1100, factor * 1950),
        "crit_center_torso": (factor * 865, factor * 2000, factor * 1100, factor * 2450),
    }
    # The armor and structure data was the worst to extract in any sort of larger sub-image,
    # so I just made a bunch of small sub-images for each armor/structure value location.
    # The name for each value wasn't really necessary since I'm explicitly targeting the individual values themselves.
    # This was super tedious but it ended up being the only way to get the data out reliably.
    add_supt_box_to_data_boxes(data_boxes, "armor_left_torso", (factor * 1930, factor * 310))
    add_supt_box_to_data_boxes(data_boxes, "armor_right_torso", (factor * 2200, factor * 311))
    add_supt_box_to_data_boxes(data_boxes, "armor_left_arm", (factor * 1779, factor * 955))
    add_supt_box_to_data_boxes(data_boxes, "armor_right_arm", (factor * 2386, factor * 956))
    add_supt_box_to_data_boxes(data_boxes, "armor_left_leg", (factor * 1745, factor * 1179))
    add_supt_box_to_data_boxes(data_boxes, "armor_right_leg", (factor * 2411, factor * 1179))
    add_supt_box_to_data_boxes(data_boxes, "armor_head", (factor * 2112, factor * 256))
    add_supt_box_to_data_boxes(data_boxes, "armor_center_torso", (factor * 2079, factor * 965))
    add_supt_box_to_data_boxes(data_boxes, "armor_rear_left_torso", (factor * 1789, factor * 1563))
    add_supt_box_to_data_boxes(data_boxes, "armor_rear_right_torso", (factor * 2368, factor * 1563))
    add_supt_box_to_data_boxes(data_boxes, "armor_rear_center_torso", (factor * 2079, factor * 1209))

    add_supt_box_to_data_boxes(data_boxes, "struct_left_torso", (factor * 1881, factor * 1732))
    add_supt_box_to_data_boxes(data_boxes, "struct_right_torso", (factor * 2300, factor * 1732))
    add_supt_box_to_data_boxes(data_boxes, "struct_left_arm", (factor * 1738, factor * 2052))
    add_supt_box_to_data_boxes(data_boxes, "struct_right_arm", (factor * 2317, factor * 2052))
    add_supt_box_to_data_boxes(data_boxes, "struct_left_leg", (factor * 1799, factor * 2293))
    add_supt_box_to_data_boxes(data_boxes, "struct_right_leg", (factor * 2268, factor * 2294))
    add_supt_box_to_data_boxes(data_boxes, "struct_center_torso", (factor * 2028, factor * 2174))

    parser = argparse.ArgumentParser(description="Extract Battletech mech data from a PDF into JSON")
    parser.add_argument("--input_pdf", type=Path, default=Path("/home/chief/StudioProjects/battletech_combat_helper_v2/scripts/test.pdf"), help="Path to the input Battletech mech PDF")
    parser.add_argument("--output_json", type=Path, default=Path("/home/chief/StudioProjects/battletech_combat_helper_v2/scripts/mechs.json"), help="Path to write the output JSON file")
    parser.add_argument("--dpi", type=int, default=factor * 300, help="DPI for PDF-to-image conversion")
    parser.add_argument("--save-images", action="store_true", default=False, help="Save page images for debugging")
    try:
        args = parser.parse_args()
    except SystemExit:
        print(parser.error())
        return 2

    if not args.input_pdf.exists():
        print(f"Error: input PDF does not exist: {args.input_pdf}", file=sys.stderr)
        return 1

    pages = convert_pdf_to_images(args.input_pdf, dpi=args.dpi)
    mechs: list[dict[str, object | None]] = []

    for index, image in enumerate(pages, start=1):
        if args.save_images:
            out_image = args.output_json.parent / f"page_{index:03d}.png"
            image.save(out_image)
            print(f"Saved page image: {out_image}")

        mech_data: dict[str, str] = {}
        for box_name, box_coords in data_boxes.items():
            cropped_image = image.crop(box_coords)
            if args.save_images:
                out_cropped = args.output_json.parent / f"page_{index:03d}_{box_name}.png"
                cropped_image.save(out_cropped)
                print(f"Saved cropped image: {out_cropped}")
            if box_name.find("armor_") == -1 and box_name.find("struct_") == -1:
                mech_data[box_name] = ocr_page(cropped_image, config="--psm 6")
            else:
                mech_data[box_name] = ocr_page(cropped_image, config="--psm 7")

        mech = parse_mech_text(mech_data)
        mechs.append(mech)
        print(f"Parsed page {index}: {mech['id'] or 'unknown'}")

    args.output_json.parent.mkdir(parents=True, exist_ok=True)
    with args.output_json.open("w", encoding="utf-8") as fp:
        json.dump(mechs, fp, indent=2, ensure_ascii=False)

    print(f"Wrote {len(mechs)} mechs to {args.output_json}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
