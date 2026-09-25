# Git hooks

Local git hooks for this repository.

## Setup (once per clone)

    git config core.hooksPath .githooks

## Hooks

### pre-push

Runs `pnpm test:e2e` in `services/backend` before pushing to `main`.

- Blocks the push if e2e fail.
- Skips for feature branches and `test/*` (experiments).
- Bypass (emergency): `git push --no-verify`.

## When --no-verify is allowed

`git push --no-verify` bypasses the pre-push hook. Use it **only** when:

1. The failing tests are a **known, documented issue** (see AI-Brain Pitfalls).
2. You are **immediately following up** with a CI run on GitHub.
3. If CI is **red** — revert the commit with `git revert <sha>`.

Do **not** use `--no-verify` for:
- "I'll fix it later" (it never gets fixed).
- Skipping slow tests on a regular basis.
- Any push where CI cannot verify the result.

If you used `--no-verify`, add a comment in the commit body with the reason:

    git commit -m "..." -m "Bypass: pre-push failing on TODO-1 flakiness, CI to verify"
