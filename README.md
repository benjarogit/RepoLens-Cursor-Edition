<p align="center">
  <strong>RepoLens</strong><br/>
  <sub>Cursor Edition</sub>
</p>

<p align="center">
  Multi-lens code audits inside <strong>Cursor IDE</strong> — local findings, no external agent CLI.
</p>

<p align="center">
  <a href="LICENSE"><img src="https://img.shields.io/badge/License-Apache_2.0-blue.svg" alt="License" /></a>
  <a href="https://github.com/benjarogit/RepoLens-Cursor-Edition/releases/latest"><img src="https://img.shields.io/github/v/release/benjarogit/RepoLens-Cursor-Edition?label=release" alt="Latest release" /></a>
  <a href="https://github.com/TheMorpheus407/RepoLens"><img src="https://img.shields.io/badge/upstream-RepoLens-informational" alt="Upstream" /></a>
  <a href="UPSTREAM_REVISION"><img src="https://img.shields.io/badge/sync-tracked-brightgreen" alt="Upstream sync" /></a>
</p>

<!-- README-I18N:START -->
<p align="center">
  <strong>English</strong> · <a href="README.de.md">Deutsch</a>
</p>
<!-- README-I18N:END -->

---

## What this is

A fork of [TheMorpheus407/RepoLens](https://github.com/TheMorpheus407/RepoLens) wired for **Cursor Composer/Agent**:

| | |
|---|---|
| **Agent** | `--agent cursor-ide` only (recommended path) |
| **Output** | Markdown under `logs/<run-id>/` (`--local`) |
| **Loop** | IDE handoff via `REPOLENS_CTL` → prompt → response → done |

Upstream still supports Claude, Codex, and others. This edition does not use those by default.

> [!IMPORTANT]
> Agents get shell access to your project. Prefer a single domain (`--domain security`) before a full audit. Always pass `--local`.

## Quick start

```bash
git clone https://github.com/benjarogit/RepoLens-Cursor-Edition.git
cd RepoLens-Cursor-Edition
chmod +x repolens.sh

export REPOLENS_IDE_AUTONOMOUS=1
./repolens.sh \
  --project /path/to/your/repo \
  --agent cursor-ide \
  --local \
  --domain security \
  --yes
```

Keep the Cursor chat on this repo open. When the terminal emits `REPOLENS_CTL`, the agent:

1. reads `files.prompt`
2. writes the full answer to `files.response`
3. `touch`es `files.done`

Details: [docs/en/handoff.md](docs/en/handoff.md)

## How it fits together

```
repolens.sh ──► ide-prompt ──► Cursor Agent ──► ide-response ──► touch done
                    ▲                                    │
                    └──────── REPOLENS_CTL (stderr) ─────┘
```

Shipped Cursor guidance:

- [`.cursor/rules/repolens-agent-cursor-ide-only.mdc`](.cursor/rules/repolens-agent-cursor-ide-only.mdc) — agent policy
- [`.cursor/rules/repolens-ide-handoff.mdc`](.cursor/rules/repolens-ide-handoff.mdc) — handoff loop
- [`.cursor/skills/audit-pipeline/SKILL.md`](.cursor/skills/audit-pipeline/SKILL.md) — structure audit → RepoLens

## Resume

```bash
./repolens.sh --resume <run-id> \
  --project /path/to/your/repo \
  --agent cursor-ide --local --yes

# latest interrupted run:
./repolens.sh --resume \
  --project /path/to/your/repo \
  --agent cursor-ide --local --yes
```

Helpers: `repolens_until_done.sh`, `repolens_agent_or_ide.sh`

## Docs

| | |
|---|---|
| [Handoff protocol](docs/en/handoff.md) | File contract & env vars |
| [Operator notes](docs/en/operator.md) | First runs, quota, triage |
| [CLI reference](docs/en/full-reference.md) | Modes, flags, domains |
| [Upstream sync](UPSTREAM.md) | Merging TheMorpheus407/RepoLens |
| [Changelog](CHANGELOG.md) | Cursor Edition + upstream history |
| [Methodology](METHODOLOGY.md) | How lenses are designed |

German copies of handoff/operator live under [`docs/de/`](docs/de/).

## License

[Apache-2.0](LICENSE). Upstream © Bootstrap Academy / TheMorpheus407; Cursor Edition changes under the same terms where applicable.
