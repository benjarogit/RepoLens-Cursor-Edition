# RepoLens Cursor Edition

[![License: Apache-2.0](https://img.shields.io/badge/License-Apache_2.0-blue.svg)](LICENSE)
[![Upstream](https://img.shields.io/badge/upstream-TheMorpheus407%2FRepoLens-informational)](https://github.com/TheMorpheus407/RepoLens)
[![Fork](https://img.shields.io/badge/fork-Cursor%20Edition-blue)](https://github.com/benjarogit/RepoLens-Cursor-Edition)

**Navigation:** [Start](#30-second-start) · [Agent policy](#agent-policy) · [Handoff](#ide-handoff) · [Resume](#resume) · [Docs](#documentation) · [Deutsch](README.de.md)

Multi-lens code audit tool, tailored for **Cursor IDE**. This fork runs specialist lenses against a git repo and writes findings as local markdown — driven by Composer/Agent via an IDE handoff protocol (`REPOLENS_CTL`).

> [!IMPORTANT]
> RepoLens gives AI agents shell access to your project. A full audit can cost a lot of time and (with paid CLIs) money. **Always use `--local` on this fork.** Read [Warnings](#warnings) before the first run.

## 30-second start

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

Open the Cursor chat in this workspace. When the terminal prints `REPOLENS_CTL {…}`, the agent reads `files.prompt`, writes `files.response`, and `touch`es `files.done`.

## Agent policy

| Use | Do not use (without explicit exception) |
|-----|----------------------------------------|
| `--agent cursor-ide --local` | `claude`, `codex`, `opencode`, `antigravity`, `cursor` (CLI) |

Rules shipped in the repo:

- [`.cursor/rules/repolens-agent-cursor-ide-only.mdc`](.cursor/rules/repolens-agent-cursor-ide-only.mdc)
- [`.cursor/rules/repolens-ide-handoff.mdc`](.cursor/rules/repolens-ide-handoff.mdc)
- Skill: [`.cursor/skills/audit-pipeline/SKILL.md`](.cursor/skills/audit-pipeline/SKILL.md) (Struktur-Audit → RepoLens)

## IDE handoff

1. RepoLens writes `ide-prompt-iter-N.md` under `logs/<run-id>/…`
2. Agent runs the lens and saves the full reply to `ide-response-iter-N.txt` (≥ ~400 bytes, no stubs)
3. Agent creates `ide-done-iter-N` (`touch`)
4. Script continues to the next lens / iteration

Machine protocol: stderr lines `REPOLENS_CTL {…json…}` and append to `logs/<run-id>/repolens-ctl.ndjson` (`kind: "ide_handoff"`). Details: [docs/en/handoff.md](docs/en/handoff.md).

## Resume

Interrupted or rate-limited runs:

```bash
./repolens.sh --resume <run-id> --project /path/to/your/repo --agent cursor-ide --local --yes
# or auto-pick latest interrupted run:
./repolens.sh --resume --project /path/to/your/repo --agent cursor-ide --local --yes
```

Wrappers: `repolens_until_done.sh`, `repolens_agent_or_ide.sh`.

## Documentation

| Doc | Content |
|-----|---------|
| [README.de.md](README.de.md) | German landing page |
| [docs/en/handoff.md](docs/en/handoff.md) | IDE handoff protocol |
| [docs/de/handoff.md](docs/de/handoff.md) | Handoff (Deutsch) |
| [docs/en/operator.md](docs/en/operator.md) | Operator notes (resume, quota, triage) |
| [docs/de/operator.md](docs/de/operator.md) | Operator (Deutsch) |
| [UPSTREAM.md](UPSTREAM.md) | Sync with TheMorpheus407/RepoLens |
| [docs/en/full-reference.md](docs/en/full-reference.md) | Full CLI / modes / domains reference |
| [METHODOLOGY.md](METHODOLOGY.md) | Methodology |

## Upstream

Upstream project: [TheMorpheus407/RepoLens](https://github.com/TheMorpheus407/RepoLens).  
Pinned revision: [`UPSTREAM_REVISION`](UPSTREAM_REVISION). Sync process: [`UPSTREAM.md`](UPSTREAM.md).

This edition keeps Cursor IDE handoff, local-first defaults, and optional Cursor CLI support; upstream features (ledger, triage, resume, perf estimates, …) are merged regularly.

## Warnings

- **Not sandboxed** — agents can run shell commands in the project
- **Cost / time** — prefer `--domain security` or `--focus <lens>` first; full `--mode audit` is long
- **No warranty** — Apache-2.0; you are responsible for how you use findings

## License

Apache-2.0 — see [LICENSE](LICENSE). Upstream copyright Bootstrap Academy / TheMorpheus407; Cursor Edition additions under the same license terms where applicable.
