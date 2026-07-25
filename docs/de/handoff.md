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
2. `files.prompt` aus dem JSON öffnen. Jeder Prompt endet mit dem Handoff-Protokoll inklusive Position im Lauf (`lens 7/42`).
3. Lens im Chat ausführen (**Zielprojekt** prüfen).
4. Die **volle** Antwort nach `files.response` speichern (mind. ~400 Bytes; keine leeren Stubs).
5. `files.done` mit `touch` anlegen.

Danach macht RepoLens mit der nächsten Iteration oder Lens weiter.

## Vollständiges Audit in einem Chat

Ein volles Audit ist eine lange Kette von Handoffs, und der Chat soll sie alle bedienen. Zwei Angaben machen das beherrschbar:

- Jedes `ide_handoff` trägt `lens_index`, `lens_total` und `last_lens` — der Agent weiß, wo er steht.
- Der Lauf endet mit `"kind":"run_complete"`. Bis dahin kommen weitere Handoffs.

Die Disziplin, die einen langen Lauf im Kontext-Budget hält:

- **Eine Chat-Zeile pro Handoff**, z. B. `Lens 7/42 security/injection — 3 Findings (1 high)`. Die Analyse gehört in die Response-Datei, nicht in den Chat.
- **Nicht zwischendurch nachfragen.** Nicht anbieten, den Lauf zu kürzen; nicht melden, das sei zu viel für den Chat.
- **Eine unpassende Lens ist kein Abbruchgrund.** Antwort mit `NOT APPLICABLE`, Begründung und mindestens zwei echten `path:line`-Anchors, die das Geprüfte belegen, dann `done` touchen.
- **Bei Fehlern** die Ursache in die Response-Datei schreiben, eine Chat-Zeile melden, weiter mit dem nächsten Handoff.

Nach `run_complete`: Findings aus `files.findings_dir` und `files.summary` lesen, in den Plan-Modus wechseln und jede offene Entscheidung als interaktive Frage stellen — **Antwort A ist dabei immer die Best-Practice-Empfehlung** (der übliche, verteidigbare Weg, nicht zwingend der theoretisch beste).

## Gute Antworten

- Echte Findings oder klares `DONE`, wenn nichts zu melden ist
- Pro Finding: **Pfad**, **Severity** (Schweregrad), ein Satz **Risiko**, **Fix**
- Abschnitte **Method** + **Findings**
- Mindestens zwei konkrete `path:line`-Anchors, die im Repo existieren (z. B. `core/env-file.sh:39`)
- Kein Fülltext, Byte-Padding (`# continuity` / `# pad`) oder Automation-/Grep-Worker-Templates

RepoLens lehnt flache/templated Antworten ab (`IDE_RESPONSE_REJECTED`) und wiederholt dieselbe Iteration. Der Fehler nennt im Feld `reason` die verletzte Prüfung (`reply is 315 bytes, needs at least 400`, `missing a '## Findings' section`, …) — genau das beheben und die Response-Datei neu schreiben. `DONE` ohne neue Findings braucht ≥3 verifizierte Anchors. Nur für Demos: `REPOLENS_IDE_ALLOW_STUB=1`.

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
