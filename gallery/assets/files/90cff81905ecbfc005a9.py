"""Recheck exact author-matrix/ENA lineage matches, without guessing missing IDs."""
import collections
import csv
import gzip
from pathlib import Path

audit = Path(__file__).resolve().parent
batch = audit.parent
with (audit / "ena-run-alias-metadata.tsv").open() as handle:
    records = list(csv.DictReader(handle, delimiter="\t"))
lookup = collections.defaultdict(list)
for record in records:
    lookup[record["run_alias"].removesuffix(".fastq.gz")].append(record)

for sample in ("KPCLOH.Tumor2.DP.SP", "KPCLOH.Pre.Tumor3.SP"):
    source = batch / "genomics/p53-LOH-figures-master/data" / sample
    with gzip.open(source / (sample + ".5k.seg.quantal.primary.txt.gz"), "rt") as handle:
        cells = handle.readline().strip().split("\t")[3:]
    with (audit / (sample + ".ENA.cell-lineage.tsv")).open() as handle:
        saved = list(csv.DictReader(handle, delimiter="\t"))
    expected = {}
    unresolved = []
    for cell in cells:
        matches = lookup[cell]
        if len(matches) != 1:
            unresolved.append(cell)
            continue
        record = matches[0]
        alias = record["sample_alias"]
        lineage = "DP" if ".DP." in alias else "SP" if ".SP." in alias else ""
        expected[cell] = (lineage, record["run_accession"], alias)
    observed = {
        row["cell_id"]: (row["lineage"], row["run_accession"], row["sample_alias"])
        for row in saved
    }
    assert expected == observed
    assert len(observed) == len(saved), "Duplicate saved cell IDs"
    print(sample, "matched", len(observed), "/", len(cells), "unresolved", unresolved)
