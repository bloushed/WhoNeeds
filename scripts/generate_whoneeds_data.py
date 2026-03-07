#!/usr/bin/env python3
"""Generate WhoNeeds_Data.lua from live Murlok PvE guide pages.

This script discovers specs from murlok.io class pages, fetches a PvE guide
page for each spec, extracts secondary stat priorities and top gear item IDs,
then rewrites WhoNeeds_Data/WhoNeeds_Data.lua.
"""

from __future__ import annotations

import argparse
import datetime as dt
import html
import pathlib
import re
import sys
import urllib.request
from dataclasses import dataclass
from typing import Dict, List, Sequence, Tuple


ROOT = pathlib.Path(__file__).resolve().parents[1]
DEFAULT_OUTPUT = ROOT / "WhoNeeds_Data" / "WhoNeeds_Data.lua"
MURLOK_BASE_URL = "https://murlok.io"
USER_AGENT = "WhoNeedsDataGenerator/0.1 (+https://murlok.io)"


SPEC_IDS_BY_ROUTE: Dict[Tuple[str, str], int] = {
    ("death-knight", "blood"): 250,
    ("death-knight", "frost"): 251,
    ("death-knight", "unholy"): 252,
    ("demon-hunter", "havoc"): 577,
    ("demon-hunter", "vengeance"): 581,
    ("demon-hunter", "devourer"): 1480,
    ("druid", "balance"): 102,
    ("druid", "feral"): 103,
    ("druid", "guardian"): 104,
    ("druid", "restoration"): 105,
    ("evoker", "devastation"): 1467,
    ("evoker", "preservation"): 1468,
    ("evoker", "augmentation"): 1473,
    ("hunter", "beast-mastery"): 253,
    ("hunter", "marksmanship"): 254,
    ("hunter", "survival"): 255,
    ("mage", "arcane"): 62,
    ("mage", "fire"): 63,
    ("mage", "frost"): 64,
    ("monk", "brewmaster"): 268,
    ("monk", "mistweaver"): 270,
    ("monk", "windwalker"): 269,
    ("paladin", "holy"): 65,
    ("paladin", "protection"): 66,
    ("paladin", "retribution"): 70,
    ("priest", "discipline"): 256,
    ("priest", "holy"): 257,
    ("priest", "shadow"): 258,
    ("rogue", "assassination"): 259,
    ("rogue", "outlaw"): 260,
    ("rogue", "subtlety"): 261,
    ("shaman", "elemental"): 262,
    ("shaman", "enhancement"): 263,
    ("shaman", "restoration"): 264,
    ("warlock", "affliction"): 265,
    ("warlock", "demonology"): 266,
    ("warlock", "destruction"): 267,
    ("warrior", "arms"): 71,
    ("warrior", "fury"): 72,
    ("warrior", "protection"): 73,
}

CLASS_ORDER = [
    "death-knight",
    "demon-hunter",
    "druid",
    "evoker",
    "hunter",
    "mage",
    "monk",
    "paladin",
    "priest",
    "rogue",
    "shaman",
    "warlock",
    "warrior",
]

STAT_TOKEN_BY_NAME = {
    "critical strike": "CRIT",
    "haste": "HASTE",
    "mastery": "MASTERY",
    "versatility": "VERS",
}


@dataclass
class SpecData:
    spec_id: int
    class_slug: str
    spec_slug: str
    season: str
    weights: Dict[str, float]
    bis_item_ids: List[int]


def slug_to_label(slug: str) -> str:
    return " ".join(part.capitalize() for part in slug.split("-"))


def fetch_text(url: str, timeout: int) -> str:
    request = urllib.request.Request(url, headers={"User-Agent": USER_AGENT})
    with urllib.request.urlopen(request, timeout=timeout) as response:
        return response.read().decode("utf-8")


def discover_specs(timeout: int) -> List[Tuple[str, str]]:
    routes: List[Tuple[str, str]] = []
    seen = set()

    for class_slug in CLASS_ORDER:
        class_url = f"{MURLOK_BASE_URL}/{class_slug}"
        html_text = fetch_text(class_url, timeout)
        pattern = re.compile(rf'href="/{re.escape(class_slug)}/([^"/?#]+)/3v3"')

        for match in pattern.finditer(html_text):
            route = (class_slug, match.group(1))
            if route in seen:
                continue
            seen.add(route)
            routes.append(route)

    return routes


def extract_section(page: str, section_id: str) -> str:
    match = re.search(
        rf'<section\b[^>]*\bid="{re.escape(section_id)}"[^>]*>(.*?)</section>',
        page,
        re.S,
    )
    if not match:
        raise ValueError(f"Could not find section '{section_id}'")
    return match.group(1)


def extract_season(page: str) -> str:
    title_match = re.search(r"<title>.*?Guide - (.*?)</title>", page, re.S)
    if title_match:
        return html.unescape(title_match.group(1)).strip()
    return "Unknown Season"


def extract_stat_weights(section: str) -> Dict[str, float]:
    stats: Dict[str, int] = {}

    for name, value in re.findall(
        r"<li class=\"guide-stats-chart-item[^\"]*\">\s*"
        r"<span>[^<]*?([A-Za-z ]+)</span>\s*"
        r"<span class=\"h3\">\+?(\d+)</span>",
        section,
        re.S,
    ):
        normalized_name = name.strip().lower()
        token = STAT_TOKEN_BY_NAME.get(normalized_name)
        if token:
            stats[token] = int(value)

    if len(stats) < 2:
        priority_names = [
            item.strip().lower()
            for item in re.findall(r"<li class=\"h3 [^\"]+\">([^<]+)</li>", section)
        ]
        fallback_values = [100, 92, 84, 76]
        for index, name in enumerate(priority_names[:4]):
            token = STAT_TOKEN_BY_NAME.get(name)
            if token and token not in stats:
                stats[token] = fallback_values[index]

    if not stats:
        raise ValueError("No secondary stats found in stat-priority section")

    maximum = max(stats.values())
    return {
        token: round(value / maximum, 4)
        for token, value in sorted(stats.items())
    }


def extract_bis_items(section: str, max_items_per_slot: int) -> List[int]:
    item_ids: List[int] = []
    seen = set()

    slot_pattern = re.compile(r"<h3>([^<]+)</h3>\s*<ol[^>]*>(.*?)</ol>", re.S)
    item_pattern = re.compile(r"wowhead\.com/item=(\d+)")

    for _, slot_block in slot_pattern.findall(section):
        slot_ids = []
        slot_seen = set()
        for item_id_str in item_pattern.findall(slot_block):
            item_id = int(item_id_str)
            if item_id in slot_seen:
                continue
            slot_seen.add(item_id)
            slot_ids.append(item_id)
            if len(slot_ids) >= max_items_per_slot:
                break

        for item_id in slot_ids:
            if item_id in seen:
                continue
            seen.add(item_id)
            item_ids.append(item_id)

    if not item_ids:
        raise ValueError("No BiS gear item IDs found in gear section")

    return item_ids


def fetch_spec_data(
    class_slug: str,
    spec_slug: str,
    content_mode: str,
    timeout: int,
    max_items_per_slot: int,
) -> SpecData:
    spec_id = SPEC_IDS_BY_ROUTE.get((class_slug, spec_slug))
    if spec_id is None:
        raise KeyError(f"Missing SpecializationID mapping for {class_slug}/{spec_slug}")

    spec_url = f"{MURLOK_BASE_URL}/{class_slug}/{spec_slug}/{content_mode}"
    page = fetch_text(spec_url, timeout)

    stat_section = extract_section(page, "stat-priority")
    gear_section = extract_section(page, "gear")
    season = extract_season(page)

    return SpecData(
        spec_id=spec_id,
        class_slug=class_slug,
        spec_slug=spec_slug,
        season=season,
        weights=extract_stat_weights(stat_section),
        bis_item_ids=extract_bis_items(gear_section, max_items_per_slot),
    )


def lua_quote(value: str) -> str:
    return '"' + value.replace("\\", "\\\\").replace('"', '\\"') + '"'


def render_lua(
    content_mode: str,
    season: str,
    generated_at: str,
    specs: Sequence[SpecData],
) -> str:
    lines: List[str] = []
    lines.append("_G.WhoNeedsExternalData = {")
    lines.append(f"    version = {lua_quote(generated_at)},")
    lines.append('    source = "murlok.io live scrape",')
    lines.append(f"    updatedAt = {lua_quote(generated_at)},")
    lines.append(f"    contentType = {lua_quote(content_mode)},")
    lines.append(f"    season = {lua_quote(season)},")
    lines.append("    specWeights = {")

    for spec in specs:
        lines.append(
            f"        [{spec.spec_id}] = {{ -- {spec.class_slug}/{spec.spec_slug}"
        )
        for token, value in sorted(spec.weights.items()):
            lines.append(f"            {token} = {value:.4f},")
        lines.append("        },")

    lines.append("    },")
    lines.append("    bis = {")

    for spec in specs:
        lines.append(
            f"        [{spec.spec_id}] = {{ -- {spec.class_slug}/{spec.spec_slug}"
        )
        for item_id in spec.bis_item_ids:
            lines.append(f"            [{item_id}] = true,")
        lines.append("        },")

    lines.append("    },")
    lines.append("    specRoutes = {")

    for spec in specs:
        route = f"{spec.class_slug}/{spec.spec_slug}"
        label = f"{slug_to_label(spec.spec_slug)} {slug_to_label(spec.class_slug)}"
        lines.append(
            f"        [{spec.spec_id}] = {{ route = {lua_quote(route)}, label = {lua_quote(label)} }},"
        )

    lines.append("    },")
    lines.append("}")
    lines.append("")
    return "\n".join(lines)


def parse_args(argv: Sequence[str]) -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="Generate WhoNeeds_Data.lua from live murlok.io PvE pages."
    )
    parser.add_argument(
        "--content",
        default="m+",
        choices=["m+", "raid"],
        help="PvE content mode to scrape from murlok.io.",
    )
    parser.add_argument(
        "--output",
        type=pathlib.Path,
        default=DEFAULT_OUTPUT,
        help="Output Lua file path.",
    )
    parser.add_argument(
        "--timeout",
        type=int,
        default=20,
        help="HTTP timeout in seconds per request.",
    )
    parser.add_argument(
        "--max-items-per-slot",
        type=int,
        default=3,
        help="Number of top listed items to keep per gear slot.",
    )
    parser.add_argument(
        "--spec",
        action="append",
        default=[],
        metavar="CLASS/SPEC",
        help="Optional route filter, e.g. paladin/protection. Can be repeated.",
    )
    parser.add_argument(
        "--stdout",
        action="store_true",
        help="Print the generated Lua instead of writing the output file.",
    )
    return parser.parse_args(argv)


def main(argv: Sequence[str]) -> int:
    args = parse_args(argv)

    print("Discovering specs from murlok.io...", file=sys.stderr)
    routes = discover_specs(args.timeout)

    if args.spec:
        requested = {tuple(item.split("/", 1)) for item in args.spec}
        routes = [route for route in routes if route in requested]

    if not routes:
        raise SystemExit("No specs discovered for the selected filters.")

    specs: List[SpecData] = []
    seasons = set()

    for class_slug, spec_slug in routes:
        route = f"{class_slug}/{spec_slug}"
        print(f"Fetching {route} ({args.content})...", file=sys.stderr)
        try:
            spec = fetch_spec_data(
                class_slug=class_slug,
                spec_slug=spec_slug,
                content_mode=args.content,
                timeout=args.timeout,
                max_items_per_slot=args.max_items_per_slot,
            )
        except Exception as exc:
            print(f"Skipping {route}: {exc}", file=sys.stderr)
            continue

        specs.append(spec)
        seasons.add(spec.season)

    if not specs:
        raise SystemExit("No spec data could be generated.")

    specs.sort(key=lambda item: item.spec_id)
    generated_at = dt.datetime.now(dt.UTC).replace(microsecond=0).isoformat()
    season = sorted(seasons)[0] if len(seasons) == 1 else " / ".join(sorted(seasons))
    lua_text = render_lua(
        content_mode=args.content,
        season=season,
        generated_at=generated_at,
        specs=specs,
    )

    if args.stdout:
        print(lua_text)
        return 0

    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text(lua_text, encoding="utf-8", newline="\n")
    print(
        f"Wrote {len(specs)} specs to {args.output} for {args.content} ({season}).",
        file=sys.stderr,
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main(sys.argv[1:]))
