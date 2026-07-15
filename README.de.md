# RepoLens Cursor Edition

[![License: Apache-2.0](https://img.shields.io/badge/License-Apache_2.0-blue.svg)](LICENSE)
[![Upstream](https://img.shields.io/badge/upstream-TheMorpheus407%2FRepoLens-informational)](https://github.com/TheMorpheus407/RepoLens)
[![Fork](https://img.shields.io/badge/fork-Cursor%20Edition-blue)](https://github.com/benjarogit/RepoLens-Cursor-Edition)

**Navigation:** [Start](#30-sekunden-start) · [Agent-Policy](#agent-policy) · [Handoff](#ide-handoff) · [Resume](#resume) · [Doku](#dokumentation) · [English](README.md)

Multi-Lens-Code-Audit, ausgelegt auf die **Cursor IDE**. Dieser Fork führt Spezial-Lenses gegen ein Git-Repo aus und schreibt Findings als lokales Markdown — gesteuert über Composer/Agent und das IDE-Handoff-Protokoll (`REPOLENS_CTL`).

> [!IMPORTANT]
> RepoLens gibt KI-Agenten Shell-Zugriff auf dein Projekt. Ein voller Audit kann viel Zeit (und mit bezahlten CLIs Geld) kosten. **In diesem Fork immer `--local` nutzen.** Vor dem ersten Lauf die [Warnungen](#warnungen) lesen.

## 30-Sekunden-Start

```bash
git clone https://github.com/benjarogit/RepoLens-Cursor-Edition.git
cd RepoLens-Cursor-Edition
chmod +x repolens.sh

export REPOLENS_IDE_AUTONOMOUS=1
./repolens.sh \
  --project /pfad/zum/projekt \
  --agent cursor-ide \
  --local \
  --domain security \
  --yes
```

Cursor-Chat in diesem Workspace offen lassen. Bei `REPOLENS_CTL {…}` im Terminal: Agent liest `files.prompt`, schreibt `files.response`, `touch` auf `files.done`.

## Agent-Policy

| Nutzen | Nicht nutzen (ohne explizite Ausnahme) |
|--------|----------------------------------------|
| `--agent cursor-ide --local` | `claude`, `codex`, `opencode`, `antigravity`, `cursor` (CLI) |

Mitgelieferte Rules:

- [`.cursor/rules/repolens-agent-cursor-ide-only.mdc`](.cursor/rules/repolens-agent-cursor-ide-only.mdc)
- [`.cursor/rules/repolens-ide-handoff.mdc`](.cursor/rules/repolens-ide-handoff.mdc)
- Skill: [`.cursor/skills/audit-pipeline/SKILL.md`](.cursor/skills/audit-pipeline/SKILL.md) (Struktur-Audit → RepoLens)

## IDE-Handoff

1. RepoLens schreibt `ide-prompt-iter-N.md` unter `logs/<run-id>/…`
2. Agent führt die Lens aus und speichert die volle Antwort in `ide-response-iter-N.txt` (≥ ~400 Bytes, keine Stubs)
3. Agent erzeugt `ide-done-iter-N` (`touch`)
4. Skript macht mit der nächsten Lens / Iteration weiter

Maschinenprotokoll: stderr-Zeilen `REPOLENS_CTL {…json…}` und Append in `logs/<run-id>/repolens-ctl.ndjson` (`kind: "ide_handoff"`). Details: [docs/de/handoff.md](docs/de/handoff.md).

## Resume

Unterbrochene oder rate-limitierte Läufe:

```bash
./repolens.sh --resume <run-id> --project /pfad/zum/projekt --agent cursor-ide --local --yes
# oder automatisch den letzten unterbrochenen Run:
./repolens.sh --resume --project /pfad/zum/projekt --agent cursor-ide --local --yes
```

Hilfsskripte: `repolens_until_done.sh`, `repolens_agent_or_ide.sh`.

## Dokumentation

| Doc | Inhalt |
|-----|--------|
| [README.md](README.md) | English landing page |
| [docs/de/handoff.md](docs/de/handoff.md) | IDE-Handoff-Protokoll |
| [docs/en/handoff.md](docs/en/handoff.md) | Handoff (English) |
| [docs/de/operator.md](docs/de/operator.md) | Operator-Hinweise (Resume, Quota, Triage) |
| [docs/en/operator.md](docs/en/operator.md) | Operator notes |
| [UPSTREAM.md](UPSTREAM.md) | Sync mit TheMorpheus407/RepoLens |
| [docs/en/full-reference.md](docs/en/full-reference.md) | Volle CLI-/Modes-/Domains-Referenz |
| [METHODOLOGY.md](METHODOLOGY.md) | Methodik |

## Upstream

Upstream: [TheMorpheus407/RepoLens](https://github.com/TheMorpheus407/RepoLens).  
Pin: [`UPSTREAM_REVISION`](UPSTREAM_REVISION). Sync: [`UPSTREAM.md`](UPSTREAM.md).

Diese Edition hält Cursor-IDE-Handoff und Local-First fest; Upstream-Features (Ledger, Triage, Resume, Perf-Schätzungen, …) werden regelmäßig gemerged.

## Warnungen

- **Nicht sandboxed** — Agenten können Shell-Befehle im Projekt ausführen
- **Kosten / Zeit** — zuerst `--domain security` oder `--focus <lens>`; volles `--mode audit` ist lang
- **Keine Gewähr** — Apache-2.0; Nutzung der Findings liegt bei dir

## Lizenz

Apache-2.0 — siehe [LICENSE](LICENSE). Upstream-Copyright Bootstrap Academy / TheMorpheus407; Cursor-Edition-Erweiterungen unter denselben Bedingungen, soweit anwendbar.
