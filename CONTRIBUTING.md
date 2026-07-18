---
Document Type: Contribution Guide
Status: ACTIVE
Last Updated: July 2026
Classification: Internal
---

# CONTRIBUTING

## Purpose

This guide defines how people contribute to the SHIK Platform repository and its documentation. It supplements the repository-level `AGENTS.md`, which contains the mandatory operating constraints for AI agents.

The repository is the source of truth. Architectural statements are authoritative only when recorded in the applicable governed document and, for architecture decisions, in an accepted ADR.

## Branch workflow

- `main` is the source branch and must not be edited directly.
- Work only in the branch explicitly named for the task.
- Use one logical documentation concern per change package and per commit.
- Do not mix unrelated corrections, formatting, or content changes into a package.
- A pull request may be created only after an explicit request from the project owner.

Before changing documentation:

1. List every file that will be affected.
2. Describe the exact intended changes.
3. State the possible consequences.
4. Obtain confirmation from the project owner.
5. If documents conflict, present the supported options and request a decision before editing.

## Document Front Matter

Governed documents must begin with YAML Front Matter. Preserve the established field names and layout of the document family.

| Field | Rule |
|---|---|
| Document ID | Required for governed documents; must be unique. |
| Document Name | Required and must describe the document unambiguously. |
| Book | Required when the document belongs to a numbered book. |
| Version | Required; change only when the content change warrants it. |
| Status | Required and must use the repository's approved status vocabulary. |
| Project | Use `SHIK Platform` for project documents. |
| Owner | Required for governed documents. |
| Last Updated | Update only when the document is materially changed. |
| Classification | Required; preserve the applicable classification. |

Service and navigation files such as `README.md`, `SUMMARY.md`, `CHANGELOG.md`, `CONTRIBUTING.md`, and `DECISIONS.md` do not receive a governed Document ID unless the project owner explicitly changes that policy.

## Document ID rules

- Never change an existing Document ID without explicit owner approval.
- Assign a new ID only with owner approval and according to the relevant document family.
- Check that the proposed ID is unique before using it.
- Register every new governed document in the Document Registry in the same package.
- Do not reuse an ID belonging to a removed, superseded, or historical document.
- A filename or heading does not override the ID recorded in Front Matter.

## Related Documents

Every governed document must contain a `Related Documents` section.

- Reference only Document IDs that exist in the Document Registry.
- Use the canonical ID and document name.
- Add relationships that materially help traceability; do not create decorative links.
- When an ID changes under explicit approval, update all incoming references in the same package.
- Recheck all Related Documents after every package.

## Architecture Decision Records

- Record a new architecture decision in an ADR; do not establish it only in a guide, overview, or decision summary.
- Follow the ADR lifecycle and status rules defined by ADR governance.
- Update the Architecture Decision Register when an ADR is added or its lifecycle status changes.
- `DECISIONS.md` is a readable summary of accepted decisions. It does not replace an ADR or the Architecture Decision Register.
- Do not silently resolve contradictions. Identify the documents supporting each option and obtain the project owner's decision.

## Terminology and naming

Use the canonical terminology defined by the project glossary. Keep product names, technology names, deployment terms, and storage terms consistent with accepted ADRs. Avoid introducing synonyms when an established term already exists.

## Navigation and registry

- `docs/README.md` is the documentation entry point.
- `docs/SUMMARY.md`, when present, is the central navigation map.
- The Document Registry is the canonical inventory of governed documents.
- Navigation and service files must link to governed documents without duplicating their authority.

## Validation

Run the repository documentation validator before completing every package:

```bash
python3 scripts/check-doc-terminology.py
```

The package is ready for review only when the validator reports no errors. Also verify:

- Front Matter completeness;
- unique Document IDs;
- Document Registry synchronization;
- valid Related Documents references;
- terminology consistency;
- absence of unintended file changes;
- the package diff contains only the approved scope.

## Commits and pull requests

- Create one commit per confirmed package.
- Use a concise commit message describing the documentation outcome.
- After committing, report the changed files and the semantic diff.
- Re-run validation and stop before the next package unless the project owner explicitly waived that checkpoint.
- Creating a commit does not authorize creating or merging a pull request.
- Create, update, or merge a pull request only after a separate explicit instruction.

## Prohibited changes

Without separate explicit permission, do not:

- edit `main` directly;
- delete or rename files;
- change an existing Document ID;
- perform mass formatting;
- modify content unrelated to the current package;
- invent architectural decisions, release history, or implementation facts;
- replace an accepted ADR with a summary document;
- create branches, issues, pull requests, or merges outside the approved task.

## Related Documents

- PB-109 — Terminology and Glossary
- ADR-1600 — Architecture Decision Register
- GOV-2703 — Architecture Decision Records Governance
- GOV-2707 — Document Registry
- RTM-001 — Requirements Traceability Matrix

---

**END OF DOCUMENT**
