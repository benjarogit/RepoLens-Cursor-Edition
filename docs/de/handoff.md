# IDE-Handoff

<p align="right">
  <a href="../en/handoff.md">English</a> · <strong>Deutsch</strong>
  · <a href="index.md">Docs-Index</a>
  · <a href="../../README.de.md">README</a>
</p>

Mit `--agent cursor-ide` ruft RepoLens **kein** Claude, Codex oder `cursor-agent` auf.  
Es schreibt eine Prompt-Datei und wartet, bis der **Cursor-Chat** per Dateien antwortet.

## In einem Satz

**Prompt lesen → Antwort schreiben → Done setzen** — wiederholen, bis der Lauf fertig ist.

## Schritt für Schritt

```
repolens.sh  →  schreibt Prompt  →  druckt REPOLENS_CTL
     ↑                                    ↓
  touch done  ←  du oder der Agent schreibst die Antwort
```

1. Im Terminal (oder `logs/<run-id>/repolens-ctl.ndjson`) auf `REPOLENS_CTL` mit `"kind":"ide_handoff"` achten.
2. `files.prompt` aus dem JSON öffnen.
3. Lens im Chat ausführen (**Zielprojekt** prüfen).
4. Die **volle** Antwort nach `files.response` speichern (mind. ~400 Bytes; keine leeren Stubs).
5. `files.done` mit `touch` anlegen.

Danach macht RepoLens mit der nächsten Iteration oder Lens weiter.

## Gute Antworten

- Echte Findings oder klares `DONE`, wenn nichts zu melden ist
- Pro Finding: **Pfad**, **Severity** (Schweregrad), ein Satz **Risiko**, **Fix**
- Abschnitte **Method** + **Findings**
- Mindestens zwei konkrete `path:line`-Anchors, die im Repo existieren (z. B. `core/env-file.sh:39`)
- Kein Fülltext, Byte-Padding (`# continuity` / `# pad`) oder Automation-/Grep-Worker-Templates

RepoLens lehnt flache/templated Antworten ab (`IDE_RESPONSE_REJECTED`). `DONE` ohne neue Findings braucht ≥3 verifizierte Anchors. Nur für Demos: `REPOLENS_IDE_ALLOW_STUB=1`.

## Nützliche Umgebungsvariablen

| Variable | Bedeutung |
|----------|-----------|
| `REPOLENS_IDE_AUTONOMOUS=1` | Markiert Handoffs für einen autonomen Agenten |
| `REPOLENS_IDE_FAIL_FAST=1` | Stoppt die Lens bei schlechter oder fehlender Antwort (Standard) |
| `REPOLENS_IDE_MIN_RESPONSE_BYTES` | Mindestgröße nach Padding-Strip (Standard 400); Pfad-Anchors Pflicht |
| `REPOLENS_CURSOR_IDE_POLL_SEC` | Wie oft nach `done` geschaut wird |
| `REPOLENS_CURSOR_IDE_MAX_WAIT_SEC` | Maximale Wartezeit pro Iteration |

## Hängt der Lauf?

1. `logs/<run-id>/summary.json` prüfen.
2. Fortsetzen:

   ```bash
   ./repolens.sh --resume <run-id> \
     --project /pfad/zum/projekt \
     --agent cursor-ide --local --yes
   ```

Siehe auch: [Operator-Guide](operator.md) · [Cursor-Rules](https://github.com/benjarogit/RepoLens-Cursor-Edition/blob/master/.cursor/rules/repolens-ide-handoff.mdc)
