# Releases (Cursor Edition)

So schneidest du ein **RepoLens Cursor Edition**-Release, ohne Changelog-Text zu erfinden.

## Regeln

1. **Changelog selbst schreiben** in `CHANGELOG.md` (Keep a Changelog).
2. Fork-relevante Notes aus `[Unreleased]` in einen datierten Abschnitt heben:
   `## [Cursor Edition YYYY.MM.DD] - YYYY-MM-DD`
3. Nach `master` committen, dann Release erzeugen.

Die GitHub Action **erfindet keine** Changelog-Bullets aus Commits. Sie packt den Abschnitt, den du geschrieben hast, und **hängt an**:

- einen **Compare-Link** zum vorherigen `cursor-edition-*`-Tag
- eine kurze **Commit-Liste** (verlinkte SHAs; volle Range auf GitHub, wenn es viele sind)

## Option A — Tag pushen

```bash
# wenn der CHANGELOG-Abschnitt auf master liegt:
git tag -a cursor-edition-YYYY.MM.DD -m "Cursor Edition YYYY.MM.DD"
git push fork cursor-edition-YYYY.MM.DD
```

Workflow [`.github/workflows/release.yml`](https://github.com/benjarogit/RepoLens-Cursor-Edition/blob/master/.github/workflows/release.yml) legt/aktualisiert das GitHub Release aus diesem Abschnitt.

## Option B — Actions-UI

1. Datierter `CHANGELOG`-Abschnitt liegt auf `master`.
2. Actions → **release** → Run workflow.
3. Input `date` = `YYYY.MM.DD` (optional zuerst Dry-Run).

Fehlt der Tag, erzeugt der Workflow `cursor-edition-YYYY.MM.DD` auf dem aktuellen `master`-Tip und veröffentlicht das Release.

## Lokal prüfen

```bash
./ci/extract-changelog-section.sh 2026.07.15
./ci/release-commit-range.sh cursor-edition-2026.07.15
```

## Docs-Site

Docs deployen separat über den `docs`-Workflow bei Änderungen an `docs/` / `mkdocs.yml`. Releases verlinken die Site im Release-Body.
