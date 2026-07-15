# Operator guide

<p align="right">
  <strong>English</strong> · <a href="../de/operator.md">Deutsch</a>
  · <a href="../README.md">Docs index</a>
  · <a href="../../README.md">README</a>
</p>

Practical notes for running **RepoLens Cursor Edition**.  
Default path: `--agent cursor-ide --local`.

## First run (keep it small)

1. Start with one domain, e.g. security:

   ```bash
   export REPOLENS_IDE_AUTONOMOUS=1
   ./repolens.sh \
     --project /path/to/your/repo \
     --agent cursor-ide \
     --local \
     --domain security \
     --yes
   ```

2. Leave the Cursor chat open on **this** RepoLens repo so handoffs can complete ([handoff](handoff.md)).
3. Open findings under `logs/<run-id>/issues/`.
4. Fix issues in the **target** repo, then re-run the same domain.
5. Only then add more domains or a full `--mode audit` (long and heavy).

## Useful domains

| Domain | Good for |
|--------|----------|
| `security` | Auth, injection, secrets, common app risks |
| `toolgate` | Run real linters/SAST if installed (Biome, PHPStan, ruff, …) |
| `architecture` | Boundaries, coupling, structure |
| `code-quality` | Complexity, smells, consistency |
| `llm-security` | Prompt injection / agent tool risks |
| `devops` / `iac` | CI and infrastructure-as-code |

Single lens: `--domain security --focus injection` (example).

## Where results live

| Path | What it is |
|------|------------|
| `logs/<run-id>/issues/` | Markdown findings (main output in `--local`) |
| `logs/<run-id>/summary.json` | Status, outcomes, timing |
| `logs/<run-id>/final/` | Machine index / triage when produced (`findings.jsonl`, optional human-review) |
| `logs/<run-id>/attempts.json` | History if the run was resumed |

Handy flags: `--yes`, `--human-review`, `--resume`.

## If a run stops

Cursor quota or a failed handoff can pause a lens. **Resume the same run** — do not invent a new id unless you mean to start over:

```bash
./repolens.sh --resume <run-id> \
  --project /path/to/your/repo \
  --agent cursor-ide --local --yes

# or auto-pick the latest interrupted run:
./repolens.sh --resume \
  --project /path/to/your/repo \
  --agent cursor-ide --local --yes
```

Helpers: `repolens_until_done.sh`, `repolens_agent_or_ide.sh`.

## Toolgate (real scanners)

`toolgate` lenses try to **run tools on your machine** (ESLint/Biome, PHPCS, PHPStan/Psalm, ruff, …).  
If a tool is missing, you usually get a `[SETUP]` finding instead of silent success.

```bash
./repolens.sh ... --domain toolgate --yes
# or: --domain toolgate --focus lint
```

## What not to audit by default

Full multi-lens runs against **vendored library/interpreter mirrors** (e.g. `php-src`, random dependency forks) are usually poor ROI. Prefer the **application** that uses them, or a narrow diff against the upstream parent.

## More detail

- [IDE handoff](handoff.md)
- [CLI & modes reference](full-reference.md)
- [Audit-pipeline skill](../../.cursor/skills/audit-pipeline/SKILL.md)
