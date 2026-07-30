# IDE handoff

<p align="right">
  <strong>English</strong> · <a href="../de/handoff.md">Deutsch</a>
  · <a href="index.md">Docs index</a>
  · <a href="../../README.md">README</a>
</p>

With `--agent cursor-ide`, RepoLens does **not** call Claude, Codex, or `cursor-agent`.  
It writes a prompt file and waits until the **Cursor chat** answers through files.

## In one sentence

**Read the prompt → write the answer → publish hashed `complete.json`** — repeat until the run finishes.

## Step by step

```
repolens.sh  →  writes request.json + prompt.md  →  prints REPOLENS_CTL
     ↑                                                      ↓
  complete.json  ←  you write response.md + hashed marker
```

1. Watch the terminal (or `logs/<run-id>/repolens-ctl.ndjson`) for `REPOLENS_CTL` with `"kind":"ide_handoff"`.
2. Open `files.prompt` from that JSON. Every prompt ends with the handoff protocol, including the current position (`lens 7/42`) and the exact finalize commands.
3. Run the lens in chat (inspect the **target** project).
4. Save the **full** answer to `files.response` (at least ~400 bytes; no empty stubs).
5. Publish `files.complete` atomically: `complete.json` must carry this request's `request_id` and the `git hash-object` digest of `response.md`. Do **not** use `touch done`.

RepoLens then validates a private snapshot of both files and continues with the next iteration or lens. On reject it removes only `complete.json` so you can fix the response and republish.

Layout per request:

```text
logs/<run-id>/<domain>/<lens>/cursor-ide/lens/<request-id>/
  request.json  prompt.md  response.md  complete.json
```

## Running a full audit in one chat

A full audit is a long queue of handoffs, and the chat is supposed to serve all of them. Two fields keep that manageable:

- Every `ide_handoff` carries `lens_index`, `lens_total`, and `last_lens`, so the agent knows where it stands.
- The run ends with `"kind":"run_complete"` (`next_action: plan_mode`) — until that arrives, more handoffs are coming.

The discipline that keeps a long run inside the context budget:

- **One chat line per handoff**, e.g. `Lens 7/42 security/injection — 3 findings (1 high)`. The analysis belongs in the response file, not in the chat.
- **Never stop to ask.** Do not offer to shorten the run and do not declare it too large for the chat.
- **A lens that does not fit the project is not a reason to stop.** Answer `NOT APPLICABLE` with a reason and at least two real `path:line` anchors proving what was inspected, then publish `complete.json`.
- **On error**, write the cause into the response file, say it in one line, and move on to the next handoff.

After `run_complete`, read the findings from `files.findings_dir` and `files.summary`, switch to Plan mode, and run **batch grilling** (frontier rounds): ask every currently answerable decision in one round, wait, recompute. **Option A is always the best-practice recommendation** (the usual, defensible route, not necessarily the theoretically best one). Cap ~8 questions per round; dependent decisions wait for the next round.

## Good answers look like

- Real findings, or a clear `DONE` if there is nothing to report
- Per finding: **path**, **severity**, one-line **risk**, **fix**
- **Method** + **Findings** sections
- At least two concrete `path:line` anchors that exist in the repo (e.g. `core/env-file.sh:39`); citations through symlinks or past EOF do not count
- No filler, byte-padding (`# continuity` / `# pad`), or automation/grep-worker templates

RepoLens rejects shallow or templated replies (`IDE_RESPONSE_REJECTED`) and repeats the same iteration. The error carries a `reason` field naming the failing check (`reply is 315 bytes, needs at least 400`, `missing a '## Findings' section`, …) — fix exactly that, rewrite the response file, and republish `complete.json`. `DONE` without new findings still needs ≥3 verified anchors. Demo-only stubs: `REPOLENS_IDE_ALLOW_STUB=1` (not for real audits).

## Useful environment variables

| Variable | Meaning |
|----------|---------|
| `REPOLENS_IDE_AUTONOMOUS=1` | Marks handoffs for an autonomous agent |
| `REPOLENS_IDE_FAIL_FAST=1` | Stops the lens on a bad or missing response (default) |
| `REPOLENS_IDE_MIN_RESPONSE_BYTES` | Min size after stripping padding (default 400); path anchors required |
| `REPOLENS_CURSOR_IDE_POLL_SEC` | How often to check for `complete.json` |
| `REPOLENS_CURSOR_IDE_MAX_WAIT_SEC` | Maximum wait per iteration |

`REPOLENS_IDE_*` aliases map onto `REPOLENS_CURSOR_IDE_*` where applicable; Edition defaults win.

## Stuck?

1. Check `logs/<run-id>/summary.json`.
2. Resume:

   ```bash
   ./repolens.sh --resume <run-id> \
     --project /path/to/repo \
     --agent cursor-ide --local --yes
   ```

Resume issues a new `request_id`; an old `complete.json` cannot finish the new request.

See also: [Cursor IDE protocol](../cursor-ide.md) · [Operator guide](operator.md) · [Cursor rules](https://github.com/benjarogit/RepoLens-Cursor-Edition/blob/master/.cursor/rules/repolens-ide-handoff.mdc)
