# IDE handoff

<p align="right">
  <strong>English</strong> · <a href="../de/handoff.md">Deutsch</a>
  · <a href="../README.md">Docs index</a>
  · <a href="../../README.md">README</a>
</p>

With `--agent cursor-ide`, RepoLens does **not** call Claude, Codex, or `cursor-agent`.  
It writes a prompt file and waits until the **Cursor chat** answers through files.

## In one sentence

**Read the prompt → write the answer → mark done** — repeat until the run finishes.

## Step by step

```
repolens.sh  →  writes prompt  →  prints REPOLENS_CTL
     ↑                                    ↓
  touch done  ←  you or the agent write the response
```

1. Watch the terminal (or `logs/<run-id>/repolens-ctl.ndjson`) for `REPOLENS_CTL` with `"kind":"ide_handoff"`.
2. Open `files.prompt` from that JSON.
3. Run the lens in chat (inspect the **target** project).
4. Save the **full** answer to `files.response` (at least ~400 bytes; no empty stubs).
5. Create `files.done` with `touch`.

RepoLens then continues with the next iteration or lens.

## Good answers look like

- Real findings, or a clear `DONE` if there is nothing to report
- Per finding: **path**, **severity**, one-line **risk**, **fix**
- No filler (“automatic run”, empty placeholders)

Demo-only stubs: `REPOLENS_IDE_ALLOW_STUB=1` (not for real audits).

## Useful environment variables

| Variable | Meaning |
|----------|---------|
| `REPOLENS_IDE_AUTONOMOUS=1` | Marks handoffs for an autonomous agent |
| `REPOLENS_IDE_FAIL_FAST=1` | Stops the lens on a bad or missing response (default) |
| `REPOLENS_CURSOR_IDE_POLL_SEC` | How often to check for `done` |
| `REPOLENS_CURSOR_IDE_MAX_WAIT_SEC` | Maximum wait per iteration |

## Stuck?

1. Check `logs/<run-id>/summary.json`.
2. Resume:

   ```bash
   ./repolens.sh --resume <run-id> \
     --project /path/to/repo \
     --agent cursor-ide --local --yes
   ```

See also: [Operator guide](operator.md) · [Cursor rules](../../.cursor/rules/repolens-ide-handoff.mdc)
