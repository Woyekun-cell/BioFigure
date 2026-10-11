<div align="center">

**[中文](README.md) · English**

# BioFigure

**Reference-guided design and quality control for biological figures**

[![BioFigure](https://img.shields.io/badge/BioFigure-3.7.1-28527A)](biofigure/SKILL.md)
[![R first](https://img.shields.io/badge/backend-R%20first-4F8F8A)](biofigure/renderer-registry.yaml)
[![Python compatible](https://img.shields.io/badge/Python-compatible-7D719B)](biofigure/renderer-registry.yaml)
[![License: MIT](https://img.shields.io/badge/license-MIT-C97864)](LICENSE)

[English handbook](docs/HANDBOOK.en.md) · [Design sources](docs/DESIGN-SOURCES.md) · [Gallery](docs/GALLERY.md) · [Releases](https://github.com/Woyekun-cell/BioFigure/releases) · [Community](https://github.com/Woyekun-cell/BioFigure/discussions)

</div>

BioFigure supports figure design across multi-omics and biomedical research, from checking data structures and selecting plot types to writing R/Python code, arranging panels, and reviewing rendered output. It is a Skill for coding assistants that connects research questions to suitable plotting methods while retaining editable code and plot data.

R is the default backend. Dedicated packages handle annotated matrices, circular tracks, phylogenies, genomic coordinates, and panel assembly. Native AnnData and Scanpy workflows can remain in Python. The workflow preserves scientific meaning while giving labels, colors, legends, and panels a clear layout.

## Research areas and plot types

| Research area | Plotting tasks |
|---|---|
| Transcriptomics and proteomics | Expression and differential heatmaps, volcano plots, grouped expression, enrichment, correlation matrices |
| Metabolomics and multi-omics | PCA, abundance distributions, cross-omics associations, annotated heatmaps, networks |
| Single-cell and spatial omics | Embeddings, marker dot plots, cell composition, spatial expression, faceted comparisons |
| Epigenomics and chromatin | ATAC/ChIP profiles, signal heatmaps, regions and genomic tracks |
| Genomics and comparative genomics | Chromosome and interval distributions, synteny, circular links, phylogenies with aligned annotations |
| Microbiology and ecology | Community composition, ordination, phylogenies, abundance and environmental associations |
| Clinical and experimental biology | Survival curves, forest plots, patient swimmers, time courses, group comparisons, model evaluation |
| Integrated figures | Multi-panel figures, imaging plates, evidence annotations |

These are areas covered by the method library and routing rules. Individual tasks depend on available data, dependencies, and method validation status. Existing analysis results can be plotted directly; unavailable upstream analyses are not treated as completed.

## Gallery by plot type

The gallery selects **79 figures in 14 categories** from available outputs. Each visual subtype appears once; color-only, dataset-only, and historical variants are omitted.

Each figure states whether it uses simulated, public, or package-example data. Inclusion does not certify reproduction of original research findings or complete acceptance testing.

| Category | Figures |
|---|---:|
| [Heatmaps and matrix annotations](docs/gallery/heatmaps.md) | 7 |
| [Distributions, box plots, and violins](docs/gallery/distributions.md) | 5 |
| [Correlations, scatter plots, and bubble matrices](docs/gallery/correlations.md) | 6 |
| [Composition, flows, and ternary plots](docs/gallery/composition.md) | 7 |
| [Bars, lollipops, and petal plots](docs/gallery/bars.md) | 6 |
| [Radar plots and multimetric comparisons](docs/gallery/radar.md) | 2 |
| [Differential expression, enrichment, and Manhattan plots](docs/gallery/differential.md) | 6 |
| [Embeddings, single-cell, and spatial plots](docs/gallery/embeddings.md) | 6 |
| [Survival, forest, and patient trajectory plots](docs/gallery/clinical.md) | 7 |
| [Genomes, chromosomes, and phylogenies](docs/gallery/genomes.md) | 11 |
| [Networks and maps](docs/gallery/networks.md) | 6 |
| [Time courses, curves, and signal profiles](docs/gallery/profiles.md) | 5 |
| [Set intersections and UpSet plots](docs/gallery/intersections.md) | 2 |
| [Mechanisms, imaging, and multi-panel figures](docs/gallery/multipanel.md) | 3 |

See the [complete gallery index](docs/GALLERY.md) and [per-figure catalog with file hashes](docs/gallery/catalog.csv). Composite figures are assigned to one primary category, and variants are not repeated.

## Methods and quality checks

**Choose packages by task.** Use ggplot2 for general statistics, ComplexHeatmap for annotated matrices, circlize for circular coordinates, ggtree for phylogenies, gggenomes for genomic tracks and synteny, and patchwork or cowplot for panel assembly. Select the package and key functions before coding.

**Check scientific meaning first.** Confirm experimental units, groups, pairing, comparison direction, transformations, and coordinates. Resolve material ambiguities instead of guessing statistical tests or inventing measurements.

**Review the rendered figure.** Check fonts and final dimensions, reserve space for labels and legends, and inspect overlap, clipping, color semantics, and required annotations. Recheck revised outputs; successful execution alone does not establish visual quality.

**Keep work reproducible.** Deliver plotting code, data, and essential environment information. Method records retain package usage, layout decisions, and known problems to support new datasets.

## Installation and use

Place the complete `biofigure` folder in the project's `.agents/skills/` directory or your personal `~/.agents/skills/` directory. Keep its scripts, configuration, and reference files. Invoke it in a Codex environment that supports Skills; see the [VS Code instructions](biofigure/references/vscode-execution.md) for paths and extension details.

```bash
python3 -m pip install -r biofigure/requirements.txt
```

Install R packages as needed for the selected plot. Provide the data, research question, and intended figure, for example:

```text
$biofigure Read expression.csv and metadata.csv and draw a grouped expression heatmap.
Preserve metadata sample order, annotate treatment and time, and review labels and legends.

$biofigure Draw a volcano plot from differential.csv using log2FC and -log10(padj).
The comparison is treatment versus control. Label specified genes; export PNG and PDF.
```

See the [English handbook](docs/HANDBOOK.en.md) for fuller design and export guidance.

## Validation and scope

Method coverage does not mean every case has passed acceptance testing. Source reproduction, independent transfer, and stress tests are tracked separately; the full V2 benchmark remains incomplete. Automated checks assess rules, files, and execution evidence, while final figures still require visual review. See the [acceptance protocol](biofigure/references/benchmark-protocol.md) and [audit record](docs/release-audit-3.5.1.json).

Version 3.7.1 adds six complex replots using author-processed data and refreshes two simulated examples: a BUSCO-anchored region, cross-genome paths, a dual pathway matrix, an evidence network, a Micro-C contact matrix with loop marks, a haplotype comparison, a Sankey plot, and a multi-event OncoPrint. Code, data, palette, layout, and exported PDFs were reviewed for the current inputs. See the [genomics learning index](biofigure/references/genomics-source-gallery-learning-20261011.md).

Public packages include BioFigure adapters, plotting tables, PDFs, executable configuration, and per-case provenance. The [public replay entries](biofigure/examples/genomics-gallery-20261011/README.md) use new directories and fresh preparation, CP2, and authorization; OHCA separately acquires a SHA-pinned processed RDS. Original author code, reference images, raw R objects, and complete local gate records are not bundled. Current-input acceptance does not certify whole-figure fidelity, transfer to new data, or the full V2 corpus.

Check public file bindings with `python3 tools/audit_public_release.py` and generated gallery documents with `python3 tools/build_gallery.py --check`. The [refresh manifest](docs/gallery/refresh-20261011.json) records SHA256 bindings; packaging checks do not replace scientific reproduction or visual review.

All eight public entries were run in fresh directories with native R, fresh CP2 and single-use authorization, and actual PNG/PDF-preview review at 96 or 120 dpi. Plotting-table hashes and PNG bytes match the sealed current layouts. The [runtime record](docs/gallery/runtime-validation-20261011.json) records environment, file bindings, and scoped results. The 127 selected functional checks and 21 packaging tests passed; the historical full suite remains incomplete without its unbundled source and evidence corpus.

The Skill does not change model weights or guarantee identical results across models and reasoning settings. It supplies explicit methods, constraints, and checks for the workflow.

## Versions and history

- [Releases: download named versions](https://github.com/Woyekun-cell/BioFigure/releases)
- [v3.7.1 current update](https://github.com/Woyekun-cell/BioFigure/tree/v3.7.1) · [Pre-refresh snapshot](https://github.com/Woyekun-cell/BioFigure/tree/snapshot-20261011-pre-gallery-refresh)
- [v3.5.1 release notes](docs/RELEASE-NOTES-3.5.1.md) · [v3.5.0 release notes](docs/RELEASE-NOTES-3.5.0.md)
- [Complete commit history](https://github.com/Woyekun-cell/BioFigure/commits/main/): inspect each change and its contemporary files.

`main` contains current code. Version tags remain attached to their release commits so earlier versions can be downloaded and compared.

## Sources and feedback

See [design sources](docs/DESIGN-SOURCES.md) and [NOTICE](NOTICE.md) for provenance. The gallery contains independently generated figures with per-figure data-origin labels; third-party reference images, webpages, and scraped code are not included.

Use [Discussions](https://github.com/Woyekun-cell/BioFigure/discussions) for figure ideas, references, and design feedback. Report reproducible problems through [Issues](https://github.com/Woyekun-cell/BioFigure/issues/new/choose), including data structure, code, package versions, and output. See the [contribution guide](CONTRIBUTING.md).
