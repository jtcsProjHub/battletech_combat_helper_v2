# Runs the clean-up steps over the mech JSON repeatedly until a pass changes nothing, because each step can enable
# the next one (fixing a variant lets the MUL data match, which gives a valid tonnage, which lets walk/run be inferred).
# Steps: json_cleanup.py (stray characters, weapon and ammo names), mul_lookup.py merge (tonnage, BV, intro year, role),
# check_mech_data.py (weapon database fill, walk/run inference, and the report of what still needs a manual fix).
# Usage: python refresh_mech_data.py [path/to/mechs.json] [--max-passes 5]

import argparse
import hashlib
import subprocess
import sys
from pathlib import Path

SCRIPTS = Path(__file__).parent
BASE_DATA = SCRIPTS.parent / "assets" / "base_data"


def run(script: str, *args: str) -> str:
    """Runs a sibling script and returns its output; the scripts report problems in their output and exit codes
    (check_mech_data exits 1 when anything is flagged), so a non-zero exit is not an error here."""
    result = subprocess.run([sys.executable, str(SCRIPTS / script), *args], capture_output=True, text=True)
    if result.returncode not in (0, 1) or "Traceback" in result.stderr:
        sys.exit(f"{script} failed:\n{result.stderr}")
    return result.stdout


def last_line(output: str) -> str:
    return next((line for line in reversed(output.splitlines()) if line.strip()), "")


def review_lines(report: str) -> list[str]:
    """Picks the values the checker filled in or inferred ('(review)') out of a report, with their mech."""
    found, mech = [], ""
    for line in report.splitlines():
        if line and not line.startswith(" "):
            mech = line
        elif "(review)" in line:
            found.append(f"{mech}\n{line}")
    return found


def digest(path: Path) -> str:
    return hashlib.sha1(path.read_bytes()).hexdigest()


def main() -> int:
    parser = argparse.ArgumentParser(description="Re-run the mech data clean-up steps until nothing changes")
    parser.add_argument("mechs_json", type=Path, nargs="?", default=BASE_DATA / "mechs_clean.json")
    parser.add_argument("--max-passes", type=int, default=5)
    args = parser.parse_args()
    path = str(args.mechs_json)
    use_mul = (BASE_DATA / "mul_cache.json").exists()
    if not use_mul:
        print("mul_cache.json not found; skipping the MUL step (see mul_lookup.py parse)\n")

    report = ""
    filled: list[str] = []
    for number in range(1, args.max_passes + 1):
        before = digest(args.mechs_json)
        print(f"pass {number}")
        print("  cleanup:", last_line(run("json_cleanup.py", path)))
        if use_mul:
            mul_output = run("mul_lookup.py", "merge", path, "--write")
            print("  mul:    ", next((line for line in mul_output.splitlines() if "mechs changed" in line), last_line(mul_output)))
        report = run("check_mech_data.py", path)
        filled += review_lines(report)
        print("  check:  ", last_line(report))
        if digest(args.mechs_json) == before:
            print(f"\nNo changes in pass {number}; the data is stable.\n")
            break
    else:
        print(f"\nStill changing after {args.max_passes} passes; run again or check for a step that undoes another.\n")

    if filled:
        # A filled value is only reported by the pass that fills it, so collect them here to review.
        print(f"{len(filled)} values were inferred during this run; check them:\n")
        print("\n".join(filled) + "\n")
    print(report)
    return 0


if __name__ == "__main__":
    sys.exit(main())
