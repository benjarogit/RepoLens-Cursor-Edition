# Operator-Hinweise

**Navigation:** [README.de](../../README.de.md) · [Handoff](handoff.md) · [English](../en/operator.md)

## Empfohlene erste Läufe

1. `--domain security` (oder `--focus injection`) mit `--local`
2. Findings unter `logs/<run-id>/issues/` prüfen
3. Fixes, dann dieselbe Domain erneut
4. Weitere Domains erst nach stabilem Baseline

## Nach dem Lauf

| Artefakt | Bedeutung |
|----------|-----------|
| `logs/<run-id>/issues/` | Lokale Markdown-Findings |
| `logs/<run-id>/summary.json` | Status, Outcomes, Timing |
| `logs/<run-id>/final/` | Registry / Triage / Human-Review (wenn aktiv) |
| `logs/<run-id>/attempts.json` | Resume-/Continuation-Historie |

Nützliche Flags: `--human-review`, `--resume`, `--yes`.

## Quota / Capacity

Cursor-Limits können eine Lens pausieren. Lieber denselben `run-id` mit `--resume` fortsetzen als einen neuen Run. Der optionale CLI-Pfad (`--agent cursor`) hat separates Kontingent; Default dieses Forks ist `cursor-ide`.

## Audit-Pipeline

Im Cursor-Chat mit diesem Repo: Skill [`.cursor/skills/audit-pipeline/SKILL.md`](../../.cursor/skills/audit-pipeline/SKILL.md) — zuerst Struktur-Audit, dann RepoLens.

## Vendor-/Dependency-Forks

Volle Multi-Lens-Audits von Interpreter- oder Library-Mirrors (z. B. vendored `php-src`, `htmlpurifier`) lohnen sich selten. Besser die **Anwendung** auditieren, die sie nutzt — oder schmal das **Delta zum Upstream-Parent**, wenn ihr einen Patch-Fork pflegt.
