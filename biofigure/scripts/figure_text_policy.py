#!/usr/bin/env python3
"""Reject explicit production notes and methods footers in figure text.

This is a narrow phrase check, not a classifier of scientific meaning.  Normal
labels, statistical annotations, original identifiers and AI research metrics
remain valid. Container checks reject captions independently of their wording;
actual figure inspection must still catch arbitrary or split footer prose.
Approval of a text allowlist is not an exemption.
"""
from __future__ import annotations

import re
import unicodedata


TEXT_POLICY_ID = "scientific-content-only-v1"
FOOTER_POLICY_ID = "no-canvas-footer-v1"


# Keep these explicit phrase rules aligned with bf_forbidden_figure_text in
# figure_style.R.  Do not reduce them to broad word bans (AI, only, simulated).
FORBIDDEN_RULES = (
    ("sample_design_footer", r"\bn\s*=\s*\d+\b[^;\n]{0,60}\bper\s+(?:group|condition|treatment)\b"),
    ("sample_time_footer", r"\bn\s*=\s*\d+\b\s*[;,].*\b(?:day|time|infection|treatment|replicates?)\b"),
    ("note_or_footer_prefix", r"^\s*(?:notes?|footnotes?|caption|footer|备注|注释说明|图注|脚注)\s*[:：]"),
    ("ai_commentary", r"\b(?:ai|chatgpt|codex)\s+(?:notes?|remarks?|insights?|comments?)\b"),
    ("generated_by_ai", r"\b(?:generated|created|rendered|prepared)\s+by\s+(?:chatgpt|openai|codex|(?:an?\s+)?(?:ai|artificial\s+intelligence))\b"),
    ("generated_figure", r"\b(?:generated\s+(?:figure|plot|chart)|(?:ai|chatgpt|codex)\s*[-–—]?\s*generated\s+(?:figure|plot|chart))\b"),
    ("checkpoint_status", r"\bcp[0-4]\s*[_:=–—-]?\s*(?:pass|fail|blocked|pending|not[_\s-]+verified)\b"),
    ("unverified_status", r"\bnot[_\s-]+verified\b"),
    ("illustration_disclaimer", r"\b(?:for\s+(?:illustration|demonstration)\s+only|descriptive\s+only)\b"),
    ("ai_commentary_zh", r"(?:AI|ChatGPT|Codex|人工智能)\s*(?:的\s*)?(?:备注|注释|点评|说明|提示|评语|见解)"),
    ("generated_figure_zh", r"(?:自动|AI|人工智能)\s*生成(?:的)?\s*(?:科研)?\s*(?:图表|图形|绘图|图(?!像))"),
    ("illustration_disclaimer_zh", r"(?:仅|只)\s*(?:作|做|供|用于|用作)\s*(?:演示|示意|说明)"),
    ("unverified_pairing_zh", r"配对\s*(?:尚)?未(?:核(?:验|实)?|验证|确认)"),
    ("unverified_conclusion_zh", r"(?:科研|研究|生物学)?结论\s*未验证"),
)
_COMPILED_RULES = tuple((rule_id, re.compile(pattern, re.IGNORECASE))
                        for rule_id, pattern in FORBIDDEN_RULES)
_FILTER_CRITERION = re.compile(r"\b(?:FDR|padj|VIP|(?:log2)?FC|fold[ -]?change)\s*(?:<=|>=|<|>|=|≤|≥)", re.IGNORECASE)


def normalize_figure_text(text: str) -> str:
    """Normalize typography/spacing without turning identifiers into phrases."""
    without_zero_width = text.translate(dict.fromkeys(map(ord, "\u200b\u200c\u200d\ufeff")))
    return " ".join(unicodedata.normalize("NFKC", without_zero_width).split())


def forbidden_figure_text_reason(text: str) -> str | None:
    """Return the first matching prohibited phrase class, or None."""
    if not isinstance(text, str):
        return None
    normalized = normalize_figure_text(text)
    if len(_FILTER_CRITERION.findall(normalized)) >= 2:
        return "filtering_criteria_footer"
    for rule_id, pattern in _COMPILED_RULES:
        if pattern.search(normalized):
            return rule_id
    return None


def validate_footer_contract(contract: dict) -> list[str]:
    """Canvas captions/footers are forbidden independently of heading approval."""
    if not isinstance(contract, dict):
        return []  # Shape/type validation belongs to the enclosing schema.
    errors = []
    if contract.get("footer_policy", "outside-only") != "outside-only":
        errors.append("text_contract.footer_policy must be outside-only; canvas caption/footer forbidden")
    for key in ("allow_caption", "allow_footer", "allow_footnotes"):
        if key in contract and contract[key] is not False:
            errors.append(f"text_contract.{key} cannot authorize canvas caption/footer")
    for key in ("caption", "footer", "footnote", "caption_text", "footer_text", "footnote_text"):
        if contract.get(key) not in (None, "", False, []):
            errors.append(f"text_contract.{key} belongs outside the figure; canvas caption/footer forbidden")
    return errors


def validate_figure_text(labels: list[str], field: str = "text_contract.allowed_text") -> list[str]:
    """Check only text intended for the figure, never provenance sidecars."""
    errors = []
    for index, label in enumerate(labels):
        reason = forbidden_figure_text_reason(label)
        if reason:
            errors.append(f"{field}[{index}] contains prohibited production/audit/disclaimer text "
                          f"({reason}): {label!r}; keep it outside the figure")
    return errors
