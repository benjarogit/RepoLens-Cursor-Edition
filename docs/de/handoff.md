# IDE-Handoff (einfach)

<p align="right">
  <a href="../en/handoff.md">English</a> · <strong>Deutsch</strong>
  · <a href="README.md">Docs-Index</a>
  · <a href="../../README.de.md">README</a>
</p>

Mit `--agent cursor-ide` ruft RepoLens **kein** Claude/Codex/`cursor-agent` auf.  
Es schreibt eine Prompt-Datei und wartet, bis der **Cursor-Chat** per Dateien antwortet.

## In einem Satz

**Prompt lesen → Antwort schreiben → Done tippen** — wiederholen, bis der Lauf fertig ist.

## Schritt für Schritt

```
repolens.sh  →  schreibt Prompt  →  druckt REPOLENS_CTL
     ↑                                    ↓
  touch done  ←  du/Agent schreibst Antwort
```

1. Im Terminal (oder `logs/<run-id>/repolens-ctl.ndjson`) auf `REPOLENS_CTL` mit `"kind":"ide_handoff"` achten.
2. `files.prompt` aus dem JSON öffnen.
3. Lens im Chat ausführen (**Zielprojekt** anschauen).
4. **Volle** Antwort nach `files.response` speichern (mind. ~400 Bytes; keine leeren Stubs).
5. `touch files.done`.

Danach macht RepoLens mit der nächsten Iteration oder Lens weiter.

## Gute Antworten

- Echte Findings oder klares `DONE`, wenn nichts zu melden ist
- Pro Finding: **Pfad**, **Severity**, ein Satz **Risiko**, **Fix**
- Kein Fülltext („automatischer Durchlauf“, leere Platzhalter)

Nur für Demos: `REPOLENS_IDE_ALLOW_STUB=1` (nicht für echte Audits).

## Nützliche Umgebungsvariablen

| Variable | Bedeutung |
|----------|-----------|
| `REPOLENS_IDE_AUTONOMOUS=1` | Handoffs für autonomen Agenten markieren |
| `REPOLENS_IDE_FAIL_FAST=1` | Lens bei schlechter/fehlender Antwort stoppen (Default) |
| `REPOLENS_CURSOR_IDE_POLL_SEC` | Wie oft nach `done` geschaut wird |
| `REPOLENS_CURSOR_IDE_MAX_WAIT_SEC` | Max. Wartezeit pro Iteration |

## Hängt der Lauf?

1. `logs/<run-id>/summary.json` prüfen.
2. Fortsetzen:

   ```bash
   ./repolens.sh --resume <run-id> \
     --project /pfad/zum/projekt \
     --agent cursor-ide --local --yes
   ```

Siehe auch: [Operator-Guide](operator.md) · [Cursor-Rules](../../.cursor/rules/repolens-ide-handoff.mdc)
