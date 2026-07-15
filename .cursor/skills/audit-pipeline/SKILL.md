---
name: audit-pipeline
description: Struktur-Audit dann RepoLens (Cursor Edition) auf ein Projekt aus dem Chat starten. Nutzen bei Audit-Pipeline, Struktur-Audit und RepoLens, repolense starten, Projekt auditieren, oder wenn der Nutzer Phase 1 Struktur danach Phase 2 Lenses will.
disable-model-invocation: true
---

# Audit-Pipeline: Struktur zuerst, dann RepoLens

Zwei Phasen in **einem** Cursor-Chat:

1. **Struktur-Audit** — nur lesen, nichts am Zielcode ändern  
2. **RepoLens** — `--agent cursor-ide --local` mit IDE-Handoff

## Immer so starten

```bash
--agent cursor-ide --local
```

Nicht `claude` / `codex` / `opencode` / `cursor` (CLI) — die umgehen den Handoff.

Rules: `repolens-agent-cursor-ide-only`, `repolens-ide-handoff`.  
Menschliche Doku: `docs/de/operator.md`, `docs/de/handoff.md`.

## Phase 1 — Struktur

1. Zielprojekt grob verstehen (Einstiege, Auth, Secrets, Datenfluss).
2. Bericht schreiben nach:

   ```
   <ZIELPROJEKT>/.audit/struktur-audit-<YYYY-MM-DD>.md
   ```

## Phase 2 — RepoLens

```bash
export REPOLENS_IDE_AUTONOMOUS=1
export REPOLENS_ROOT="${REPOLENS_ROOT:-$(git rev-parse --show-toplevel 2>/dev/null || pwd)}"

"$REPOLENS_ROOT/repolens.sh" \
  --project "<ZIELPROJEKT>" \
  --agent cursor-ide \
  --local \
  --domain "${DOMAIN:-security}" \
  --yes \
  ${HUMAN_REVIEW:+--human-review}
```

Optionen vom Nutzer: `--domain`, `--focus`, `--human-review`, `--mode audit` (nur wenn explizit gewünscht), `--resume <run-id>`.

## Handoff (Pflicht)

Bei `REPOLENS_CTL` / `kind: ide_handoff`:

1. `files.prompt` lesen  
2. Lens hier im Chat ausführen (Struktur-Bericht als Kontext)  
3. Volle Antwort → `files.response` (≥ ~400 Bytes)  
4. `touch files.done`

Bei Abbruch: `summary.json` → `--resume`.

## Ende

- Findings: `$REPOLENS_ROOT/logs/<run-id>/issues/`
- Kurze Chat-Zusammenfassung: Anzahl, Top-3, Run-Pfad

## Nicht tun

- Andere `--agent`-Werte als Fallback
- Subagent nur für die Handoff-Schleife (Terminal weg)
- Phase 1 überspringen, wenn der Nutzer beides will
- Großes `--mode audit` ohne Freigabe
