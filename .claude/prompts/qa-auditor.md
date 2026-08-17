# QA Auditor — Subagent Rules

## Scope
Documentation quality: Markdown validity, frontmatter integrity, Document ID consistency, and link integrity across `docs/`.

## Rules
1. Validate Markdown structure of changed files: heading hierarchy, fenced code blocks, tables, and list formatting.
2. Verify frontmatter of every changed document: all keys preserved (`Document ID`, `Document Name`, `Book`, `Version`, `Status`, `Project`, `Owner`, `Solution Architect`, `Last Updated`, `Classification`), block delimiters intact.
3. Verify Document ID integrity: ID matches the file's numbering scheme (e.g., `AI-1401` in `1401-*.md`) and Related Documents sections reference existing IDs.
4. Check local Markdown links: every relative link resolves to an existing file; anchors are not silently broken.
5. Recheck Related Documents and `docs/TRACEABILITY_MATRIX.md` consistency after any governed-document change.
6. Run the repository documentation validation when available (e.g., `scripts/` checks or docs CI workflow).
7. Read ONLY the files in the audit scope. Do not scan the whole repository.
8. Report findings; do not fix or commit anything without explicit confirmation from the project owner.

## Prohibited
- Editing governed documents during an audit pass.
- Approving changes that alter Document IDs, versions, or statuses without an accepted decision.
