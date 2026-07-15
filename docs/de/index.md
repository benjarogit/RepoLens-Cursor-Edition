# Dokumentation

Willkommen bei der Doku zu **RepoLens Cursor Edition**. Navigation über die Sidebar; Sprache oben umschalten.

## In dieser Reihenfolge lesen

1. **[Operator-Guide](operator.md)** — erste Läufe, Findings, Resume, sinnvolle Domains  
2. **[IDE-Handoff](handoff.md)** — wie Cursor jede Lens abschließt (Prompt → Antwort → Done)  
3. **[Toolgate-Tools](toolgate-tools.md)** — welche Scanner/Linter laufen können  

## Referenz

| Doc | Wann |
|-----|------|
| [CLI & Modes](full-reference.md) | Flags, Modes, längere Upstream-Referenz (EN, Fallback) |
| [Finding-Registry](finding-registry-schema.md) | Aufbau von `findings.jsonl` / CSV (EN, Fallback) |

## Projekt

| Doc | Wann |
|-----|------|
| [Upstream-Sync](https://github.com/benjarogit/RepoLens-Cursor-Edition/blob/master/UPSTREAM.md) | Merge von TheMorpheus407/RepoLens |
| [Changelog](https://github.com/benjarogit/RepoLens-Cursor-Edition/blob/master/CHANGELOG.md) | Änderungen in Cursor Edition / Upstream |
| [Methodik](https://github.com/benjarogit/RepoLens-Cursor-Edition/blob/master/METHODOLOGY.md) | Lens-Design (fortgeschritten, EN) |
| [Contributing](https://github.com/benjarogit/RepoLens-Cursor-Edition/blob/master/CONTRIBUTING.md) | Lenses / Pull Requests (EN) |

## Cursor-Dateien in diesem Repo

| Pfad | Rolle |
|------|--------|
| [`.cursor/rules/`](https://github.com/benjarogit/RepoLens-Cursor-Edition/tree/master/.cursor/rules) | Agent-Policy und Handoff-Hinweise |
| [`.cursor/skills/audit-pipeline/`](https://github.com/benjarogit/RepoLens-Cursor-Edition/tree/master/.cursor/skills/audit-pipeline) | Strukturprüfung, dann RepoLens aus dem Chat |

## Ein Befehl zum Merken

```bash
export REPOLENS_IDE_AUTONOMOUS=1
./repolens.sh --project /pfad/zum/projekt --agent cursor-ide --local --domain security --yes
```

Repository-README: [Deutsch](https://github.com/benjarogit/RepoLens-Cursor-Edition/blob/master/README.de.md) · [English](https://github.com/benjarogit/RepoLens-Cursor-Edition/blob/master/README.md)
