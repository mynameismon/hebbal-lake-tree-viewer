#!/usr/bin/env python3
"""Check the grouped Hebbal tree-survey CSVs without changing their data."""

from __future__ import annotations

import argparse
import csv
import json
import re
from collections import Counter, defaultdict
from decimal import Decimal, InvalidOperation
from pathlib import Path


REQUIRED_COLUMNS = {
    "source_page",
    "sl_no",
    "tree_no",
    "tree_english_common_name",
    "botanical_name",
    "latitude",
    "longitude",
    "girth_m",
    "approx_height_m",
    "canopy_diameter_m",
    "condition_of_tree",
    "cutting_transplanting",
}
REPORT_COLUMNS = (
    "source",
    "severity",
    "code",
    "group",
    "source_page",
    "row_identifier",
    "field",
    "message",
)
TREE_NUMBER = re.compile(r"^(\d+)([A-Za-z]*)$")
MEASUREMENT_REVIEW_LIMITS = {
    "approx_height_m": Decimal("30"),
    "canopy_diameter_m": Decimal("30"),
}


def read_csv(path: Path) -> list[dict[str, str]]:
    with path.open(newline="", encoding="utf-8-sig") as stream:
        return list(csv.DictReader(stream))


def page_range(value: str) -> set[int]:
    match = re.fullmatch(r"\s*(\d+)(?:\s*[-–]\s*(\d+))?\s*", value)
    if not match:
        raise ValueError(f"Invalid page range: {value!r}")
    start = int(match.group(1))
    end = int(match.group(2) or start)
    if end < start:
        raise ValueError(f"Backwards page range: {value!r}")
    return set(range(start, end + 1))


def check_tables(root: Path) -> tuple[list[dict[str, str]], dict[str, object]]:
    manifest = read_csv(root / "manifest.csv")
    manual = read_csv(root / "review_issues.csv")
    findings: list[dict[str, str]] = []
    group_names = {entry["group"] for entry in manifest}
    assigned_pages: dict[int, str] = {}
    rows_checked = 0
    pages_seen: set[int] = set()

    def add(
        code: str,
        group: str,
        page: int | str = "",
        row: int | str = "",
        field: str = "",
        message: str = "",
        severity: str = "review",
        source: str = "automatic",
    ) -> None:
        findings.append(
            {
                "source": source,
                "severity": severity,
                "code": code,
                "group": str(group),
                "source_page": str(page),
                "row_identifier": str(row),
                "field": field,
                "message": message,
            }
        )

    for entry in manifest:
        group = entry["group"]
        expected_pages = page_range(entry["pdf_pages"])
        for page in expected_pages:
            if page in assigned_pages:
                add("page_assigned_twice", group, page, message=f"Also assigned to {assigned_pages[page]}", severity="error")
            assigned_pages[page] = group

        path = root / group / "table.csv"
        if not path.is_file():
            add("missing_table", group, message="table.csv is missing", severity="error")
            continue
        title_path = root / group / "heading.txt"
        title_lines = title_path.read_text(encoding="utf-8").splitlines() if title_path.is_file() else []
        if not title_lines or title_lines[0] != entry["printed_heading"]:
            add("heading_mismatch", group, field="printed_heading", message="heading.txt differs from manifest.csv", severity="error")

        with path.open(newline="", encoding="utf-8-sig") as stream:
            reader = csv.DictReader(stream)
            header = set(reader.fieldnames or ())
            rows = list(reader)
        for column in sorted(REQUIRED_COLUMNS - header):
            add("missing_column", group, field=column, message=f"Required column {column} is missing", severity="error")
        if not ({"location", "location_ch"} & header):
            add("missing_column", group, field="location", message="No location or location_ch column", severity="error")
        if REQUIRED_COLUMNS - header:
            continue

        rows_checked += len(rows)
        expected_count = int(entry["data_rows"])
        if len(rows) != expected_count:
            add("row_count_mismatch", group, message=f"Manifest says {expected_count} rows; CSV has {len(rows)}", severity="error")

        seen_pages: set[int] = set()
        serials: list[int] = []
        serial_rows: dict[int, tuple[str, str]] = {}
        tree_numbers: dict[str, tuple[str, str]] = {}
        prior_page = 0
        prior_serial = 0
        prior_tree_base: int | None = None
        prior_tree_page = 0

        for index, record in enumerate(rows, start=2):
            if None in record or any(value is None for value in record.values()):
                add("malformed_csv_row", group, row=f"csv_line_{index}",
                    message="Row has more or fewer cells than the CSV header", severity="error")
                continue
            page_text = record["source_page"].strip()
            serial_text = record["sl_no"].strip()
            tree_text = record["tree_no"].strip()
            row_id = serial_text or f"tree_no_{tree_text}" or f"csv_line_{index}"
            try:
                page = int(page_text)
            except ValueError:
                add("invalid_page", group, page_text, row_id, "source_page", "Page must be an integer", "error")
                continue
            seen_pages.add(page)
            pages_seen.add(page)
            if page not in expected_pages:
                add("page_outside_group", group, page, row_id, "source_page", "Page is outside this title's manifest range", "error")
            if page < prior_page:
                add("page_out_of_order", group, page, row_id, "source_page", "Rows go backwards in PDF page order", "review")
            prior_page = page

            previous_tree_base = prior_tree_base
            previous_tree_page = prior_tree_page
            tree_match = TREE_NUMBER.fullmatch(tree_text)
            if not tree_match:
                add("invalid_tree_number", group, page, row_id, "tree_no", f"Unexpected tree number {tree_text!r}", "review")
                tree_base = None
            else:
                tree_base = int(tree_match.group(1))
                if tree_text in tree_numbers:
                    first_page, first_row = tree_numbers[tree_text]
                    add("duplicate_tree_number", group, page, row_id, "tree_no", f"Also appears on page {first_page}, row {first_row}", "review")
                tree_numbers[tree_text] = (page_text, row_id)
                if prior_tree_base is not None and page == prior_tree_page and tree_base < prior_tree_base:
                    add("tree_number_decrease", group, page, row_id, "tree_no", f"Tree number falls from {prior_tree_base} to {tree_base}", "review")
                prior_tree_base = tree_base
                prior_tree_page = page

            if serial_text:
                try:
                    serial = int(serial_text)
                except ValueError:
                    add("invalid_serial", group, page, row_id, "sl_no", "Serial number must be an integer", "review")
                else:
                    serials.append(serial)
                    if serial in serial_rows:
                        first_page, first_tree = serial_rows[serial]
                        add("duplicate_serial", group, page, row_id, "sl_no", f"Serial {serial} also appears on page {first_page}, tree {first_tree}", "review")
                    serial_rows[serial] = (page_text, tree_text)
                    if serial < prior_serial:
                        add("serial_out_of_order", group, page, row_id, "sl_no", f"Serial decreases from {prior_serial} to {serial}", "review")
                    prior_serial = serial
            elif (not tree_match or not tree_match.group(2) or tree_base != previous_tree_base
                  or page != previous_tree_page or index == 2):
                # A blank printed serial is valid only immediately after its base tree.
                add("orphan_continuation", group, page, row_id, "sl_no", "Blank serial is not directly after its base tree", "review")

            for field in ("tree_english_common_name", "botanical_name", "condition_of_tree"):
                if not record[field].strip():
                    add("missing_text", group, page, row_id, field, "Required text is blank", "review")
            location_field = "location_ch" if "location_ch" in header else "location"
            if not record[location_field].strip():
                add("missing_text", group, page, row_id, location_field, "Location is blank", "review")

            condition = record["condition_of_tree"].strip().lower()
            action = record["cutting_transplanting"].strip().upper()
            if condition not in {"healthy", "dead", "up-rooted", "uprooted"}:
                add("unexpected_condition", group, page, row_id, "condition_of_tree", f"Value is {record['condition_of_tree']!r}", "review")
            if action not in {"", "CUTTING", "TRANSPLANTING"}:
                add("unexpected_action", group, page, row_id, "cutting_transplanting", f"Value is {record['cutting_transplanting']!r}", "review")
            if condition == "healthy" and not action:
                add("missing_action", group, page, row_id, "cutting_transplanting", "Healthy tree has no action", "review")
            if condition == "dead" and action:
                add("action_on_dead_tree", group, page, row_id, "cutting_transplanting", f"Dead tree is marked {action}", "review")

            for field in ("latitude", "longitude", "girth_m", "approx_height_m", "canopy_diameter_m"):
                value = record[field].strip()
                if not value:
                    add("missing_value", group, page, row_id, field, "Cell is blank", "review")
                    continue
                try:
                    number = Decimal(value)
                except InvalidOperation:
                    add("invalid_number", group, page, row_id, field, f"Not numeric: {value!r}", "review")
                    continue
                if not number.is_finite():
                    add("invalid_number", group, page, row_id, field, f"Not a finite number: {value!r}", "review")
                    continue
                if field == "latitude" and not (Decimal("12.8") <= number <= Decimal("13.2")):
                    add("coordinate_outlier", group, page, row_id, field, f"Outside broad project bounds: {value}", "review")
                elif field == "longitude" and not (Decimal("77.3") <= number <= Decimal("77.9")):
                    add("coordinate_outlier", group, page, row_id, field, f"Outside broad project bounds: {value}", "review")
                elif field in MEASUREMENT_REVIEW_LIMITS and not (Decimal("0") < number <= MEASUREMENT_REVIEW_LIMITS[field]):
                    add("measurement_outlier", group, page, row_id, field,
                        f"Outside review range (0, {MEASUREMENT_REVIEW_LIMITS[field]}]: {value}", "review")

        for page in sorted(expected_pages - seen_pages):
            add("missing_page", group, page, message="No rows from this PDF page", severity="error")
        printed_total = int(entry["printed_total"])
        for serial in sorted(set(range(1, printed_total + 1)) - set(serials)):
            next_serial = min((number for number in serial_rows if number > serial), default=None)
            previous_serial = max((number for number in serial_rows if number < serial), default=None)
            neighbor = next_serial if next_serial is not None else previous_serial
            page = serial_rows[neighbor][0] if neighbor is not None else ""
            add("missing_serial", group, page, serial, "sl_no", f"Printed total is {printed_total}, but serial {serial} is absent", "review")
        for serial in sorted(set(serials) - set(range(1, printed_total + 1))):
            add("serial_outside_total", group, field="sl_no", row=serial, message=f"Serial is outside 1–{printed_total}", severity="review")

    for page in sorted(set(range(15, 49)) - set(assigned_pages)):
        add("unassigned_pdf_page", "", page, message="PDF data page is not in any heading group", severity="error")

    for note in manual:
        group = note["group"]
        if group not in group_names:
            add("manual_issue_unknown_group", group, note["source_page"], note["row_identifier"], note["field"], "Issue references no manifest group", "error")
        elif note["source_page"].isdigit() and int(note["source_page"]) not in page_range(next(entry["pdf_pages"] for entry in manifest if entry["group"] == group)):
            add("manual_issue_wrong_page", group, note["source_page"], note["row_identifier"], note["field"], "Issue page is outside this heading's PDF pages", "error")
        add("manual_review", group, note["source_page"], note["row_identifier"], note["field"], note["issue"], "review", "manual")

    def finding_order(item: dict[str, str]) -> tuple[object, ...]:
        identifier = item["row_identifier"]
        serial = re.fullmatch(r"\d+", identifier) or re.match(r"SL NO\s+(\d+)", identifier, re.I)
        page = int(item["source_page"]) if item["source_page"].isdigit() else 0
        return (page, item["group"],
                int(serial.group(1) if serial.lastindex else serial.group()) if serial else 10**9,
                identifier, item["source"], item["code"])

    findings.sort(key=finding_order)
    summary: dict[str, object] = {
        "groups": len(manifest),
        "rows": rows_checked,
        "pages": len(pages_seen),
        "manual_notes": len(manual),
        "automatic_findings": sum(item["source"] == "automatic" for item in findings),
        "automatic_errors": sum(item["source"] == "automatic" and item["severity"] == "error" for item in findings),
        "automatic_by_code": dict(Counter(item["code"] for item in findings if item["source"] == "automatic")),
    }
    return findings, summary


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--root", type=Path, default=Path(__file__).resolve().parents[1] / "data" / "by_heading")
    args = parser.parse_args()
    root = args.root.resolve()
    findings, summary = check_tables(root)
    with (root / "check_findings.csv").open("w", newline="", encoding="utf-8") as stream:
        writer = csv.DictWriter(stream, fieldnames=REPORT_COLUMNS)
        writer.writeheader()
        writer.writerows(findings)
    with (root / "check_findings.json").open("w", encoding="utf-8") as stream:
        json.dump({"summary": summary, "findings": findings}, stream, indent=2, ensure_ascii=False)
        stream.write("\n")
    print(f"Checked {summary['groups']} groups, {summary['rows']} rows, {summary['pages']} pages; "
          f"{summary['manual_notes']} manual notes and {summary['automatic_findings']} automatic findings "
          f"({summary['automatic_errors']} errors).")
    print("Automatic findings by code:", summary["automatic_by_code"])


if __name__ == "__main__":
    main()
