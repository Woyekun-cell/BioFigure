"""Resolve task references without confusing the project with the Skill install.

Task document references use their owning document or an explicitly supplied
project root. Skill-owned index/material paths continue to use the Skill root.
"""
from __future__ import annotations

from pathlib import Path


def _path(value: str | Path | None, label: str) -> Path:
    if not isinstance(value, (str, Path)) or not str(value).strip():
        raise ValueError(f'{label} must be a non-empty path')
    return Path(value).expanduser()


def resolve_reference_path(value: str | Path | None, *, document_path: Path | None = None,
                           project_root: Path | None = None) -> Path:
    """Resolve a task file against explicit context, never an unrelated cwd.

    With both contexts, one existing target wins; distinct existing targets are
    rejected as ambiguous. A missing target retains the first contextual path
    so the caller can report its normal missing-file error. Cwd is used only by
    legacy callers that provide neither document nor project context.
    """
    path = _path(value, 'reference path')
    if path.is_absolute():
        return path.resolve()
    bases = []
    if document_path is not None:
        bases.append(_path(document_path, 'document path').resolve().parent)
    if project_root is not None:
        bases.append(_path(project_root, 'project root').resolve())
    if not bases:
        bases.append(Path.cwd())
    candidates = list(dict.fromkeys((base / path).resolve() for base in bases))
    existing = [candidate for candidate in candidates if candidate.is_file()]
    if len(existing) > 1:
        raise ValueError('reference path is ambiguous between document and project root: '
                         + ', '.join(str(candidate) for candidate in existing))
    return existing[0] if existing else candidates[0]


def resolve_project_root(value: str | Path | None, *, document_path: Path | None = None) -> Path:
    """Validate a declared project directory, relative to the lock that owns it."""
    root = _path(value, 'project root')
    if not root.is_absolute():
        base = (_path(document_path, 'document path').resolve().parent
                if document_path is not None else Path.cwd())
        root = base / root
    root = root.resolve()
    if not root.is_dir():
        raise ValueError(f'project root must be an existing directory: {root}')
    return root
