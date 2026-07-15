# Releasing (Cursor Edition)

How to cut a **RepoLens Cursor Edition** release without inventing changelog text.

## Rules

1. **Write the changelog yourself** under `CHANGELOG.md` (Keep a Changelog).
2. Promote fork-facing notes from `[Unreleased]` into a dated section:
   `## [Cursor Edition YYYY.MM.DD] - YYYY-MM-DD`
3. Commit that change to `master`, then create the release.

The GitHub Action **does not** invent changelog bullets from commits. It packages the section you wrote and **appends**:

- a **compare link** to the previous `cursor-edition-*` tag
- a short **commit list** (linked SHAs; full range on GitHub if there are many)

## Option A — tag push

```bash
# after CHANGELOG section exists on master:
git tag -a cursor-edition-YYYY.MM.DD -m "Cursor Edition YYYY.MM.DD"
git push fork cursor-edition-YYYY.MM.DD
```

Workflow [`.github/workflows/release.yml`](https://github.com/benjarogit/RepoLens-Cursor-Edition/blob/master/.github/workflows/release.yml) creates/updates the GitHub Release from that section.

## Option B — Actions UI

1. Ensure the dated `CHANGELOG` section is on `master`.
2. Actions → **release** → Run workflow.
3. Input `date` = `YYYY.MM.DD` (optional dry-run first).

If the tag is missing, the workflow creates `cursor-edition-YYYY.MM.DD` on the current `master` tip and publishes the release.

## Check locally

```bash
./ci/extract-changelog-section.sh 2026.07.15
./ci/release-commit-range.sh cursor-edition-2026.07.15
```

## Docs site

Docs deploy separately via the `docs` workflow when `docs/` / `mkdocs.yml` change. Releases link the site in the release body.
