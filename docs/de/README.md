# Dokumentation

<p align="right">
  <a href="../README.md">English docs index</a> · <strong>Deutsch</strong>
  · <a href="../README.de.md">README</a>
</p>

## In dieser Reihenfolge lesen

1. **[README](../README.de.md)** — was dieser Fork ist und wie du schnell startest
2. **[Operator-Guide](operator.md)** — erste Läufe, Findings, Resume, sinnvolle Domains
3. **[IDE-Handoff](handoff.md)** — wie Cursor jede Lens abschließt (Prompt → Antwort → Done)

## Wenn du mehr brauchst

| Doc | Wann |
|-----|------|
| [CLI- & Modes-Referenz](../en/full-reference.md) | Flags, Modes, längere Upstream-Referenz (EN) |
| [Finding-Registry-Schema](../finding-registry-schema.md) | Aufbau von `findings.jsonl` / CSV (EN) |
| [Upstream-Sync](../UPSTREAM.md) | Merge von TheMorpheus407/RepoLens |
| [Changelog](../CHANGELOG.md) | Änderungen in Cursor Edition / Upstream |
| [Methodik](../METHODOLOGY.md) | Lens-Design (fortgeschritten, EN) |
| [Contributing](../CONTRIBUTING.md) | Lenses / Pull Requests (EN) |

## Cursor-Dateien in diesem Repo

| Pfad | Rolle |
|------|--------|
| [`.cursor/rules/`](../.cursor/rules/) | Agent-Policy und Handoff-Hinweise |
| [`.cursor/skills/audit-pipeline/`](../.cursor/skills/audit-pipeline/) | Strukturprüfung, dann RepoLens aus dem Chat |

## Ein Befehl zum Merken

```bash
export REPOLENS_IDE_AUTONOMOUS=1
./repolens.sh --project /pfad/zum/projekt --agent cursor-ide --local --domain security --yes
```
