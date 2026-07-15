# IDE-Handoff-Protokoll

**Navigation:** [README.de](../../README.de.md) · [Operator](operator.md) · [English](../en/handoff.md)

Mit `--agent cursor-ide` startet RepoLens keinen externen Agent-CLI. Es wartet, bis der Cursor-Chat-Agent jede Lens-Iteration über Dateien abschließt.

## Ablauf

```
repolens.sh  →  schreibt Prompt  →  REPOLENS_CTL (stderr + ndjson)
     ↑                                        ↓
  touch done  ←  Agent schreibt Antwort  ←  Cursor Agent
```

1. CTL-Event lesen: stderr `REPOLENS_CTL {…}` oder `logs/<run-id>/repolens-ctl.ndjson` (`kind: ide_handoff`)
2. `files.prompt` öffnen
3. Lens im Chat ausführen (Projekt-Kontext)
4. Volle Antwort nach `files.response` schreiben (≥ `REPOLENS_IDE_MIN_RESPONSE_BYTES`, Default 400)
5. `touch files.done`

## Qualität

- Echte Findings oder `DONE` — keine Stub-Texte
- Pro Finding: Pfad, Severity, ein Satz Exploit, Fix
- Nur für Demos: `REPOLENS_IDE_ALLOW_STUB=1`

## Nützliche Env

| Variable | Rolle |
|----------|--------|
| `REPOLENS_IDE_AUTONOMOUS=1` | Handoffs für autonome Agenten markieren |
| `REPOLENS_IDE_FAIL_FAST=1` | Lens bei abgelehnter/fehlender Antwort stoppen (Default) |
| `REPOLENS_CURSOR_IDE_POLL_SEC` | Poll-Intervall während des Wartens |
| `REPOLENS_CURSOR_IDE_MAX_WAIT_SEC` | Max. Wartezeit pro Iteration |

## Stall / Resume

`logs/<run-id>/summary.json` prüfen, dann:

```bash
./repolens.sh --resume <run-id> --project <pfad> --agent cursor-ide --local --yes
```
