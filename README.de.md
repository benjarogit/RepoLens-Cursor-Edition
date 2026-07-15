<p align="center">
  <picture>
    <source media="(prefers-color-scheme: dark)" srcset="docs/assets/logo-dark.png" />
    <img src="docs/assets/logo-light.png" alt="RepoLens Cursor Edition" width="88" height="88" />
  </picture>
</p>

<h1 align="center">RepoLens</h1>

<p align="center">
  <strong>Cursor Edition</strong><br/>
  Multi-Lens-Audits in der <strong>Cursor IDE</strong> — lokale Findings, ohne fremde Agent-CLIs.
</p>

<p align="center">
  <a href="LICENSE"><img src="https://img.shields.io/badge/License-Apache_2.0-blue.svg" alt="Lizenz" /></a>
  <a href="https://github.com/benjarogit/RepoLens-Cursor-Edition/releases/latest"><img src="https://img.shields.io/github/v/release/benjarogit/RepoLens-Cursor-Edition?label=release" alt="Latest Release" /></a>
  <a href="https://github.com/TheMorpheus407/RepoLens"><img src="https://img.shields.io/badge/upstream-RepoLens-informational" alt="Upstream" /></a>
  <a href="UPSTREAM_REVISION"><img src="https://img.shields.io/badge/sync-tracked-brightgreen" alt="Upstream-Sync" /></a>
</p>

<!-- README-I18N:START -->
<p align="center">
  <a href="README.md">English</a> · <strong>Deutsch</strong>
</p>
<!-- README-I18N:END -->

---

## Was das ist

Fork von [TheMorpheus407/RepoLens](https://github.com/TheMorpheus407/RepoLens), verdrahtet für **Cursor Composer/Agent**:

| | |
|---|---|
| **Agent** | nur `--agent cursor-ide` (vorgesehener Pfad) |
| **Output** | Markdown unter `logs/<run-id>/` (`--local`) |
| **Schleife** | IDE-Handoff über `REPOLENS_CTL` → Prompt → Antwort → Done |

Upstream kennt weiterhin Claude, Codex & Co. Diese Edition nutzt die nicht als Default.

> [!IMPORTANT]
> Agenten bekommen Shell-Zugriff auf dein Projekt. Zuerst eine Domain (`--domain security`), nicht gleich den vollen Audit. Immer `--local`.

## Schnellstart

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

Cursor-Chat auf diesem Repo offen lassen. Bei `REPOLENS_CTL` im Terminal:

1. `files.prompt` lesen
2. volle Antwort nach `files.response` schreiben
3. `files.done` per `touch` setzen

Details: [docs/de/handoff.md](docs/de/handoff.md)

## Zusammenspiel

```
repolens.sh ──► ide-prompt ──► Cursor Agent ──► ide-response ──► touch done
                    ▲                                    │
                    └──────── REPOLENS_CTL (stderr) ─────┘
```

Mitgelieferte Cursor-Hilfen:

- [`.cursor/rules/repolens-agent-cursor-ide-only.mdc`](.cursor/rules/repolens-agent-cursor-ide-only.mdc) — Agent-Policy
- [`.cursor/rules/repolens-ide-handoff.mdc`](.cursor/rules/repolens-ide-handoff.mdc) — Handoff-Schleife
- [`.cursor/skills/audit-pipeline/SKILL.md`](.cursor/skills/audit-pipeline/SKILL.md) — Struktur-Audit → RepoLens

## Resume

```bash
./repolens.sh --resume <run-id> \
  --project /pfad/zum/projekt \
  --agent cursor-ide --local --yes

# letzter unterbrochener Run:
./repolens.sh --resume \
  --project /pfad/zum/projekt \
  --agent cursor-ide --local --yes
```

Hilfsskripte: `repolens_until_done.sh`, `repolens_agent_or_ide.sh`

## Dokumentation

| | |
|---|---|
| [Handoff-Protokoll](docs/de/handoff.md) | Dateivertrag & Env-Vars |
| [Operator-Hinweise](docs/de/operator.md) | Erste Läufe, Quota, Triage |
| [CLI-Referenz](docs/en/full-reference.md) | Modes, Flags, Domains (EN) |
| [Upstream-Sync](UPSTREAM.md) | Merge von TheMorpheus407/RepoLens |
| [Changelog](CHANGELOG.md) | Cursor Edition + Upstream-Historie |
| [Methodik](METHODOLOGY.md) | Lens-Design |

Englische Varianten unter [`docs/en/`](docs/en/).

## Lizenz

[Apache-2.0](LICENSE). Upstream © Bootstrap Academy / TheMorpheus407; Cursor-Edition unter denselben Bedingungen, soweit anwendbar.
