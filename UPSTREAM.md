# Upstream sync (RepoLens Cursor Edition)

This repository is a **standalone fork** of [TheMorpheus407/RepoLens](https://github.com/TheMorpheus407/RepoLens) with Cursor IDE handoff (`cursor-ide`), local-first defaults, and helper scripts (`repolens_until_done.sh`, `repolens_agent_or_ide.sh`).

GitHub: [benjarogit/RepoLens-Cursor-Edition](https://github.com/benjarogit/RepoLens-Cursor-Edition) (`master`).

## Remotes (typical)

```bash
git remote -v
# origin / fork  →  benjarogit/RepoLens-Cursor-Edition
# origin upstream remote often named:
# origin  → TheMorpheus407/RepoLens   (fetch upstream)
# fork    → benjarogit/RepoLens-Cursor-Edition
```

```bash
git fetch origin master   # upstream, if origin points there
git log -1 --oneline origin/master
cat UPSTREAM_REVISION
```

## Merge workflow

1. Clean working tree (commit or stash).
2. `git merge origin/master` (or `upstream/master`).
3. Resolve conflicts: prefer **upstream** for neutral tooling (lenses, ledger, triage, tests); prefer **fork** for Cursor handoff (`lib/cursor_runner.sh`, `cursor-ide` branches in `repolens.sh` / `lib/core.sh`).
4. `bash -n repolens.sh lib/core.sh lib/summary.sh lib/cursor_runner.sh`
5. Update [`UPSTREAM_REVISION`](UPSTREAM_REVISION) to the upstream SHA you merged.
6. Smoke: `./repolens.sh --help` and a narrow `--domain security --local --dry-run` if available.

### Fork-specific paths (review carefully)

| Area | Paths |
|------|--------|
| Cursor IDE / CTL | `repolens.sh`, `lib/cursor_runner.sh`, `lib/core.sh`, `lib/summary.sh` |
| Resume wrappers | `repolens_until_done.sh`, `repolens_agent_or_ide.sh` |
| Cursor rules / skill | `.cursor/rules/`, `.cursor/skills/audit-pipeline/` |
| Docs / branding | `README.md`, `README.de.md`, `docs/`, this file |

## Publish

Push to `fork` / `benjarogit/RepoLens-Cursor-Edition` after merge and docs updates. Do not add Cursor co-author trailers to commits.
