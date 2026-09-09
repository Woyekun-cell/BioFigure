# BioFigure 3.1 Full Handbook

## 1. Scope

BioFigure is a unified production skill for biological scientific figures. It turns a research question into a scientifically bounded, visually restrained, reproducible, and inspectable figure. It does not replace raw NGS analysis, and “Nature style” never overrides data semantics or journal-specific requirements.

## 2. Entry point and dynamic routing

`biofigure/SKILL.md` is the concise entry point. Every invocation first loads personal style, rendering execution, reference quality, the scientific contract, the visual stance, and checkpoints. `manifest.yaml` then routes along four axes: primary and secondary biological domains, primary and secondary scientific roles, one locked backend, and one delivery target. `scripts/route_figure.py` emits a module list and backend lock; emitting a path is not evidence that its content has been read.

Domains cover transcriptomics/metabolomics/multi-omics, single-cell/spatial, chromatin, genome variation, phylogeny/synteny/gene families, imaging assays, machine learning, mechanisms, and multi-panel figures. Roles cover QC, discovery, comparison, structure, mechanism, validation, prediction, and robustness/model evaluation.

## 3. Scientific contract

`static/core/contract.md` constrains every downstream module. Before rendering, BioFigure records the central claim and its boundary; biological entities and relationships; experimental, statistical, and replicate units; coordinates, units, transformations, filters, missing values, and uncertainty. A non-statistical figure must still state why statistics do not apply. Missing measurements may only be represented by an explicitly labelled schematic or simulation.

Imaging figures retain scale-bar, exposure, sampling, and representative-image boundaries. Machine-learning figures check train/validation/test separation, leakage, calibration, and external validation. Genome figures check assembly versions, coordinate conventions, strand, ID mapping, and homology. Every edge in a mechanism diagram requires an evidence level; association cannot be promoted to a proven mechanism.

## 4. Pattern retrieval and Atlas evidence

`patterns/` currently indexes 19 reusable designs, including volcano, raw-point distributions, square heatmaps, PCA, single-cell dot plots, chromatin signal views, enrichment, multi-omics factors, tree-plus-gene-structure, chromosome density, synteny, and multi-panel evidence chains. A Pattern records applicability, hierarchy, encoding, layout, optional components, risks, and renderer options. It does not contain the measurements of a specific study.

`atlas/` stores evidence for Patterns. The curated top-journal corpus is the primary layer; SciDraw supplies optional design candidates. A webpage image, title, and code link must belong to the same card. Association does not imply scientific or visual approval. Evidence preference is author code or an official vignette, then a paper figure with Source Data, then image-only inspiration. Retrieved, read, executed, visually inspected, and human-approved are separate states.

## 5. Figure Design Spec

`schemas/figure-design-spec.schema.yaml` requires the following before coding: task and message; data and biology contracts; backend and delivery locks; candidate and selected Patterns; reference observations and rejected elements; hierarchy, encoding, annotation, legend, and palette semantics; renderer and physical size; layout slots; resolved font file; allowed text; white background; and inspection plan. An invalid Spec blocks rendering.

## 6. Renderers and components

`renderer-registry.yaml` registers 18 backends. R defaults to ggplot2, ComplexHeatmap for matrices, ggtree for trees, and gggenomes/circlize for genome and synteny layouts. Seurat plus custom ggplot supports R-native single-cell work. Python offers matplotlib, seaborn, Scanpy, pyGenomeTracks, and pyGenomeViz. Specialized tools may create inputs, but they do not bypass final QA.

`components/` defines marks, labels, legends, annotations, statistical layers, and genomic tracks. Components are composable objects rather than complete templates. Data, label, annotation, and legend regions are allocated in millimetres before layers are drawn.

## 7. First-render standard

The default is a real Arial or Helvetica file, a pure white canvas, one standalone figure, and no unrequested title. Readable heatmaps use physically calculated square cells and restrained borders; classification strips are normally no wider than 3 mm. Dot plots use a fine black outline, with area and colour assigned to different variables. Legends stay outside the evidence region. Palettes follow data type, midpoint, category count, colour-vision accessibility, and greyscale separation rather than a fixed house palette.

Comparisons with biological replicates export a statistics table containing analysis scale, omnibus test, prespecified contrasts, multiplicity adjustment, effect sizes, confidence intervals, and exact P/q values. Unknown pairing or repeated-measure structure blocks invented tests. Illustrator is limited to final object-level edits; reproducible colour, position, and spacing changes return to code.

## 8. Inspection, critics, and benchmark

CP0 resolves scientific intent; CP1 fixes the scientific contract; CP2 locks the design; CP3 opens the final PNG and records its hash, size, viewer, and defects; CP4 releases only after critics and QA pass. A later checkpoint cannot pass after an earlier gate fails.

The Scientific Critic covers semantics and statistics; Visual covers hierarchy, density, composition, and whitespace; Publication covers fonts, line weights, clipping, and export; Anti-AI rejects decorative headings, cards, and generic template language. ML, imaging, genome, and mechanism figures add specialist critics. Benchmarking evaluates the skill across tasks with a common rubric; it does not replace artifact inspection. `CODE EXECUTES`, `FIGURE PASSES`, user approval, and journal acceptance are separate claims.

## 9. Directory map

| Path | Responsibility |
|---|---|
| `SKILL.md` / `manifest.yaml` | Entry point and routing |
| `static/core/` | Non-negotiable scientific and visual stance |
| `references/` | Domain, chart, layout, statistics, export, and source rules |
| `patterns/` / `atlas/` | Design grammar and evidence |
| `components/` | Composable visual components |
| `schemas/` | Structured contracts |
| `scripts/` | Routing, retrieval, validation, and R style helpers |
| `critics/` / `checkpoints/` | Rendered-artifact gates |
| `benchmark/` / `test-prompts.json` | Cross-task regression evaluation |
| `examples/gallery/` | Runnable simulated templates |

Back to [README](../README.md) · [中文手册](HANDBOOK.zh-CN.md)

