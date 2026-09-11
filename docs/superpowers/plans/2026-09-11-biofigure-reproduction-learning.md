# BioFigure 顶刊复现语料学习 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 将Project_005精选案例转成可检索派生知识并验证自然语言独立生成R图。

**Architecture:** 构建器只读源图和代码，输出无整段源码的案例卡；检索器将其作为设计证据；门禁要求新脚本和实际渲染凭证。

**Tech Stack:** Python 3、R/ggplot2、YAML/JSON、unittest、Pillow。

**Spec:** `docs/superpowers/specs/2026-09-11-biofigure-reproduction-learning-design.md`

## Global Constraints

不复制整图或整段原代码；不执行采集代码；保留来源和SHA-256；图内声称不作科学事实；最终代码必须从自然语言需求独立生成。

---

### Task 1: 派生案例库

**Files:** Create `scripts/build_reproduction_atlas.py`, `tests/test_reproduction_atlas.py`, `atlas/reproduction-derived-corpus.json`.

- [ ] 先写失败测试：必须有图型、优点、图层、配色、包、哈希，且无原代码。
- [ ] 实现OCR文本、代码token、颜色与布局的保守抽取。
- [ ] 构建79期语料并校验源哈希。

### Task 2: 检索与门禁

**Files:** Create `scripts/retrieve_reproduction.py`, `references/reproduction-learning.md`; modify `SKILL.md`, `manifest.yaml`, `scripts/validate_checkpoints.py`.

- [ ] 先写检索3–5案例、检索凭证、禁止源码依赖的失败测试。
- [ ] 实现任务/图型/数据结构/包加权检索。
- [ ] 将检索凭证与新脚本哈希加入CP校验。

### Task 3: 自然生成回归评测

**Files:** Create `benchmark/reproduction/*.yaml`, `scripts/run_reproduction_benchmark.py`; modify `benchmark/rubric.yaml`.

- [ ] 用6类自然语言任务建立无源码测试集。
- [ ] 从空白R脚本绘图，固定seed，输出PNG/PDF。
- [ ] 实际查看渲染图，跑完整测试、Critic和Skill校验；失败不发布。
