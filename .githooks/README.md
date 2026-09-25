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
