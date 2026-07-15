# Documentation

<p align="right">
  <strong>English</strong> · <a href="de/README.md">Deutsch</a>
  · <a href="../README.md">README</a>
</p>

## Read in this order

1. **[README](../README.md)** — what this fork is, 30-second start
2. **[Operator guide](en/operator.md)** — first runs, findings, resume, useful domains
3. **[IDE handoff](en/handoff.md)** — how Cursor fills in each lens (prompt → response → done)

## When you need more

| Doc | Use when |
|-----|----------|
| [CLI & modes reference](en/full-reference.md) | Flags, modes, long upstream-style reference |
| [Finding registry schema](finding-registry-schema.md) | `findings.jsonl` / CSV shape |
| [Upstream sync](../UPSTREAM.md) | Merging TheMorpheus407/RepoLens into this fork |
| [Changelog](../CHANGELOG.md) | What changed in Cursor Edition / upstream |
| [Methodology](../METHODOLOGY.md) | How lenses are designed (advanced) |
| [Contributing](../CONTRIBUTING.md) | Adding lenses / PRs |

## Cursor files in this repo

| Path | Role |
|------|------|
| [`.cursor/rules/`](../.cursor/rules/) | Always-on agent policy + handoff |
| [`.cursor/skills/audit-pipeline/`](../.cursor/skills/audit-pipeline/) | Struktur-Audit → RepoLens from chat |

## One command to remember

```bash
export REPOLENS_IDE_AUTONOMOUS=1
./repolens.sh --project /path/to/repo --agent cursor-ide --local --domain security --yes
```
