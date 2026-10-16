<div align="center">

**[中文](README.md) · English**

# BioFigure

**Reference-guided design and quality control for biological figures**

[![BioFigure](https://img.shields.io/badge/BioFigure-3.8.0-28527A)](biofigure/SKILL.md)
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

The gallery selects **77 figures in 14 categories**. Each visual subtype appears once; color-only, dataset-only and historical variants are omitted.

Each figure states whether it uses simulated, public or package-example data. Inclusion does not certify reproduction of original research findings or complete acceptance testing.

| Category | Figures |
|---|---:|
| [Heatmaps](docs/gallery/heatmaps.md) | 6 |
| [Distributions](docs/gallery/distributions.md) | 5 |
| [Correlations and scatter plots](docs/gallery/correlations.md) | 6 |
| [Composition and flows](docs/gallery/composition.md) | 7 |
| [Bars and lollipops](docs/gallery/bars.md) | 6 |
| [Radar plots](docs/gallery/radar.md) | 2 |
| [Differential expression](docs/gallery/differential.md) | 6 |
| [Embeddings and spatial plots](docs/gallery/embeddings.md) | 6 |
| [Clinical plots](docs/gallery/clinical.md) | 7 |
| [Genomes and phylogeny](docs/gallery/genomes.md) | 11 |
| [Networks and maps](docs/gallery/networks.md) | 5 |
| [Time courses and profiles](docs/gallery/profiles.md) | 5 |
| [Set intersections](docs/gallery/intersections.md) | 2 |
| [Mechanisms and panels](docs/gallery/multipanel.md) | 3 |

See the [complete gallery index](docs/GALLERY.md) and [per-figure inventory](docs/gallery/catalog.csv). Composite figures appear in one primary category.

## Methods and quality checks

**Choose packages by task.** Use ggplot2 for general statistics, ComplexHeatmap for annotated matrices, circlize for circular coordinates, ggtree for phylogenies, gggenomes for genomic tracks and synteny, and patchwork or cowplot for panel assembly. Select the package and key functions before coding.

**Check scientific meaning first.** Confirm experimental units, groups, pairing, comparison direction, transformations, and coordinates. Resolve material ambiguities instead of guessing statistical tests or inventing measurements.

**Review the rendered figure.** Check fonts and final dimensions, reserve space for labels and legends, and inspect overlap, clipping, color semantics, and required annotations. Recheck revised outputs; successful execution alone does not establish visual quality.

**Keep work reproducible.** Deliver plotting code, data, and essential environment information. Method records retain package usage, layout decisions, and known problems to support new datasets.

## Installation and use

Place the complete `biofigure` folder in the project's `.agents/skills/` directory or your personal `~/.agents/skills/` directory. Keep scripts, configuration, examples and licenses together. Ordinary original figures do not require the parent repository or the author's private source archive.

```bash
python3 -m pip install -r biofigure/requirements.txt
Rscript biofigure/scripts/install_public_dependencies.R --check
python3 biofigure/scripts/audit_portable_install.py --dry-fresh-install --output work/portable-install-audit.json
```

`--check` is read-only. To install the free R dependencies, explicitly select a separate library. Missing CRAN packages are installed as needed; ComplexHeatmap uses BiocManager, without upgrading existing packages:

```bash
Rscript biofigure/scripts/install_public_dependencies.R --install --library work/R-library
```

The demonstration dependencies are ggplot2, ragg, systemfonts, jsonlite, yaml, digest, ComplexHeatmap, circlize, ape, ggrepel, scales and stringi. External packages retain their licenses; see the [Bioconductor installation instructions](https://www.bioconductor.org/install/). Fonts are not bundled. Current demonstrations require Arial and return `NEEDS_FONT` when it is missing. `--font Helvetica` checks that exact alternative family; changing a figure font still requires updating its specification and reviewing the new output. Execution has been tested on macOS; Linux and Windows runtime, font and device acceptance remain unverified. PDF export additionally requires the free Ghostscript `gs` executable for font embedding. This script never installs system software. On macOS use `brew install ghostscript`, or obtain it from [Ghostscript](https://www.ghostscript.com/releases/gsdnld.html). PNG-only checks use `Rscript biofigure/scripts/install_public_dependencies.R --check --formats png` and do not require Ghostscript.

Run a first-party synthetic example:

```bash
python3 biofigure/scripts/run_public_example.py --case boxplot --output-dir work/boxplot-new
python3 biofigure/scripts/run_public_example.py --case heatmap --output-dir work/heatmap-new --formats png
```

PNG and PDF are the defaults; `--formats png` exports PNG only. Use a new or empty output directory. Set `R_LIBS_USER` to a separately installed R library when needed. Other cases are dense-heatmap, bubble, volcano, synteny and phylogeny. Each keeps its synthetic-data label, inputs, code, statistical or coordinate semantics, and scope boundaries.

For real data, state the research question, experimental unit, groups, comparison direction and pairing, for example:

```text
$biofigure Read expression.csv and metadata.csv and draw a grouped expression heatmap.
Preserve metadata sample order, annotate treatment and time, and review labels and legends.

$biofigure Draw a volcano plot from differential.csv using log2FC and -log10(padj).
The comparison is treatment versus control. Label specified genes; export PNG and PDF.
```

See the [English handbook](docs/HANDBOOK.en.md) for fuller design and export guidance.

## Validation and scope

Version 3.8.0 separates the searchable learning catalog from public executable cases. The 454 learning records retain sources, methods, historical defects and qualification boundaries. Unshipped source material is reported as `source-materials-unavailable`: it is not advertised as executable and does not block an ordinary original figure. Explicit source adoption or reproduction still requires the relevant source image, code, inputs and fresh CP2 binding.

The [public case manifest](biofigure/public-cases.json) lists 13 executable entries: seven entirely first-party synthetic examples, plus two Cannabis cases, Planarian, OHCA, Sankey and OncoPrint. It binds code, input, provenance, licenses and SHA256. OHCA requires a SHA-pinned processed RDS; Cannabis requires pinned BUSCOplot source or a verified source cache. Network and external R dependencies are declared. Complete entrypoints do not certify arbitrary new data, another platform, full original-paper figures, or current visual acceptance.

The two DPM cases remain reference-only, with first-party adapters and the [original paper](https://www.nature.com/articles/s41467-024-49986-4). Their separate GitHub input repository provides no explicit redistribution license. This release removes the derived CSV, PNG and PDF files rather than treating the article's CC-BY license as permission for that repository. Earlier Git history may still contain those files; the [withdrawal manifest](docs/gallery/rights-exclusions-3.8.0.json) records exact paths and hashes.

The portable audit checks the complete distribution, declared runtime materials, hashes, path containment, license declarations, and a Skill-only copy. It does not execute R or award scientific, source-fidelity or visual PASS. Actual figures still require applicable analysis, CP2, single-use authorization, output checks, and final-size PNG/PDF review. The full V2 scientific benchmark remains incomplete; historical PASS does not transfer to new data or environments.

```bash
python3 biofigure/scripts/audit_portable_install.py --distribution-root . --output work/release-audit.json
python3 tools/build_gallery.py --check
```

The Skill supplies methods and checks. It does not change model parameters or guarantee equivalent results across models or reasoning settings.

## Versions and history

- [Releases: download named versions](https://github.com/Woyekun-cell/BioFigure/releases)
- [v3.8.0 portable installation and public cases](https://github.com/Woyekun-cell/BioFigure/tree/v3.8.0)
- [v3.7.1 historical update](https://github.com/Woyekun-cell/BioFigure/tree/v3.7.1) · [Pre-refresh snapshot](https://github.com/Woyekun-cell/BioFigure/tree/snapshot-20261011-pre-gallery-refresh)
- [v3.5.1 release notes](docs/RELEASE-NOTES-3.5.1.md) · [v3.5.0 release notes](docs/RELEASE-NOTES-3.5.0.md)
- [Complete commit history](https://github.com/Woyekun-cell/BioFigure/commits/main/): inspect each change and its contemporary files.

`main` contains current code. Version tags remain attached to their release commits so earlier versions can be downloaded and compared.

## Sources and feedback

See [design sources](docs/DESIGN-SOURCES.md) and [NOTICE](NOTICE.md) for provenance. The gallery contains independently generated figures with per-figure data-origin labels; third-party reference images, webpages, and scraped code are not included.

Use [Discussions](https://github.com/Woyekun-cell/BioFigure/discussions) for figure ideas, references, and design feedback. Report reproducible problems through [Issues](https://github.com/Woyekun-cell/BioFigure/issues/new/choose), including data structure, code, package versions, and output. See the [contribution guide](CONTRIBUTING.md).
