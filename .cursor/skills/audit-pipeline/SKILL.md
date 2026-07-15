---
name: audit-pipeline
description: Struktur-Audit dann RepoLens (Cursor Edition) auf ein Projekt aus dem Chat starten. Nutzen bei Audit-Pipeline, Struktur-Audit und RepoLens, repolense starten, Projekt auditieren, oder wenn der Nutzer Phase 1 Struktur danach Phase 2 Lenses will.
disable-model-invocation: true
---

# Audit-Pipeline: Struktur-Audit → RepoLens

Zweistufiger Lauf aus **einem Chat**:

1. **Struktur-Audit** (read-only, kein Code ändern)
2. **RepoLens Cursor Edition** (`cursor-ide`, `--local`) — Lenses mit Handoff-Protokoll

## Agent-Pflicht (dieser Fork)

**Immer** `--agent cursor-ide --local`. Niemals `claude`, `codex`, `opencode`, `cursor` (CLI) o. Ä. — auch nicht als „schneller Fallback“. Andere Backends brauchen externe Logins und umgehen `REPOLENS_CTL`-Handoff.

Siehe Rules: `repolens-agent-cursor-ide-only`, `repolens-ide-handoff`.

## Voraussetzungen

- `bash` 4+, `git`, `jq`, `timeout` installiert
- RepoLens-Root: dieses Repo (oder `REPOLENS_ROOT` auf den Clone zeigen)
- Zielprojekt: `--project` Pfad oder Workspace-Root
- Cursor-Chat, der IDE-Handoffs bedient (dieser Agent)

## Chat-Befehle (Beispiele)

```
Audit-Pipeline für /pfad/zu/projekt — Domain security
Struktur-Audit und RepoLens auf dieses Repo
Starte audit-pipeline mit --domain security --human-review
```

## Phase 1 — Struktur-Audit

1. Lies die Architektur-/Datenfluss-Oberfläche des Zielprojekts (Entry points, Auth, Secrets, Persistenz).
2. **Keine Code-Änderungen** am Zielprojekt.
3. Schreibe den Bericht nach:

   ```
   <ZIELPROJEKT>/.audit/struktur-audit-<YYYY-MM-DD>.md
   ```

   Verzeichnis `.audit/` anlegen falls nötig. Kurz in Phase-2-Prompt referenzieren (Architektur-Risiken, Datenfluss-Brüche).

## Phase 2 — RepoLens starten

Im Terminal (Hintergrund, `block_until_ms: 0`):

```bash
export REPOLENS_IDE_AUTONOMOUS=1
# Default: dieses Repo, wenn der Skill aus dem Fork-Workspace läuft
export REPOLENS_ROOT="${REPOLENS_ROOT:-$(git rev-parse --show-toplevel 2>/dev/null || pwd)}"

"$REPOLENS_ROOT/repolens.sh" \
  --project "<ZIELPROJEKT>" \
  --agent cursor-ide \
  --local \
  --domain "${DOMAIN:-security}" \
  --yes \
  ${HUMAN_REVIEW:+--human-review}
```

Optionale Variablen vom Nutzer:

| Parameter | Flag / Env |
|-----------|------------|
| Domain | `--domain security` (Default), `architecture`, `llm-security`, … |
| Eine Lens | `--focus injection` (+ `--domain security`) |
| Noise-Budget | `--human-review` |
| Voller Audit | `--mode audit` (lang, teuer — nur wenn explizit gewünscht) |
| Resume | `--resume <run-id>` |

`run-id` steht in der Terminal-Ausgabe und unter `$REPOLENS_ROOT/logs/<run-id>/`.

## Phase 2 — IDE-Handoff (Pflicht)

RepoLens wartet auf **dich (den Agent)**. Bei jeder Zeile `REPOLENS_CTL {…}` mit `"kind":"ide_handoff"`:

1. `files.prompt` lesen
2. Lens in **diesem Chat** ausführen (Projekt-Kontext + Struktur-Audit-Bericht als Hintergrund)
3. **Vollständige** Antwort nach `files.response` schreiben (≥ 400 Bytes, keine Stub-Texte)
4. `touch files.done` im Terminal

Terminal-Output auf `REPOLENS_CTL` oder `ide_handoff` prüfen. Bei Rate-Limit / Abbruch: `summary.json` lesen, mit `--resume <run-id>` fortsetzen.

Stub nur für Demos: `REPOLENS_IDE_ALLOW_STUB=1`.

## Abschluss

- Findings: `$REPOLENS_ROOT/logs/<run-id>/issues/`
- Mit `--human-review`: auch `final/`-Triage-Artefakte
- Kurze Chat-Zusammenfassung: Anzahl Findings, Top-3, Pfad zum Run

## Was nicht tun

- **Kein** `--agent claude|codex|opencode|cursor` — nur `cursor-ide`
- Keinen Subagent für die Handoff-Schleife (Terminal-Verlust)
- Phase 1 nicht überspringen, wenn der Nutzer „Struktur-Audit und RepoLens“ sagt
- Nicht `--mode audit` ohne explizite Nutzerfreigabe (Kosten/Zeit)
