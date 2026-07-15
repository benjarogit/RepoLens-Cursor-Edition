# Upstream sync (RepoLens Cursor Edition)

How to pull changes from [TheMorpheus407/RepoLens](https://github.com/TheMorpheus407/RepoLens) into this fork.

GitHub: [benjarogit/RepoLens-Cursor-Edition](https://github.com/benjarogit/RepoLens-Cursor-Edition) (`master`).  
Pinned commit: [`UPSTREAM_REVISION`](UPSTREAM_REVISION).

## Remotes in this clone (typical)

```bash
git remote -v
# origin  → TheMorpheus407/RepoLens          (upstream)
# fork    → benjarogit/RepoLens-Cursor-Edition
```

```bash
git fetch origin master
git log -1 --oneline origin/master
cat UPSTREAM_REVISION   # should match after a successful sync
```

## Merge steps

1. Clean working tree (commit or stash).
2. `git merge origin/master`.
3. On conflicts:
   - Prefer **upstream** for lenses, ledger, triage, tests, and neutral `lib/*.sh`
   - Keep **fork** for Cursor handoff (`lib/cursor_runner.sh`, `cursor-ide` paths in `repolens.sh` / `lib/core.sh` / `lib/summary.sh`)
4. Quick check: `bash -n repolens.sh lib/core.sh lib/summary.sh lib/cursor_runner.sh`
5. Write the merged upstream SHA into `UPSTREAM_REVISION`.
6. Optional smoke test: `./repolens.sh --help`

## Fork-only paths (review on every sync)

| Area | Paths |
|------|--------|
| Cursor IDE | `repolens.sh`, `lib/cursor_runner.sh`, `lib/core.sh`, `lib/summary.sh` |
| Wrappers | `repolens_until_done.sh`, `repolens_agent_or_ide.sh` |
| Cursor guidance | `.cursor/rules/`, `.cursor/skills/audit-pipeline/` |
| Docs / brand | `README.md`, `README.de.md`, `docs/`, this file |

## Publish

```bash
git push fork master
```

Do not add Cursor co-author trailers to commits.
