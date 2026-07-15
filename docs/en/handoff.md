# IDE handoff protocol

<p align="right">
  <strong>English</strong> · <a href="../de/handoff.md">Deutsch</a>
  · <a href="../../README.md">README</a>
</p>

When `--agent cursor-ide` is set, RepoLens does not spawn an external agent CLI. It waits for the Cursor chat agent to finish each lens iteration via files.

## Flow

```
repolens.sh  →  writes prompt  →  REPOLENS_CTL (stderr + ndjson)
     ↑                                      ↓
  touch done  ←  agent writes response  ←  Cursor Agent
```

1. Read CTL event: stderr `REPOLENS_CTL {…}` or `logs/<run-id>/repolens-ctl.ndjson` (`kind: ide_handoff`)
2. Open `files.prompt`
3. Run the lens in chat (project context)
4. Write the full answer to `files.response` (≥ `REPOLENS_IDE_MIN_RESPONSE_BYTES`, default 400)
5. `touch files.done`

## Quality

- Real findings or `DONE` — no stub boilerplate
- Per finding: path, severity, one-line exploit, fix
- Demo-only stubs: `REPOLENS_IDE_ALLOW_STUB=1`

## Useful env

| Variable | Role |
|----------|------|
| `REPOLENS_IDE_AUTONOMOUS=1` | Mark handoffs for autonomous agents |
| `REPOLENS_IDE_FAIL_FAST=1` | Stop lens on rejected/missing response (default) |
| `REPOLENS_CURSOR_IDE_POLL_SEC` | Poll interval while waiting |
| `REPOLENS_CURSOR_IDE_MAX_WAIT_SEC` | Max wait per iteration |

## Stall / resume

Check `logs/<run-id>/summary.json`, then:

```bash
./repolens.sh --resume <run-id> --project <path> --agent cursor-ide --local --yes
```

See also: [Operator notes](operator.md)
