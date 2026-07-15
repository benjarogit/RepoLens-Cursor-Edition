<p align="center">
  <picture>
    <source media="(prefers-color-scheme: dark)" srcset="docs/assets/logo-dark.png" />
    <img src="docs/assets/logo-light.png" alt="RepoLens Cursor Edition" width="88" height="88" />
  </picture>
</p>

<h1 align="center">RepoLens</h1>

<p align="center">
  <strong>Cursor Edition</strong><br/>
  Multi-Lens-Audits in der <strong><a href="https://cursor.com/referral?code=UW6WJZLB8ECL">Cursor</a>-IDE</strong> — Findings als lokale Dateien, ohne separate Agent-CLI.
</p>

<p align="center">
  <a href="LICENSE"><img src="https://img.shields.io/badge/License-Apache_2.0-blue.svg" alt="Lizenz" /></a>
  <a href="https://github.com/benjarogit/RepoLens-Cursor-Edition/releases/latest"><img src="https://img.shields.io/github/v/release/benjarogit/RepoLens-Cursor-Edition?label=release" alt="Latest Release" /></a>
  <a href="https://github.com/TheMorpheus407/RepoLens"><img src="https://img.shields.io/badge/upstream-RepoLens-informational" alt="Upstream" /></a>
  <a href="UPSTREAM_REVISION"><img src="https://img.shields.io/badge/sync-tracked-brightgreen" alt="Upstream-Sync" /></a>
  <a href="https://cursor.com/referral?code=UW6WJZLB8ECL"><img src="https://img.shields.io/badge/Cursor-starten-black" alt="Cursor starten" /></a>
</p>

<!-- README-I18N:START -->
<p align="center">
  <a href="README.md">English</a> · <strong>Deutsch</strong>
</p>
<!-- README-I18N:END -->

---

## Was das ist

Fork von [TheMorpheus407/RepoLens](https://github.com/TheMorpheus407/RepoLens), ausgelegt auf **[Cursor](https://cursor.com/referral?code=UW6WJZLB8ECL) Composer/Agent**. Jede *Lens* ist ein gezielter Prüfdurchlauf; zusammen decken sie Security, Qualität und mehr ab.

| | |
|---|---|
| **Agent** | `--agent cursor-ide` (empfohlen) |
| **Output** | Markdown unter `logs/<run-id>/` (`--local`) |
| **Schleife** | IDE-Handoff über `REPOLENS_CTL` → Prompt → Antwort → Done |

Upstream unterstützt weiterhin Claude, Codex und ähnliche Backends. Diese Edition nutzt sie nicht als Standard.

> [!IMPORTANT]
> Agenten können Shell-Befehle in deinem Projekt ausführen. Starte mit einer Domain (z. B. `--domain security`), bevor du einen vollen Audit startest. Immer `--local` setzen.

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

Brauchst du noch [Cursor](https://cursor.com/referral?code=UW6WJZLB8ECL)? Zuerst installieren, dann den Chat auf diesem Repo offen lassen. Wenn das Terminal `REPOLENS_CTL` ausgibt:

1. `files.prompt` lesen
2. die volle Antwort nach `files.response` schreiben
3. `files.done` mit `touch` anlegen

Details: [docs/de/handoff.md](docs/de/handoff.md)

## Zusammenspiel

```
repolens.sh ──► ide-prompt ──► Cursor Agent ──► ide-response ──► touch done
                    ▲                                    │
                    └──────── REPOLENS_CTL (stderr) ─────┘
```

Mitgelieferte Cursor-Hilfen:

- [`.cursor/rules/repolens-agent-cursor-ide-only.mdc`](.cursor/rules/repolens-agent-cursor-ide-only.mdc) — welcher Agent
- [`.cursor/rules/repolens-ide-handoff.mdc`](.cursor/rules/repolens-ide-handoff.mdc) — Handoff-Ablauf
- [`.cursor/skills/audit-pipeline/SKILL.md`](.cursor/skills/audit-pipeline/SKILL.md) — Strukturprüfung, dann RepoLens

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
| [Docs-Index](docs/de/README.md) | Empfohlene Lesereihenfolge |
| [Operator-Guide](docs/de/operator.md) | Erste Läufe, Domains, Resume, Toolgate |
| [IDE-Handoff](docs/de/handoff.md) | Prompt → Antwort → Done |
| [CLI- & Modes-Referenz](docs/en/full-reference.md) | Längere Flag- und Mode-Referenz (EN) |
| [Upstream-Sync](UPSTREAM.md) | Merge von TheMorpheus407/RepoLens |
| [Changelog](CHANGELOG.md) | Cursor Edition und Upstream |
| [Methodik](METHODOLOGY.md) | Wie Lenses aufgebaut sind (EN) |

English: [docs/README.md](docs/README.md).

## Lizenz

[Apache-2.0](LICENSE). Upstream © Bootstrap Academy / TheMorpheus407; Cursor-Edition unter denselben Bedingungen, soweit anwendbar.
