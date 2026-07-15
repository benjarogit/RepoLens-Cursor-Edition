# Operator notes

<p align="right">
  <strong>English</strong> · <a href="../de/operator.md">Deutsch</a>
  · <a href="../../README.md">README</a>
</p>

## Recommended first runs

1. `--domain security` (or `--focus injection`) with `--local`
2. Review `logs/<run-id>/issues/`
3. Fix, then re-run the same domain
4. Scale to more domains only after a stable baseline

## After a run

| Artifact | Meaning |
|----------|---------|
| `logs/<run-id>/issues/` | Local markdown findings |
| `logs/<run-id>/summary.json` | Status, outcomes, timing |
| `logs/<run-id>/final/` | Registry / triage / human-review (when enabled) |
| `logs/<run-id>/attempts.json` | Resume / continuation history |

Useful flags: `--human-review`, `--resume`, `--yes`.

## Quota / capacity

Cursor usage limits may pause a lens. Prefer `--resume` on the same `run-id` instead of a new run. Optional CLI path (`--agent cursor`) has separate quota; this fork’s default path is `cursor-ide`.

## Audit pipeline

From Cursor chat with this repo open, use [`.cursor/skills/audit-pipeline/SKILL.md`](../../.cursor/skills/audit-pipeline/SKILL.md): structure audit first, then RepoLens.

## Vendor / dependency forks

Full multi-lens audits of interpreter or library mirrors (e.g. vendored `php-src`, `htmlpurifier`) are usually poor ROI. Prefer auditing the **application** that consumes them, or a narrow **delta vs upstream parent** when you maintain a patched fork.

See also: [Handoff protocol](handoff.md)
