#!/usr/bin/env python3
"""Read-only validation for SHIK Platform Markdown documentation."""

from __future__ import annotations

import re
import sys
from collections import defaultdict
from pathlib import Path
from urllib.parse import unquote

ROOT = Path(__file__).resolve().parents[1]
GLOSSARY = ROOT / "docs/01-business/TERMINOLOGY_GLOSSARY.md"
DOCUMENT_REGISTRY = (
    ROOT
    / "docs/27-enterprise-architecture-governance/2707-document-registry.md"
)
ID_RE = re.compile(r"^Document ID:\s*([A-Z][A-Z0-9]*-\d+)\s*$", re.MULTILINE)
NAME_RE = re.compile(r"^Document Name:\s*(.+?)\s*$", re.MULTILINE)
RELATED_HEADING_RE = re.compile(r"^#{1,6}\s+Related Documents\s*$", re.IGNORECASE)
RELATED_ID_RE = re.compile(r"\b[A-Z][A-Z0-9]*-\d+\b")
LINK_RE = re.compile(r"!?(?:\[[^\]]*\])\(([^)]+)\)")
REGISTRY_ROW_RE = re.compile(
    r"^\|\s*([A-Z][A-Z0-9]*-\d+)\s*"
    r"\|\s*([^|]+?)\s*"
    r"\|\s*([^|]+?)\s*"
    r"\|\s*([^|]+?)\s*"
    r"\|\s*([^|]+?)\s*"
    r"\|\s*([^|]+?)\s*"
    r"\|\s*`([^`]+)`\s*\|\s*$",
    re.MULTILINE,
)

FORBIDDEN_TERMS = {
    "Communication Center": re.compile(r"\bCommunication Center\b", re.IGNORECASE),
    "Event Driven": re.compile(r"\bEvent Driven\b", re.IGNORECASE),
    "API First": re.compile(r"\bAPI First\b", re.IGNORECASE),
    "Contract First": re.compile(r"\bContract First\b", re.IGNORECASE),
    "AI First": re.compile(r"\bAI First\b", re.IGNORECASE),
    "Cloud Native": re.compile(r"\bCloud Native\b", re.IGNORECASE),
    "Multi Tenant": re.compile(r"\bMulti Tenant\b", re.IGNORECASE),
    "Real Time": re.compile(r"\bReal Time\b", re.IGNORECASE),
    "S3 Compatible": re.compile(r"\bS3 Compatible\b", re.IGNORECASE),
}

CANONICAL_NAMES = {
    "ARC-501": "SYSTEM OVERVIEW",
    "PB-401": "PLATFORM OVERVIEW",
    "GOV-2703": "ARCHITECTURE DECISION RECORDS (ADR) GOVERNANCE",
    "GOV-2707": "DOCUMENT REGISTRY",
}


def related_sections(text: str) -> list[str]:
    lines = text.splitlines()
    sections: list[str] = []
    for index, line in enumerate(lines):
        if not RELATED_HEADING_RE.match(line.strip()):
            continue
        body: list[str] = []
        for candidate in lines[index + 1 :]:
            stripped = candidate.strip()
            if stripped.startswith("#") or stripped == "END OF DOCUMENT":
                break
            body.append(candidate)
        sections.append("\n".join(body))
    return sections


def local_link_target(source: Path, raw_target: str) -> Path | None:
    target = raw_target.strip().strip("<>")
    if not target or target.startswith(("#", "http://", "https://", "mailto:")):
        return None
    target = target.split("#", 1)[0].split("?", 1)[0].strip()
    if not target:
        return None
    return (source.parent / unquote(target)).resolve()


def front_matter_value(text: str, field: str) -> str:
    pattern = re.compile(
        rf"^{re.escape(field)}:\s*(.+?)\s*$",
        re.MULTILINE,
    )
    match = pattern.search(text)
    return match.group(1).strip() if match else ""


def main() -> int:
    markdown_files = sorted(
        path for path in ROOT.rglob("*.md") if ".git" not in path.parts
    )
    errors: list[str] = []
    documents: dict[str, Path] = {}
    names: dict[str, str] = {}
    metadata: dict[str, tuple[str, str, str, str, str, str]] = {}
    texts: dict[Path, str] = {}

    for path in markdown_files:
        text = path.read_text(encoding="utf-8")
        texts[path] = text
        identifier = ID_RE.search(text)
        if not identifier:
            continue
        document_id = identifier.group(1)
        if document_id in documents:
            errors.append(
                f"duplicate Document ID {document_id}: "
                f"{documents[document_id].relative_to(ROOT)} and {path.relative_to(ROOT)}"
            )
        else:
            documents[document_id] = path
        name = NAME_RE.search(text)
        if name:
            names[document_id] = name.group(1).strip()
        metadata[document_id] = (
            front_matter_value(text, "Document Name"),
            front_matter_value(text, "Book") or "—",
            front_matter_value(text, "Status"),
            front_matter_value(text, "Version"),
            front_matter_value(text, "Last Updated"),
            path.relative_to(ROOT).as_posix(),
        )

    for document_id, expected_name in CANONICAL_NAMES.items():
        actual_name = names.get(document_id)
        if actual_name is None:
            errors.append(f"missing canonical document {document_id}")
        elif actual_name.upper() != expected_name:
            errors.append(
                f"{document_id}: expected Document Name '{expected_name}', got '{actual_name}'"
            )

    registry_text = texts.get(DOCUMENT_REGISTRY)
    if registry_text is None:
        errors.append(
            f"missing Document Registry: {DOCUMENT_REGISTRY.relative_to(ROOT)}"
        )
        registry_rows: dict[str, tuple[str, str, str, str, str, str]] = {}
    else:
        registry_rows = {}
        for row in REGISTRY_ROW_RE.findall(registry_text):
            document_id = row[0]
            registered_metadata = tuple(value.strip() for value in row[1:])
            if document_id in registry_rows:
                errors.append(
                    f"Document Registry contains duplicate row for {document_id}"
                )
            registry_rows[document_id] = registered_metadata

    for document_id, expected_metadata in sorted(metadata.items()):
        registered_metadata = registry_rows.get(document_id)
        if registered_metadata is None:
            errors.append(f"Document Registry is missing {document_id}")
        elif registered_metadata != expected_metadata:
            errors.append(
                f"Document Registry metadata mismatch for {document_id}: "
                f"expected {expected_metadata}, got {registered_metadata}"
            )
    for document_id in sorted(set(registry_rows) - set(metadata)):
        errors.append(f"Document Registry contains unknown {document_id}")

    for path, text in texts.items():
        if path != GLOSSARY:
            for label, pattern in FORBIDDEN_TERMS.items():
                for match in pattern.finditer(text):
                    line = text.count("\n", 0, match.start()) + 1
                    errors.append(
                        f"{path.relative_to(ROOT)}:{line}: non-canonical term '{label}'"
                    )

        for section in related_sections(text):
            for related_id in RELATED_ID_RE.findall(section):
                if related_id not in documents:
                    errors.append(
                        f"{path.relative_to(ROOT)}: Related Documents references "
                        f"missing {related_id}"
                    )

        for raw_target in LINK_RE.findall(text):
            target = local_link_target(path, raw_target)
            if target is not None and not target.exists():
                errors.append(
                    f"{path.relative_to(ROOT)}: broken local link '{raw_target}'"
                )

    if errors:
        print("Documentation validation failed:")
        for error in errors:
            print(f"- {error}")
        return 1

    related_count = sum(
        len(RELATED_ID_RE.findall(section))
        for text in texts.values()
        for section in related_sections(text)
    )
    print(
        "Documentation validation passed: "
        f"{len(markdown_files)} Markdown files, "
        f"{len(documents)} unique Document IDs, "
        f"{related_count} Related Documents references, "
        f"{len(registry_rows)} Document Registry rows."
    )
    return 0


if __name__ == "__main__":
    sys.exit(main())
