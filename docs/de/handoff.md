# IDE-Handoff

<p align="right">
  <a href="../en/handoff.md">English</a> · <strong>Deutsch</strong>
  · <a href="index.md">Docs-Index</a>
  · <a href="../../README.de.md">README</a>
</p>

Mit `--agent cursor-ide` ruft RepoLens **kein** Claude, Codex oder `cursor-agent` auf.  
Es schreibt eine Prompt-Datei und wartet, bis der **Cursor-Chat** per Dateien antwortet.

## In einem Satz

**Prompt lesen → Antwort schreiben → gehashtes `complete.json` publizieren** — wiederholen, bis der Lauf fertig ist.

## Schritt für Schritt

```
repolens.sh  →  schreibt request.json + prompt.md  →  druckt REPOLENS_CTL
     ↑                                                         ↓
  complete.json  ←  du schreibst response.md + Hash-Marker
```

1. Im Terminal (oder `logs/<run-id>/repolens-ctl.ndjson`) auf `REPOLENS_CTL` mit `"kind":"ide_handoff"` achten.
2. `files.prompt` aus dem JSON öffnen. Jeder Prompt endet mit dem Handoff-Protokoll inklusive Position im Lauf (`lens 7/42`) und den exakten Finalize-Befehlen.
3. Lens im Chat ausführen (**Zielprojekt** prüfen).
4. Die **volle** Antwort nach `files.response` speichern (mind. ~400 Bytes; keine leeren Stubs).
5. `files.complete` atomar publizieren: `complete.json` mit der `request_id` dieses Requests und dem `git hash-object`-Digest von `response.md`. **Kein** `touch done`.

Danach validiert RepoLens private Snapshots beider Dateien und macht mit der nächsten Iteration oder Lens weiter. Bei Reject wird nur `complete.json` gelöscht — Response korrigieren und Marker neu setzen.

Layout pro Request:

```text
logs/<run-id>/<domain>/<lens>/cursor-ide/lens/<request-id>/
  request.json  prompt.md  response.md  complete.json
```

## Vollständiges Audit in einem Chat

Ein volles Audit ist eine lange Kette von Handoffs, und der Chat soll sie alle bedienen. Zwei Angaben machen das beherrschbar:

- Jedes `ide_handoff` trägt `lens_index`, `lens_total` und `last_lens` — der Agent weiß, wo er steht.
- Der Lauf endet mit `"kind":"run_complete"` (`next_action: plan_mode`). Bis dahin kommen weitere Handoffs.

Die Disziplin, die einen langen Lauf im Kontext-Budget hält:

- **Eine Chat-Zeile pro Handoff**, z. B. `Lens 7/42 security/injection — 3 Findings (1 high)`. Die Analyse gehört in die Response-Datei, nicht in den Chat.
- **Nicht zwischendurch nachfragen.** Nicht anbieten, den Lauf zu kürzen; nicht melden, das sei zu viel für den Chat.
- **Eine unpassende Lens ist kein Abbruchgrund.** Antwort mit `NOT APPLICABLE`, Begründung und mindestens zwei echten `path:line`-Anchors, die das Geprüfte belegen, dann `complete.json` publizieren.
- **Bei Fehlern** die Ursache in die Response-Datei schreiben, eine Chat-Zeile melden, weiter mit dem nächsten Handoff.

Nach `run_complete`: Findings aus `files.findings_dir` und `files.summary` lesen, in den Plan-Modus wechseln und **Batch-Grilling** (Frontier-Runden) starten: alle *jetzt* beantwortbaren Entscheidungen in einer Runde, dann warten und Frontier neu berechnen. **Antwort A ist dabei immer die Best-Practice-Empfehlung** (der übliche, verteidigbare Weg, nicht zwingend der theoretisch beste). Pro Runde höchstens ~8 Fragen; abhängige Entscheidungen erst danach.

## Gute Antworten

- Echte Findings oder klares `DONE`, wenn nichts zu melden ist
- Pro Finding: **Pfad**, **Severity** (Schweregrad), ein Satz **Risiko**, **Fix**
- Abschnitte **Method** + **Findings**
- Mindestens zwei konkrete `path:line`-Anchors, die im Repo existieren (z. B. `core/env-file.sh:39`); Zitate über Symlinks oder hinter EOF zählen nicht
- Kein Fülltext, Byte-Padding (`# continuity` / `# pad`) oder Automation-/Grep-Worker-Templates

RepoLens lehnt flache/templated Antworten ab (`IDE_RESPONSE_REJECTED`) und wiederholt dieselbe Iteration. Der Fehler nennt im Feld `reason` die verletzte Prüfung (`reply is 315 bytes, needs at least 400`, `missing a '## Findings' section`, …) — genau das beheben, Response neu schreiben und `complete.json` erneut publizieren. `DONE` ohne neue Findings braucht ≥3 verifizierte Anchors. Nur für Demos: `REPOLENS_IDE_ALLOW_STUB=1`.

## Nützliche Umgebungsvariablen

| Variable | Bedeutung |
|----------|-----------|
| `REPOLENS_IDE_AUTONOMOUS=1` | Markiert Handoffs für einen autonomen Agenten |
| `REPOLENS_IDE_FAIL_FAST=1` | Stoppt die Lens bei schlechter oder fehlender Antwort (Standard) |
| `REPOLENS_IDE_MIN_RESPONSE_BYTES` | Mindestgröße nach Padding-Strip (Standard 400); Pfad-Anchors Pflicht |
| `REPOLENS_CURSOR_IDE_POLL_SEC` | Wie oft nach `complete.json` geschaut wird |
| `REPOLENS_CURSOR_IDE_MAX_WAIT_SEC` | Maximale Wartezeit pro Iteration |

`REPOLENS_IDE_*` mappt auf `REPOLENS_CURSOR_IDE_*`, wo sinnvoll; Edition-Defaults gewinnen.

## Hängt der Lauf?

1. `logs/<run-id>/summary.json` prüfen.
2. Fortsetzen:

   ```bash
   ./repolens.sh --resume <run-id> \
     --project /pfad/zum/projekt \
     --agent cursor-ide --local --yes
   ```

Resume vergibt eine neue `request_id`; ein altes `complete.json` schließt den neuen Request nicht ab.

Siehe auch: [Cursor-IDE-Protokoll](../cursor-ide.md) · [Operator-Guide](operator.md) · [Cursor-Rules](https://github.com/benjarogit/RepoLens-Cursor-Edition/blob/master/.cursor/rules/repolens-ide-handoff.mdc)
