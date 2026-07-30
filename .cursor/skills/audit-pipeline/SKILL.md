---
name: audit-pipeline
description: Struktur-Audit dann RepoLens (Cursor Edition) auf ein Projekt aus dem Chat starten. Nutzen bei Audit-Pipeline, Struktur-Audit und RepoLens, repolense starten, Projekt auditieren, vollständiges Audit, alle Lenses, oder wenn der Nutzer Phase 1 Struktur danach Phase 2 Lenses will.
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

**Vollständiges Audit** (alle Default-Audit-Domains) — wenn der Nutzer „komplett“, „alle Lenses“ oder „volles Audit“ sagt, ohne Rückfrage so starten:

```bash
"$REPOLENS_ROOT/repolens.sh" \
  --project "<ZIELPROJEKT>" \
  --agent cursor-ide \
  --local \
  --mode audit \
  --yes
```

Nur die passenden Lenses gewünscht? `--relevant-domains` prunt anhand des Projekts, statt den Lauf zu verkürzen.

Terminal im Hintergrund starten (`block_until_ms: 0`) und die Ausgabe auf `REPOLENS_CTL` pollen — der Chat muss frei bleiben, um die Handoffs zu bedienen.

Weitere Optionen vom Nutzer: `--domain`, `--focus`, `--human-review`, `--resume <run-id>`.

## Handoff-Schleife (Pflicht)

Bei jedem `REPOLENS_CTL` mit `kind: ide_handoff`:

1. `files.prompt` lesen (Pfad unter `cursor-ide/lens/<request-id>/`)
2. Lens hier im Chat ausführen (Struktur-Bericht als Kontext)
3. Volle Antwort → `files.response` (`## Method`, `## Findings`, ≥ 2 echte `path:line`-Anchors, ≥ 400 Bytes)
4. Atomar `files.complete` publizieren: `complete.json` mit `request_id` + `git hash-object` von `response.md` (Befehle im Prompt-Footer). **Kein** `touch done`.
5. Sofort weiter zum nächsten Handoff

Bei Reject nur `complete.json` neu schreiben (Response korrigieren). Resume vergibt eine neue `request_id`.

Durchhalten bis `kind: run_complete`:

- Pro Handoff **eine** Chat-Zeile: `Lens 7/42 security/injection — 3 Findings (1 high)` bzw. `— keine Findings`. Details nur in die Response-Datei, damit der Kontext den ganzen Lauf trägt.
- Nicht fragen, ob weitergemacht wird; nicht anbieten, den Lauf zu kürzen; nicht „zu viel für den Chat“ melden. Viele Handoffs sind bei einem vollen Audit der Normalfall.
- Unpassende Lens: Antwort mit `NOT APPLICABLE` + Begründung + ≥ 2 `path:line`-Anchors, die das belegen. Nicht abbrechen.
- Fehler: Ursache in die Response-Datei, eine Chat-Zeile, weiter mit dem nächsten Handoff.

Bei echtem Abbruch (Rate-Limit, Absturz): `summary.json` lesen, mit `--resume <run-id>` fortsetzen.

Stub nur für Demos: `REPOLENS_IDE_ALLOW_STUB=1`.

## Nach `run_complete`

1. Findings aus `$REPOLENS_ROOT/logs/<run-id>/issues/` bzw. `final/findings.jsonl` einlesen (mit `--human-review` zusätzlich `final/todo.md`, `needs_review.md`).
2. In den **Plan-Modus** wechseln: Severity-Reihenfolge, betroffene Pfade, Aufwand, Fix-Reihenfolge.
3. Skill **`batch-grilling`**: offene Punkte als Frontier-Runden abfragen (alle *jetzt* beantwortbaren Fragen auf einmal). **Antwort A/1 ist immer die Best-Practice-Empfehlung** (`(Empfohlen)` im Label) — der übliche Weg, nicht zwingend der theoretisch beste. Fakten aus den Finding-Dateien nachschlagen. Pro Runde ~8 Fragen; abhängige Entscheidungen erst in der nächsten Runde.
4. Erst wenn die Frontier leer ist und Verständnis bestätigt wurde, implementieren.

## Nicht tun

- Andere `--agent`-Werte als Fallback
- Subagent nur für die Handoff-Schleife (Terminal weg)
- Phase 1 überspringen, wenn der Nutzer beides will
- Die Handoff-Schleife abbrechen, bevor `run_complete` kam
