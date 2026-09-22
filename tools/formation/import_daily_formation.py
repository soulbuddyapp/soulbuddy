"""Normalize SoulBuddy's reviewed formation workbook into a versioned catalog."""

from __future__ import annotations

import argparse
import hashlib
import json
import re
from copy import copy
from datetime import date
from pathlib import Path
from typing import Any, Iterable

from openpyxl import load_workbook
from openpyxl.workbook.workbook import Workbook


MAX_RUNTIME_SECONDS = 630
CATALOG_VERSION = 1
YOUTUBE_URL = "https://www.youtube.com/watch?v={youtube_id}"
PROHIBITED_GARDEN_EMPTY = re.compile(r"garden.{0,24}empty", re.IGNORECASE)

# Optional material is attached to the relevant later formation days without
# becoming a required daily-video selection or affecting completion progress.
RESOURCES = [
    {
        "id": "R001",
        "title": "Sexual integrity support",
        "source": "Helpful material",
        "youtubeId": "aFyQT1bwacQ",
        "youtubeUrl": YOUTUBE_URL.format(youtube_id="aFyQT1bwacQ"),
    },
    {
        "id": "R002",
        "title": "Renewal support",
        "source": "Helpful material",
        "youtubeId": "zfQL-WIWKSU",
        "youtubeUrl": YOUTUBE_URL.format(youtube_id="zfQL-WIWKSU"),
    },
]
RESOURCE_IDS_BY_DAY = {
    16: ["R001"],
    18: ["R002"],
}


def _clean_text(value: str) -> str:
    replacements = {
        "\ufffd": "'",
        "’": "'",
        "“": '"',
        "”": '"',
        "The Garden Must Bear Fruit": "A Plentiful Harvest",
        "the garden must bear fruit": "aim for a plentiful harvest",
        "The garden must bear fruit": "Aim for a plentiful harvest",
        "Christianity must become lived transformation; aim for a plentiful harvest.": (
            "Christianity becomes lived transformation through faithful action."
        ),
        "Fruit, not an empty cleared field, is the goal.": "Aim for a plentiful harvest.",
        "A weed-free barren field is still barren.": "Plant something good in the garden each day.",
        "The garden is not merely weed-free; spiritual maturity produces good fruit.": (
            "Spiritual maturity produces good fruit."
        ),
        "A Plentiful Harvest: uproot sin early; fight from Christ's victory; walk with the Spirit; discipline gifts; practice humility; live by mercy/generosity; bear visible fruit.": (
            "A Plentiful Harvest: walk with the Spirit, practise discipline, humility, mercy, generosity, and visible fruit."
        ),
        "User-provided: A Plentiful Harvest": "User-provided spiritual formation source",
        "A Plentiful Harvest.docx": "Spiritual formation source document",
    }
    cleaned = value
    for source, replacement in replacements.items():
        cleaned = cleaned.replace(source, replacement)
    return cleaned


def _write_beatitudes_video(workbook: Workbook) -> None:
    sheet = workbook["VIDEO CATALOG"]
    existing_ids = {sheet.cell(row=row, column=1).value for row in range(2, sheet.max_row + 1)}
    if "V045" not in existing_ids:
        source_row = sheet.max_row
        target_row = source_row + 1
        for column in range(1, sheet.max_column + 1):
            source = sheet.cell(row=source_row, column=column)
            target = sheet.cell(row=target_row, column=column)
            if source.has_style:
                target._style = copy(source._style)
            if source.number_format:
                target.number_format = source.number_format
            if source.alignment:
                target.alignment = copy(source.alignment)

        sheet.append(
            [
                "V045",
                "This Is Who Experiences the Good Life (According to Jesus) • Visual Commentary",
                "BibleProject",
                YOUTUBE_URL.format(youtube_id="W9fR7sHw9Y8"),
                "W9fR7sHw9Y8",
                "10:23",
                623,
                MAX_RUNTIME_SECONDS,
                f'=IF(G{target_row}<=H{target_row},"PASS","FAIL")',
                f'=IF(I{target_row}="PASS","PRODUCTION_READY","REJECT")',
                "Beatitudes",
                "kingdom character; flourishing",
                "self-reliance / status seeking",
                "humility / mercy / kingdom hope",
                "Foundational",
                "Broad Christian",
                YOUTUBE_URL.format(youtube_id="W9fR7sHw9Y8"),
                YOUTUBE_URL.format(youtube_id="W9fR7sHw9Y8"),
                date.today().isoformat(),
                "User-selected Beatitudes visual commentary; verified against the exact YouTube watch page.",
                "P09; P10",
                "REINFORCEMENT",
                "High",
                "Suitable as a virtue-formation alternative.",
            ]
        )

    for row in range(2, sheet.max_row + 1):
        sheet.cell(row=row, column=8).value = MAX_RUNTIME_SECONDS
    sheet.cell(row=1, column=8).value = "Hard cap seconds"
    sheet.cell(row=1, column=9).value = "Within 10:30?"


def _apply_normalization(workbook: Workbook) -> None:
    for sheet in workbook.worksheets:
        for row in sheet.iter_rows():
            for cell in row:
                if isinstance(cell.value, str):
                    cell.value = _clean_text(cell.value)

    _write_beatitudes_video(workbook)

    path = workbook["70-DAY MVP PATH"]
    for row in range(2, path.max_row + 1):
        if path.cell(row=row, column=1).value == 57:
            path.cell(row=row, column=15).value = "V045"

    excluded = workbook["EXCLUDED"]
    for row in range(1, excluded.max_row + 1):
        if "Beatitudes visual commentary" in str(excluded.cell(row=row, column=1).value):
            excluded.cell(row=row, column=1).value = "Earlier Beatitudes visual commentary edition"
            excluded.cell(row=row, column=4).value = "Superseded by the verified selected edition in VIDEO CATALOG."


def normalize_workbook(path: Path) -> None:
    workbook = load_workbook(path)
    _apply_normalization(workbook)
    workbook.save(path)


def _header_map(sheet: Any) -> dict[str, int]:
    return {
        str(cell.value): index
        for index, cell in enumerate(sheet[1])
        if cell.value is not None
    }


def _parse_runtime(value: Any) -> int:
    if isinstance(value, int):
        return value
    if not isinstance(value, str):
        raise ValueError(f"Runtime must be an integer or mm:ss string, got {value!r}.")
    match = re.fullmatch(r"(?P<minutes>\d+):(?P<seconds>[0-5]\d)", value.strip())
    if match is None:
        raise ValueError(f"Runtime must be mm:ss, got {value!r}.")
    return int(match["minutes"]) * 60 + int(match["seconds"])


def _cell(row: tuple[Any, ...], headers: dict[str, int], name: str) -> Any:
    return row[headers[name]]


def _source_sha256(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def build_catalog(workbook_path: Path) -> dict[str, Any]:
    workbook = load_workbook(workbook_path, data_only=False)
    _apply_normalization(workbook)

    video_sheet = workbook["VIDEO CATALOG"]
    video_headers = _header_map(video_sheet)
    videos: list[dict[str, Any]] = []
    for row in video_sheet.iter_rows(min_row=2, values_only=True):
        video_id = _cell(row, video_headers, "Video ID")
        if not video_id:
            continue
        runtime_seconds = _parse_runtime(_cell(row, video_headers, "Runtime (mm:ss)"))
        youtube_id = str(_cell(row, video_headers, "YouTube video ID"))
        videos.append(
            {
                "id": str(video_id),
                "title": str(_cell(row, video_headers, "Title")),
                "channel": str(_cell(row, video_headers, "Channel")),
                "youtubeUrl": YOUTUBE_URL.format(youtube_id=youtube_id),
                "youtubeId": youtube_id,
                "runtimeSeconds": runtime_seconds,
                "status": "PRODUCTION_READY" if runtime_seconds <= MAX_RUNTIME_SECONDS else "REJECT",
                "primaryTopic": str(_cell(row, video_headers, "Primary topic")),
                "secondaryUse": str(_cell(row, video_headers, "Secondary use")),
                "viceTarget": str(_cell(row, video_headers, "Vice / struggle target")),
                "virtueTarget": str(_cell(row, video_headers, "Virtue target")),
                "difficulty": str(_cell(row, video_headers, "Difficulty")),
                "theologicalLens": str(_cell(row, video_headers, "Theological lens")),
                "officialRuntimeSource": str(_cell(row, video_headers, "Official runtime source")),
                "youtubeVerificationSource": str(_cell(row, video_headers, "YouTube verification source")),
                "verifiedOn": str(_cell(row, video_headers, "Verified on")),
                "curationNote": str(_cell(row, video_headers, "Metadata / curation note")),
                "bestPacks": str(_cell(row, video_headers, "Best pack(s)")),
                "formationRole": str(_cell(row, video_headers, "Formation role")),
                "verificationConfidence": str(_cell(row, video_headers, "Verification confidence")),
                "sensitivityNote": str(_cell(row, video_headers, "Sensitivity / lens note")),
            }
        )

    pack_sheet = workbook["PACK MAP"]
    pack_headers = _header_map(pack_sheet)
    packs: list[dict[str, Any]] = []
    for order, row in enumerate(pack_sheet.iter_rows(min_row=2, values_only=True), start=1):
        pack_id = _cell(row, pack_headers, "Pack ID")
        if not pack_id:
            continue
        start_day, end_day = (int(part) for part in str(_cell(row, pack_headers, "Days")).split("-"))
        packs.append(
            {
                "id": str(pack_id),
                "order": order,
                "startDay": start_day,
                "endDay": end_day,
                "title": str(_cell(row, pack_headers, "Pack / track")),
                "primaryStruggle": str(_cell(row, pack_headers, "Primary struggle")),
                "targetFormation": str(_cell(row, pack_headers, "Target virtue / formation")),
                "anchor": str(_cell(row, pack_headers, "Garden anchor")),
                "scripture": str(_cell(row, pack_headers, "Key Scripture")),
                "coverageNote": str(_cell(row, pack_headers, "MVP coverage note")),
            }
        )

    day_sheet = workbook["70-DAY MVP PATH"]
    day_headers = _header_map(day_sheet)
    days: list[dict[str, Any]] = []
    for row in day_sheet.iter_rows(min_row=2, values_only=True):
        day_number = _cell(row, day_headers, "Day")
        if not day_number:
            continue
        video_ids = [
            str(_cell(row, day_headers, "Primary video ID")),
            str(_cell(row, day_headers, "Alt 1 video ID")),
            str(_cell(row, day_headers, "Alt 2 video ID")),
        ]
        days.append(
            {
                "id": f"D{int(day_number):03d}",
                "day": int(day_number),
                "week": int(_cell(row, day_headers, "Week")),
                "packId": str(_cell(row, day_headers, "Pack ID")),
                "focus": str(_cell(row, day_headers, "Daily focus")),
                "objective": str(_cell(row, day_headers, "Objective")),
                "scripture": str(_cell(row, day_headers, "Scripture")),
                "anchor": str(_cell(row, day_headers, "Garden anchor")),
                "presentation": str(_cell(row, day_headers, "Default presentation")),
                "videoIds": video_ids,
                "resourceIds": RESOURCE_IDS_BY_DAY.get(int(day_number), []),
                "alternativeConditions": [
                    str(_cell(row, day_headers, "When to offer Alt 1")),
                    str(_cell(row, day_headers, "When to offer Alt 2")),
                ],
                "coverageStrength": str(_cell(row, day_headers, "Coverage strength")),
                "reflection": str(_cell(row, day_headers, "Post-watch reflection")),
                "action": str(_cell(row, day_headers, "Today's one action")),
                "completionRule": str(_cell(row, day_headers, "Completion rule")),
                "onComplete": str(_cell(row, day_headers, "On complete")),
                "onIncomplete": str(_cell(row, day_headers, "On incomplete")),
            }
        )

    rule_sheet = workbook["RECOMMENDATION RULES"]
    rule_headers = _header_map(rule_sheet)
    rules: list[dict[str, Any]] = []
    for row_index, row in enumerate(rule_sheet.iter_rows(min_row=2, values_only=True), start=1):
        priority = _cell(row, rule_headers, "Rule priority")
        if priority is None:
            continue
        rules.append(
            {
                "id": f"R{row_index:02d}",
                "priority": int(priority),
                "trigger": str(_cell(row, rule_headers, "User state / trigger")),
                "eligibility": str(_cell(row, rule_headers, "Eligibility filter")),
                "presentation": str(_cell(row, rule_headers, "Presentation")),
                "optionLabels": [
                    str(_cell(row, rule_headers, "Option 1")),
                    str(_cell(row, rule_headers, "Option 2")),
                    str(_cell(row, rule_headers, "Option 3")),
                ],
                "progressBehavior": str(_cell(row, rule_headers, "Progress behavior")),
                "note": str(_cell(row, rule_headers, "Reasoning / product note")),
            }
        )

    catalog = {
        "version": CATALOG_VERSION,
        "sourceSha256": _source_sha256(workbook_path),
        "videos": sorted(videos, key=lambda video: video["id"]),
        "resources": RESOURCES,
        "packs": sorted(packs, key=lambda pack: pack["order"]),
        "days": sorted(days, key=lambda day: day["day"]),
        "rules": sorted(rules, key=lambda rule: rule["priority"]),
    }
    validate_catalog(catalog)
    return catalog


def validate_catalog(catalog: dict[str, Any]) -> None:
    if catalog.get("version") != CATALOG_VERSION:
        raise ValueError("Catalog version must be 1.")
    videos = catalog.get("videos", [])
    resources = catalog.get("resources", [])
    packs = catalog.get("packs", [])
    days = catalog.get("days", [])
    rules = catalog.get("rules", [])
    if (len(videos), len(packs), len(days), len(rules)) != (45, 10, 70, 10):
        raise ValueError("Catalog must contain 45 videos, 10 packs, 70 days, and 10 rules.")

    video_ids = {video["id"] for video in videos}
    if len(video_ids) != len(videos):
        raise ValueError("Video IDs must be unique.")
    for video in videos:
        if video["status"] != "PRODUCTION_READY":
            raise ValueError(f"Video {video['id']} is not production-ready.")
        if not 1 <= video["runtimeSeconds"] <= MAX_RUNTIME_SECONDS:
            raise ValueError(f"Video {video['id']} exceeds the runtime limit.")
        if video["youtubeUrl"] != YOUTUBE_URL.format(youtube_id=video["youtubeId"]):
            raise ValueError(f"Video {video['id']} has an invalid YouTube URL.")

    resource_ids = {resource["id"] for resource in resources}
    if len(resource_ids) != len(resources):
        raise ValueError("Resource IDs must be unique.")
    for resource in resources:
        if resource["youtubeUrl"] != YOUTUBE_URL.format(
            youtube_id=resource["youtubeId"]
        ):
            raise ValueError(f"Resource {resource['id']} has an invalid YouTube URL.")

    pack_ids = {pack["id"] for pack in packs}
    if len(pack_ids) != len(packs):
        raise ValueError("Pack IDs must be unique.")
    day_ids = {day["id"] for day in days}
    if len(day_ids) != len(days):
        raise ValueError("Day IDs must be unique.")
    for day in days:
        if day["packId"] not in pack_ids:
            raise ValueError(f"Day {day['id']} references an unknown pack.")
        if len(day["videoIds"]) != 3 or len(set(day["videoIds"])) != 3:
            raise ValueError(f"Day {day['id']} must have three distinct video choices.")
        if any(video_id not in video_ids for video_id in day["videoIds"]):
            raise ValueError(f"Day {day['id']} references an unknown video.")
        if any(resource_id not in resource_ids for resource_id in day["resourceIds"]):
            raise ValueError(f"Day {day['id']} references an unknown resource.")
        if not all(day[field].strip() for field in ("objective", "scripture", "reflection", "action", "completionRule")):
            raise ValueError(f"Day {day['id']} is missing required formation copy.")

    encoded = json.dumps(catalog, ensure_ascii=False)
    if "\ufffd" in encoded:
        raise ValueError("Catalog contains replacement characters.")
    if "must bear fruit" in encoded.casefold() or PROHIBITED_GARDEN_EMPTY.search(encoded):
        raise ValueError("Catalog contains prohibited garden wording.")


def write_outputs(catalog: dict[str, Any], paths: Iterable[Path]) -> None:
    encoded = json.dumps(catalog, ensure_ascii=False, separators=(",", ":"), sort_keys=True) + "\n"
    for path in paths:
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text(encoded, encoding="utf-8", newline="\n")


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("workbook", type=Path)
    parser.add_argument("outputs", nargs="+", type=Path)
    args = parser.parse_args()

    normalize_workbook(args.workbook)
    catalog = build_catalog(args.workbook)
    write_outputs(catalog, args.outputs)
    print(f"Imported {len(catalog['videos'])} videos, {len(catalog['packs'])} packs, and {len(catalog['days'])} days.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
