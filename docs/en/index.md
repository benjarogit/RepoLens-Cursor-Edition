# Documentation

Welcome to **RepoLens Cursor Edition** docs. Use the sidebar for navigation; switch language in the header.

## Read in this order

1. **[Operator guide](operator.md)** — first runs, findings, resume, useful domains  
2. **[IDE handoff](handoff.md)** — how Cursor completes each lens (prompt → response → done)  
3. **[Toolgate tools](toolgate-tools.md)** — which real scanners/linters may run  

## Reference

| Doc | Use when |
|-----|----------|
| [CLI & modes](full-reference.md) | Flags, modes, longer upstream-style reference |
| [Finding registry](finding-registry-schema.md) | Shape of `findings.jsonl` / CSV |

## Project

| Doc | Use when |
|-----|----------|
| [Upstream sync](https://github.com/benjarogit/RepoLens-Cursor-Edition/blob/master/UPSTREAM.md) | Merging TheMorpheus407/RepoLens into this fork |
| [Changelog](https://github.com/benjarogit/RepoLens-Cursor-Edition/blob/master/CHANGELOG.md) | What changed in Cursor Edition / upstream |
| [Methodology](https://github.com/benjarogit/RepoLens-Cursor-Edition/blob/master/METHODOLOGY.md) | How lenses are designed (advanced) |
| [Contributing](https://github.com/benjarogit/RepoLens-Cursor-Edition/blob/master/CONTRIBUTING.md) | Adding lenses / pull requests |

## Cursor files in this repo

| Path | Role |
|------|------|
| [`.cursor/rules/`](https://github.com/benjarogit/RepoLens-Cursor-Edition/tree/master/.cursor/rules) | Agent policy and handoff instructions |
| [`.cursor/skills/audit-pipeline/`](https://github.com/benjarogit/RepoLens-Cursor-Edition/tree/master/.cursor/skills/audit-pipeline) | Structure review, then RepoLens from chat |

## One command to remember

```bash
export REPOLENS_IDE_AUTONOMOUS=1
./repolens.sh --project /path/to/repo --agent cursor-ide --local --domain security --yes
```

Repository README: [English](https://github.com/benjarogit/RepoLens-Cursor-Edition/blob/master/README.md) · [Deutsch](https://github.com/benjarogit/RepoLens-Cursor-Edition/blob/master/README.de.md)
