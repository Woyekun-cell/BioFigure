<div align="center">

**[中文](README.md) · English**

# 🎨 BioFigure

**Reference-guided design and quality control for biological figures**

[![BioFigure](https://img.shields.io/badge/BioFigure-3.8.0-28527A)](biofigure/SKILL.md)
[![R first](https://img.shields.io/badge/backend-R%20first-4F8F8A)](biofigure/renderer-registry.yaml)
[![Python compatible](https://img.shields.io/badge/Python-compatible-7D719B)](biofigure/renderer-registry.yaml)
[![License: MIT](https://img.shields.io/badge/license-MIT-C97864)](LICENSE)

[Quick start](#quick-start) · [English handbook](docs/HANDBOOK.en.md) · [Design sources](docs/DESIGN-SOURCES.md) · [Gallery](docs/GALLERY.md) · [Releases](https://github.com/Woyekun-cell/BioFigure/releases) · [Community](https://github.com/Woyekun-cell/BioFigure/discussions)

</div>

From choosing a plot to getting the layout right, BioFigure helps you turn biological and multi-omics data into figures you can keep refining. It works as a Skill for coding assistants, bringing plot selection, colors, layout, rendering, and quality checks together while preserving editable R/Python code and plot data. The project is under active development.

**R is the primary plotting route; Python is a fallback.** Use R packages for general statistics, matrices, circular tracks, phylogenies, genomic coordinates, and panel assembly. Choose Python only on explicit user request, to preserve an existing Python-native workflow, or when R has no suitable implementation. Fallback Matplotlib Figures, including Figures obtained from seaborn/Scanpy, can use the official `biofigure/scripts/figure_style.py` entry point to consume single-use authorization and export PNG/PDF/SVG with a render receipt. Both paths share preparation, CP2, and scientific and visual gates. Exported artifacts still require current-file inspection and checkpoint validation. Other Python/CLI exporters do not automatically receive an official receipt.

## Quick start

**Environment already configured:** run a box plot with bundled synthetic data from the repository root. The output retains PNG, PDF, statistics, and execution records. Use a fresh directory whenever inputs change.

```bash
Rscript biofigure/scripts/install_public_dependencies.R --check --profile portable
python3 biofigure/scripts/run_public_example.py boxplot --output-dir work/biofigure-first-boxplot
```

Continue after the dependency check reports `READY`. A successful render reports `RENDERED_PENDING_VISUAL_REVIEW`; open the current PNG/PDF to check fonts, final size, labels, and legends. Runtime depends on the local environment and dependencies. First-time users should follow [Installation and use](#installation-and-use).

Other executable examples are `heatmap`, `dense-heatmap`, `bubble`, `volcano`, `synteny`, and `phylogeny`. For real data, tell the coding assistant the experimental units, groups, comparison direction, and intended output:

```text
$biofigure Read expression.csv and metadata.csv and draw a grouped expression heatmap.
Preserve metadata sample order, annotate treatment and time, and review labels and legends.
```

When the Python fallback is needed, follow the [official authorized-rendering steps](biofigure/references/python-rendering.md). Initial support excludes rectangular heatmaps requiring dedicated cell-geometry audits and MathText/TeX. Install the optional dependencies when needed; R-only work does not require them. Prepare seaborn/Scanpy separately for the task and record actual versions:

```bash
python3 -m pip install -r biofigure/requirements-python.txt
```

## Featured figures

A few examples of the layouts I work on: dense annotations, genomic comparisons and connected statistical views. Follow the case links for the source and rendering workflow.

### Circular heatmap × UpSet

Layered annotations, expression patterns and set intersections, composed as one connected figure.

![Circular heatmap × UpSet](docs/assets/archive-gallery/scidraw-001-065/10_circular_heatmap_upset.png)

[Case](docs/gallery/heatmaps.md#bf-0082) · [Code](biofigure/examples/archive-gallery/scidraw-001-065/scripts/render_cases_10_14.R) · [Reference](https://mp.weixin.qq.com/s/LuFxqYKavB5VvL3K_fDGVA)

### BUSCO-anchored genomic comparison

A redraw from publicly released author-processed data, aligning genomic regions and synthase loci.

![BUSCO-anchored genomic comparison](docs/assets/genomics-gallery-20261011/cannabis-cassette.png)

[Case](docs/gallery/genomes.md#bf-0217) · [Code](biofigure/examples/genomics-gallery-20261011/cannabis-cassette/scripts) · [Source notes](biofigure/examples/genomics-gallery-20261011/cannabis-cassette/provenance.json) · [Reference](https://www.nature.com/articles/s41586-025-09065-0)

### Micro-C contact map and loops

A redraw of the OHCA book example, combining a Micro-C contact matrix with loop annotations.

![Micro-C contact map and loops](docs/assets/genomics-gallery-20261011/ohca-microc.png)

[Case](docs/gallery/genomes.md#bf-0221) · [Code](biofigure/examples/genomics-gallery-20261011/ohca-microc/scripts) · [Source notes](biofigure/examples/genomics-gallery-20261011/ohca-microc/provenance.json) · [Reference](https://js2264.github.io/OHCA/devel/pages/topological-features.html)

### Correlation matrix and Mantel network

Using vegan example data to connect an environmental correlation matrix with a Mantel-test network.

![Correlation matrix and Mantel network](docs/assets/scidraw-gallery-batch2/18_linket_correlation_network.png)

[Case](docs/gallery/networks.md#bf-0055) · [Code](biofigure/examples/scidraw-gallery/scripts/generate_batch20.R) · [Example data](https://github.com/vegandevs/vegan/blob/master/man/varechem.Rd)

[Seven compact examples with inputs and PNG/PDF exports](biofigure/examples/portable)

## Gallery by plot type

The gallery selects **77 figures in 14 categories**. Each visual subtype appears once; color-only, dataset-only and historical variants are omitted.

Explore the visual approach, then follow the code, data and source links to adapt a figure for your own work.

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

Start with your analysis results, choose a figure around the question and data structure, then prepare the relevant packages and plotting parameters.

## Methods and quality checks

**Choose packages by task.** Use ggplot2 for general statistics, ComplexHeatmap for annotated matrices, circlize for circular coordinates, ggtree for phylogenies, gggenomes for genomic tracks and synteny, and patchwork or cowplot for panel assembly. Select the package and key functions before coding.

**Check scientific meaning first.** Confirm experimental units, groups, pairing, comparison direction, transformations, and coordinates. Resolve material ambiguities instead of guessing statistical tests or inventing measurements.

**Review the rendered figure.** Check fonts and final dimensions, reserve space for labels and legends, and inspect overlap, clipping, color semantics, and required annotations. Recheck revised outputs; successful execution alone does not establish visual quality.

**Keep work reproducible.** Deliver plotting code, data, and essential environment information. Method records retain package usage, layout decisions, and known problems to support new datasets.

## Installation and use

Place the complete `biofigure` folder in the project's `.agents/skills/` directory or your personal `~/.agents/skills/` directory. Keep scripts, configuration, examples and licenses together. Ordinary original figures do not require the parent repository or the author's private source archive.

```bash
python3 -m venv .venv
source .venv/bin/activate
python3 -m pip install -r biofigure/requirements.txt
Rscript biofigure/scripts/install_public_dependencies.R --check --profile portable
python3 biofigure/scripts/audit_portable_install.py --dry-fresh-install --output work/portable-install-audit.json
```

`--check` is read-only. To install the free R dependencies, explicitly select a separate library. Missing CRAN packages are installed as needed; ComplexHeatmap uses BiocManager, without upgrading existing packages:

```bash
Rscript biofigure/scripts/install_public_dependencies.R --install --library work/R-library --profile portable
```

<details>
<summary>Dependency versions, fonts and platforms</summary>

This exact-version requirement applies to the `portable` / `all-public` profiles in `install_public_dependencies.R`, rather than every R renderer. Other R tasks still require checks for their selected packages, fonts, and devices.

The default `portable` profile covers the seven new synthetic examples and OncoPrint. Its dependencies are ggplot2, ragg, systemfonts, jsonlite, yaml, digest, ComplexHeatmap, circlize, ape, ggrepel, scales and stringi. R and top-level package versions must match the [version lock](biofigure/static/core/public-runtime-versions.tsv): R 4.6.1 and Bioconductor 3.23. Mismatches return `NEEDS_R_VERSION` or `NEEDS_PACKAGE_VERSIONS`. Explicit installation obtains the selected versions from official CRAN/Bioconductor sources without upgrading unrelated existing packages. External packages retain their licenses; see the [Bioconductor installation instructions](https://www.bioconductor.org/install/). Fonts are not bundled. Current demonstrations require Arial and return `NEEDS_FONT` when it is missing. `--font Helvetica` checks that exact alternative family; changing a figure font still requires updating its specification and reviewing the new output. Execution has been tested on macOS; Linux and Windows runtime, font and device acceptance remain unverified. A fresh Python environment still uses existing R packages and system Arial; this is not a fresh operating-system installation test. PDF export additionally requires free Ghostscript for font embedding; it resolves an explicit `R_GSCMD` path or `gs`, `gswin64c` and `gswin32c`. This script never installs system software. On macOS use `brew install ghostscript`, or obtain it from [Ghostscript](https://www.ghostscript.com/releases/gsdnld.html). PNG-only checks use `Rscript biofigure/scripts/install_public_dependencies.R --check --formats png` and do not require Ghostscript.

</details>

Run a built-in plotting example:

```bash
python3 biofigure/scripts/run_public_example.py boxplot --output-dir work/boxplot-new
python3 biofigure/scripts/run_public_example.py heatmap --output-dir work/heatmap-new --formats png
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

Scientific and visual gates remain required: confirm experimental and statistical units, inspect data, lock the design, and review the actual output. Re-rendered figures require fresh review. Automated checks assess rules, files, and execution evidence; they neither replace inspection nor establish a general aesthetic score.

| Validation scope | Supported conclusion |
|---|---|
| Fixed cases | Applies only to the bound inputs, code, environment, and output; consult each case's status |
| New data | Recheck design, input, statistics, preparation, CP2, authorization, and the current figure; prior PASS does not transfer |
| Other platforms | Different operating systems, R/package versions, fonts, and devices require fresh execution and inspection; see the [platform record](docs/PLATFORM-VALIDATION.md) |
| Full V2 benchmark | Incomplete; method coverage, gallery inclusion, and public packaging tests do not establish full qualification |

## Cases and validation records

<details>
<summary>Public cases, sources, dependencies and validation records</summary>


For all 13 cases, explicitly select `all-public`. It installs the specialist packages and verifies the fixed HiCExperiment/HiContacts source archives by commit and SHA256, then records hashes of the installed package files. A matching package name/version alone is not source-pin evidence.

```bash
Rscript biofigure/scripts/install_public_dependencies.R --install --library work/R-library --profile all-public
Rscript biofigure/scripts/install_public_dependencies.R --check --library work/R-library --profile all-public
```

Use the same library when rendering: in a macOS shell, `export R_LIBS_USER="$PWD/work/R-library"`; in Windows PowerShell, `$env:R_LIBS_USER=(Resolve-Path "work/R-library").Path`. Both systems use the same exact-font PDF/Ghostscript interface, with no Quartz-only public runtime. PDF requires Ghostscript 10; retained cases also need Poppler `pdftoppm` for PDF inspection. On macOS, use `brew install ghostscript poppler`; see the [platform-validation guide](docs/PLATFORM-VALIDATION.md) for Windows tooling. Fonts must already be installed lawfully and are not bundled. Cross-platform acceptance depends on actual CI runs and inspection of the exported figures; setup success alone is not output acceptance.

Version 3.8.0 separates the searchable learning catalog from public executable cases. The 454 learning records retain sources, methods, historical defects and qualification boundaries. Unshipped source material is reported as `source-materials-unavailable`: it is not advertised as executable and does not block an ordinary original figure. Explicit source adoption or reproduction still requires the relevant source image, code, inputs and fresh CP2 binding.

The [public case manifest](biofigure/public-cases.json) lists 13 executable entries: seven entirely first-party synthetic examples, plus two Cannabis cases, Planarian, OHCA, Sankey and OncoPrint. OncoPrint preserves all 144 synthetic samples and 12 genes in three consecutive 48-column native blocks, with measured 2.1×2.1 mm square cells; its current fixed-input macOS execution and exported outputs were reviewed afresh. It binds code, input, provenance, licenses and SHA256. OHCA requires a SHA-pinned processed RDS; Cannabis requires pinned BUSCOplot source or a verified source cache. Network and external R dependencies are declared. Complete entrypoints do not certify arbitrary new data, another platform, full original-paper figures, or current visual acceptance.

The `portable` profile does not install specialist dependencies for retained cases; explicitly select `all-public` for them. The Cannabis cases also need packages including cowplot, magick and svglite; their entrypoints acquire and verify [pinned BUSCOplot source](https://github.com/knausb/BUSCOplot/tree/d4f793988ce89279cf44294ceb8017756e181b0b), or accept a verified source cache. Planarian additionally needs data.table and svglite; Sankey additionally needs ggalluvial, cowplot and svglite. Each case's script or execution configuration is the complete dependency authority. OHCA requires an existing R library containing [pinned HiContacts source](https://github.com/js2264/HiContacts/tree/dfb588e11e0a76e3f68ba0ed2fca7633848c8d0d), [pinned HiCExperiment source](https://github.com/js2264/HiCExperiment/tree/0f56f30b12466fd79f3500ebd0e4d7c8aa64a59a), InteractionSet, GenomeInfoDb, S4Vectors, rhdf5, Rhdf5lib, ggrastr, svglite and common plotting packages. Its [execution configuration](biofigure/examples/genomics-gallery-20261011/ohca-microc/data/metadata/execution-config.json) records package and input locks. [Bioconductor installation guidance](https://www.bioconductor.org/install/) can help prepare dependencies; the public entrypoint does not install them. Current Bioconductor releases are not the pinned commits and are not a compatibility guarantee for this adapter.

The two DPM cases remain reference-only, with first-party adapters and the [original paper](https://www.nature.com/articles/s41467-024-49986-4). Their separate GitHub input repository provides no explicit redistribution license. This release removes the derived CSV, PNG and PDF files rather than treating the article's CC-BY license as permission for that repository. Earlier Git history may still contain those files; the [withdrawal manifest](docs/gallery/rights-exclusions-3.8.0.json) records exact paths and hashes.

The portable audit checks the complete distribution, declared runtime materials, hashes, path containment, license declarations, and a Skill-only copy. It does not execute R or award scientific, source-fidelity or visual PASS. Actual figures still require applicable analysis, CP2, single-use authorization, output checks, and final-size PNG/PDF review. The full V2 scientific benchmark remains incomplete; historical PASS does not transfer to new data or environments.

```bash
python3 biofigure/scripts/audit_portable_install.py --distribution-root . --output work/release-audit.json
python3 tools/build_gallery.py --check
```

The Skill supplies methods and checks. It does not change model parameters or guarantee equivalent results across models or reasoning settings.

</details>

## Versions and history

- [Releases: download named versions](https://github.com/Woyekun-cell/BioFigure/releases)
- [v3.8.0 portable installation and public cases](https://github.com/Woyekun-cell/BioFigure/tree/v3.8.0)
- [v3.7.1 historical update](https://github.com/Woyekun-cell/BioFigure/tree/v3.7.1) · [Pre-refresh snapshot](https://github.com/Woyekun-cell/BioFigure/tree/snapshot-20261011-pre-gallery-refresh)
- [v3.5.1 release notes](docs/RELEASE-NOTES-3.5.1.md) · [v3.5.0 release notes](docs/RELEASE-NOTES-3.5.0.md)
- [Complete commit history](https://github.com/Woyekun-cell/BioFigure/commits/main/): inspect each change and its contemporary files.

`main` contains current code. Version tags remain attached to their release commits so earlier versions can be downloaded and compared.

## Sources and feedback

Find the ideas and methods behind the figures in [design sources](docs/DESIGN-SOURCES.md) and [NOTICE](NOTICE.md). Gallery cases link to code, data and sources—follow the workflow, then adapt it to your own data.

Use [Discussions](https://github.com/Woyekun-cell/BioFigure/discussions) for figure ideas, references, and design feedback. Report reproducible problems through [Issues](https://github.com/Woyekun-cell/BioFigure/issues/new/choose), including data structure, code, package versions, and output. See the [contribution guide](CONTRIBUTING.md).

