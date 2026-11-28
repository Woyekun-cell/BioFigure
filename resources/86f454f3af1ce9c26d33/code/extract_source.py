"""Export the four Fig. 1d/e worksheets without changing cell values or row order."""

import argparse
import csv
import posixpath
from pathlib import Path
from xml.etree import ElementTree as ET
from zipfile import ZipFile


MAIN = "{http://schemas.openxmlformats.org/spreadsheetml/2006/main}"
OFFICE = "{http://schemas.openxmlformats.org/officeDocument/2006/relationships}"
PACKAGE = "{http://schemas.openxmlformats.org/package/2006/relationships}"
SHEETS = {
    "Fig. 1d - Heatmap": ("d-ratios.csv", 253, 7),
    "Fig. 1d - p-values": ("d-pvalues.csv", 5, 3),
    "Fig. 1e - Heatmap": ("e-ratios.csv", 36, 7),
    "Fig. 1e - p-values": ("e-pvalues.csv", 5, 3),
}


def read_workbook(path):
    def read_xml(member):
        return ET.fromstring(book.read(member))

    def member_name(link):
        if link.get("TargetMode") == "External":
            raise ValueError("Expected a worksheet inside the workbook")
        target = link.attrib["Target"]
        return posixpath.normpath(
            target.lstrip("/") if target.startswith("/") else posixpath.join("xl", target)
        )

    def cell_text(cell):
        kind = cell.get("t")
        if kind == "inlineStr":
            return "".join(node.text or "" for node in cell.iter(MAIN + "t"))
        value = cell.findtext(MAIN + "v")
        if kind == "s" and value is not None:
            return shared[int(value)]
        if kind == "e":
            raise ValueError(f"Excel error at {cell.attrib['r']}: {value}")
        return value

    tables = {}
    with ZipFile(path) as book:
        workbook = read_xml("xl/workbook.xml")
        relationships = {
            item.attrib["Id"]: item
            for item in read_xml("xl/_rels/workbook.xml.rels").findall(PACKAGE + "Relationship")
        }
        shared_link = next(
            (r for r in relationships.values() if r.attrib["Type"].endswith("/sharedStrings")),
            None,
        )
        shared = (
            ["".join(node.text or "" for node in si.iter(MAIN + "t"))
             for si in read_xml(member_name(shared_link)).findall(MAIN + "si")]
            if shared_link is not None else []
        )
        sheets = {
            sheet.attrib["name"]: relationships[sheet.attrib[OFFICE + "id"]]
            for sheet in workbook.find(MAIN + "sheets")
        }
        for name, (filename, count, width) in SHEETS.items():
            if name not in sheets:
                raise ValueError(f"Worksheet missing: {name}")
            link = sheets[name]
            if not link.attrib["Type"].endswith("/worksheet"):
                raise ValueError(f"{name}: relationship does not point to a worksheet")
            sheet_data = read_xml(member_name(link)).find(MAIN + "sheetData")
            rows = sheet_data.findall(MAIN + "row")
            if len(rows) != count + 1:
                raise ValueError(f"{name}: expected {count} data rows, found {len(rows) - 1}")
            table = []
            for n, row in enumerate(rows, start=1):
                expected = [chr(65 + column) + str(n) for column in range(width)]
                cells = row.findall(MAIN + "c")
                values = [cell_text(cell) for cell in cells]
                if (row.get("r") != str(n)
                        or [cell.get("r") for cell in cells] != expected
                        or any(value in (None, "") for value in values)):
                    raise ValueError(f"{name}: row {n} missing or misplaced cells")
                table.append(values)
            tables[filename] = table
    return tables


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("workbook", type=Path)
    parser.add_argument("output_dir", type=Path)
    args = parser.parse_args()
    tables = read_workbook(args.workbook)
    args.output_dir.mkdir(parents=True, exist_ok=True)
    for filename, table in tables.items():
        path = args.output_dir / filename
        with path.open("w", encoding="utf-8", newline="") as stream:
            csv.writer(stream, lineterminator="\n").writerows(table)
        print(f"{path}: {len(table) - 1} data rows, {len(table[0])} columns")


if __name__ == "__main__":
    main()
