# RepoLens upstream sync (CSRetro vendored fork)

The tree `maintainers/RepoLens/` is a **vendored fork** of [TheMorpheus407/RepoLens](https://github.com/TheMorpheus407/RepoLens) with CSRetro-specific integrations (Cursor `cursor-ide`, `repolens_until_done.sh`, `tools.sh` entry points, log hygiene). It is **not** a git submodule.

## Baseline revision

After each successful merge from upstream, update [`UPSTREAM_REVISION`](UPSTREAM_REVISION) with the upstream commit you consolidated against.

## One-time: add a remote (in the CSRetro clone)

```bash
cd /path/to/csretro
git remote add repolens-upstream https://github.com/TheMorpheus407/RepoLens.git
git fetch repolens-upstream
```

## Check for new upstream commits

```bash
git fetch repolens-upstream
git log -1 --oneline repolens-upstream/master
# or repolens-upstream/main depending on default branch
```

Compare against the SHA in `UPSTREAM_REVISION`.

## Consolidate changes (recommended workflow)

1. **Shallow clone upstream** to a temp directory (or use `git worktree`).
2. **Diff** against `maintainers/RepoLens/` — focus on upstream changes you want (lenses, `lib/*.sh`, `config/`, prompts).
3. **Re-apply** or **cherry-pick** behaviour; **do not** blindly overwrite CSRetro edits listed below.
4. Run **`make check`** or **`bash tests/run-all.sh`** inside `maintainers/RepoLens/` if you touched shell logic.
5. From CSRetro root: **`./tools.sh repolens --domain security --dry-run`** (or a narrow `--focus`) to sanity-check wiring.
6. Commit with a clear message, e.g. `maintainers(repolens): sync upstream to <short-sha>`.
7. Update **`UPSTREAM_REVISION`** to the upstream commit you merged.

### Files to treat as fork-specific (review carefully on each sync)

| Area | Paths (typical) |
|------|-----------------|
| Cursor IDE / CTL | `repolens.sh`, `lib/cursor_runner.sh`, `lib/core.sh`, `lib/streak.sh`, `lib/summary.sh` (as touched by fork) |
| Auto-resume wrapper | `repolens_until_done.sh` |
| Docs / branding | `README.md` (Cursor Local Edition / csretro blocks), this `UPSTREAM.md`, `UPSTREAM_REVISION` |
| Consumer integration | CSRetro [`tools.sh`](../../tools.sh), [`tools/lib/repolens_logs_prune.sh`](../../tools/lib/repolens_logs_prune.sh), [`.cursor/rules/repolens-ide-handoff.mdc`](../../.cursor/rules/repolens-ide-handoff.mdc), [`.vscode/tasks.json`](../../.vscode/tasks.json) |

Upstream may rename files; after a large upstream jump, re-diff the whole tree.

## Conflicts

Prefer **upstream behaviour** for neutral tooling (lenses, prompts, domain config), and **preserve** CSRetro-only paths (Cursor handoff protocol, `repolens_until_done`, log pruning hooks). When in doubt, keep upstream logic and re-layer the fork’s small patches in a follow-up commit.

## Publishing

Push consolidated changes on your usual CSRetro branch. Optionally maintain a **separate GitHub fork** of RepoLens for visibility; the **source of truth** for CSRetro remains this monorepo path.
