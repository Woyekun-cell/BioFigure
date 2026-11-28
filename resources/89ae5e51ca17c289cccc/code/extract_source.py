"""Export and audit the published Fig. 3c chromosome-contact source worksheet."""

import argparse
import csv
import hashlib
import json
import posixpath
from collections import Counter, defaultdict
from decimal import Decimal
from itertools import combinations_with_replacement, groupby
from pathlib import Path
from statistics import mean
from xml.etree import ElementTree as ET
from zipfile import ZipFile


MAIN = "{http://schemas.openxmlformats.org/spreadsheetml/2006/main}"
OFFICE = "{http://schemas.openxmlformats.org/officeDocument/2006/relationships}"
PACKAGE = "{http://schemas.openxmlformats.org/package/2006/relationships}"
SHEET = "Fig. 3c - inter counts"
HEADER = [
    "cell", "condition", "cell_category", "chromosome1", "chromosome2",
    "chromosome_interaction", "raw_count", "normalized_count", "rank_count",
]
GROUPS = {
    "Control": ("RPE_TP53", 33, "control_mean_rank"),
    "WGD with LCS": ("RPE_WGD", 8, "wgd_with_lcs_mean_rank"),
    "WGD without LCS": ("RPE_WGD", 17, "wgd_without_lcs_mean_rank"),
}
CHROMOSOMES = [f"chr{number}" for number in range(1, 23)] + ["chrX"]
EXPECTED_PAIRS = set(combinations_with_replacement(CHROMOSOMES, 2))
EXPECTED_CLASSES = {"LL": 105, "LS": 120, "SS": 28}


def read_source(workbook_path):
    def linked_xml(relationship):
        if relationship.get("TargetMode") == "External":
            raise ValueError("Expected an internal workbook relationship")
        target = relationship.attrib["Target"]
        member = target.lstrip("/") if target.startswith("/") else posixpath.join("xl", target)
        return ET.fromstring(book.read(posixpath.normpath(member)))

    def cell_text(cell):
        kind = cell.get("t")
        if cell.find(MAIN + "f") is not None or kind == "e":
            raise ValueError(f"Unexpected Excel formula or error in {cell.get('r')}")
        if kind == "inlineStr":
            return "".join(node.text or "" for node in cell.iter(MAIN + "t"))
        value = cell.findtext(MAIN + "v")
        return shared[int(value)] if kind == "s" and value is not None else value

    with ZipFile(workbook_path) as book:
        workbook = ET.fromstring(book.read("xl/workbook.xml"))
        links = ET.fromstring(book.read("xl/_rels/workbook.xml.rels"))
        relationships = {link.attrib["Id"]: link for link in links.findall(PACKAGE + "Relationship")}
        shared = []
        for link in relationships.values():
            if link.attrib["Type"].endswith("/sharedStrings"):
                shared = [
                    "".join(text.text or "" for text in entry.iter(MAIN + "t"))
                    for entry in linked_xml(link).findall(MAIN + "si")
                ]
                break
        sheets = [sheet for sheet in workbook.find(MAIN + "sheets") if sheet.get("name") == SHEET]
        if len(sheets) != 1:
            raise ValueError(f"Expected exactly one worksheet named {SHEET!r}")
        link = relationships[sheets[0].attrib[OFFICE + "id"]]
        if not link.attrib["Type"].endswith("/worksheet"):
            raise ValueError(f"{SHEET}: relationship does not point to a worksheet")
        rows = linked_xml(link).find(MAIN + "sheetData").findall(MAIN + "row")
        expected_count = sum(group[1] for group in GROUPS.values()) * len(EXPECTED_PAIRS)
        if len(rows) != expected_count + 1:
            raise ValueError(f"{SHEET}: expected {expected_count} source rows, found {len(rows) - 1}")

        table = []
        columns = "ABCDEFGHI"
        for number, row in enumerate(rows, start=1):
            cells = row.findall(MAIN + "c")
            addresses = [cell.get("r") for cell in cells]
            allowed = [[f"{column}{number}" for column in columns[:width]] for width in (7, 9)]
            if row.get("r") != str(number) or addresses not in allowed:
                raise ValueError(f"{SHEET}: row {number} has missing or misplaced cells")
            values = [cell_text(cell) for cell in cells]
            if any(value is None or not value.strip() for value in values):
                raise ValueError(f"{SHEET}: row {number} has an unexpected empty stored cell")
            table.append(values + [""] * (len(HEADER) - len(values)))
    if table[0] != HEADER:
        raise ValueError(f"{SHEET}: unexpected source header {table[0]}")
    return table


def audit_source(table):
    cell_groups = {}
    cell_pairs = defaultdict(set)
    cell_ranks = defaultdict(list)
    pair_classes = {}
    group_ranks = defaultdict(lambda: defaultdict(list))
    group_rows = Counter()
    diagonal_rows = Counter()
    for number, row in enumerate(table[1:], start=2):
        cell, condition, group, first, second, pair_class, raw, normalized, rank = row
        pair = (first, second)
        if group not in GROUPS or condition != GROUPS[group][0] or not cell.startswith(f"{condition}_"):
            raise ValueError(f"Row {number}: inconsistent condition or cell category")
        if cell_groups.setdefault(cell, group) != group:
            raise ValueError(f"Row {number}: inconsistent category for {cell}")
        if pair not in EXPECTED_PAIRS or pair in cell_pairs[cell]:
            raise ValueError(f"Row {number}: unexpected or duplicated pair for {cell}")
        cell_pairs[cell].add(pair)
        group_rows[group] += 1
        if pair_class not in EXPECTED_CLASSES or pair_classes.setdefault(pair, pair_class) != pair_class:
            raise ValueError(f"Row {number}: inconsistent chromosome interaction class")
        if not raw.isdecimal():
            raise ValueError(f"Row {number}: raw_count must be a nonnegative integer")
        if first == second:
            if normalized or rank:
                raise ValueError(f"Row {number}: diagonal rows must have blank normalization and rank")
            diagonal_rows[group] += 1
            continue
        if not normalized or not rank:
            raise ValueError(f"Row {number}: off-diagonal rows must have normalization and rank")

        count = Decimal(normalized)
        rank_value = Decimal(rank)
        if not count.is_finite() or count < 0 or not rank_value.is_finite():
            raise ValueError(f"Row {number}: invalid normalized count or rank")
        cell_ranks[cell].append((count, rank_value))
        group_ranks[(*pair, pair_class)][group].append(rank_value)

    cell_counts = Counter(cell_groups.values())
    if cell_counts != Counter({group: expected[1] for group, expected in GROUPS.items()}):
        raise ValueError(f"Unexpected cell counts by group: {cell_counts}")
    for cell, pairs in cell_pairs.items():
        if pairs != EXPECTED_PAIRS:
            raise ValueError(f"{cell}: chromosome-pair coverage differs from the full upper triangle")

    checked_ranks = 0
    tie_blocks = 0
    for cell, ranks in cell_ranks.items():
        start = 1
        for _, tied in groupby(sorted(ranks), key=lambda item: item[0]):
            tie = list(tied)
            tie_blocks += len(tie) > 1
            average_rank = Decimal(2 * start + len(tie) - 1) / 2
            if any(rank != average_rank for _, rank in tie):
                raise ValueError(f"{cell}: source rank_count disagrees with normalized_count order")
            start += len(tie)
        checked_ranks += len(ranks)

    if Counter(key[2] for key in group_ranks) != Counter(EXPECTED_CLASSES):
        raise ValueError("Unexpected interaction-class counts for interchromosomal pairs")
    means = {}
    for pair, values in sorted(group_ranks.items()):
        if {group: len(ranks) for group, ranks in values.items()} != dict(cell_counts):
            raise ValueError(f"{pair}: ranks missing for one or more cells")
        means[pair] = {group: float(mean(values[group])) for group in GROUPS}

    plotted_groups = ("Control", "WGD with LCS")
    highlight = ("chr10", "chrX", "LL")
    rank_limits = (30, 250)
    visible_count = sum(
        all(rank_limits[0] <= values[group] <= rank_limits[1] for group in plotted_groups)
        for values in means.values()
    )
    plot_header = ["chromosome1", "chromosome2", "chromosome_interaction"]
    plot_header += [info[2] for info in GROUPS.values()]
    plot_rows = [plot_header] + [[*pair, *values.values()] for pair, values in means.items()]
    audit = {
        "source_worksheet": SHEET,
        "source_columns": HEADER,
        "source_rows": len(table) - 1,
        "cells": len(cell_groups),
        "chromosomes_per_cell": len(CHROMOSOMES),
        "source_rows_per_cell": len(EXPECTED_PAIRS),
        "groups": {
            group: {
                "condition": GROUPS[group][0],
                "cells": cell_counts[group],
                "rows": group_rows[group],
                "diagonal_rows": diagonal_rows[group],
                "ranked_rows": group_rows[group] - diagonal_rows[group],
            }
            for group in GROUPS
        },
        "blank_normalized_count_rows": sum(diagonal_rows.values()),
        "blank_rank_count_rows": sum(diagonal_rows.values()),
        "blank_raw_count_rows": 0,
        "rank_check": {
            "method": "Ascending average ranks of within-cell normalized_count; exclude blank diagonals.",
            "ranks_checked": checked_ranks,
            "discrepancies": 0,
            "tie_blocks": tie_blocks,
        },
        "aggregation": "Mean supplied rank_count by cell_category and chromosome-pair/class key, then pivot.",
        "author_method": "https://github.com/CSOgroup/WGD/blob/main/src/04_scHiC.py#L310-L327",
        "plotted_groups": {"x": plotted_groups[0], "y": plotted_groups[1]},
        "pairs_by_class": EXPECTED_CLASSES,
        "total_plot_pairs": len(means),
        "author_code_display_limits_both_axes": list(rank_limits),
        "pairs_inside_author_code_limits": visible_count,
        "mean_rank_ranges": {
            group: [min(values[group] for values in means.values()), max(values[group] for values in means.values())]
            for group in GROUPS
        },
        "highlight_chr10_chrX": {
            "chromosome_interaction": highlight[2],
            "mean_ranks": means[highlight],
            "is_top_mean_rank": {
                group: means[highlight][group] == max(values[group] for values in means.values())
                for group in GROUPS
            },
        },
    }
    return plot_rows, audit


def write_csv(path, rows):
    with path.open("w", encoding="utf-8", newline="") as stream:
        csv.writer(stream, lineterminator="\n").writerows(rows)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("workbook", type=Path)
    parser.add_argument("case_dir", type=Path, nargs="?", default=Path(__file__).resolve().parent)
    args = parser.parse_args()
    source_rows = read_source(args.workbook)
    plot_rows, audit = audit_source(source_rows)
    audit["source_workbook_sha256"] = hashlib.sha256(args.workbook.read_bytes()).hexdigest()

    data_dir = args.case_dir / "data"
    evidence_dir = args.case_dir / "evidence"
    data_dir.mkdir(parents=True, exist_ok=True)
    evidence_dir.mkdir(parents=True, exist_ok=True)
    write_csv(data_dir / "fig3c-ranked-contacts.csv", source_rows)
    write_csv(data_dir / "plot-pairs.csv", plot_rows)
    (evidence_dir / "source-data-audit.json").write_text(
        json.dumps(audit, indent=2) + "\n", encoding="utf-8",
    )
    print(f"{SHEET}: {audit['source_rows']} source rows, {audit['total_plot_pairs']} plot pairs")


if __name__ == "__main__":
    main()
