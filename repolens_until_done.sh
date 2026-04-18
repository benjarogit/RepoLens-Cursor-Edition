#!/usr/bin/env bash
# Copyright 2025-2026 Bootstrap Academy (upstream RepoLens).
#
# Run RepoLens to completion across Cursor CLI quota windows: call repolens.sh,
# then --resume the same RUN_ID after sleeps when rate-limited or when lenses
# remain incomplete (rate-limited / skipped / transient agent statuses).
#
# Usage: repolens_until_done.sh [same args as repolens.sh]
# Optional leading --resume <run-id> to continue an existing run.
#
# Environment:
#   REPOLENS_UNTIL_DONE_SLEEP_SEC   Pause between waves (default: 120)
#   REPOLENS_UNTIL_DONE_MAX_LOOPS    Safety cap (default: 2000)
#   REPOLENS_RUN_ID_FILE            Passed through to repolens.sh (set internally)
#
# csretro wrapper (auto-resume loop): Copyright 2025-2026 benjarogit / Sunny C.

set -uo pipefail

if (( BASH_VERSINFO[0] < 4 )); then
  echo "repolens_until_done.sh requires bash 4.0 or newer" >&2
  exit 1
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPOLENS_BIN="$SCRIPT_DIR/repolens.sh"

MAX_LOOPS="${REPOLENS_UNTIL_DONE_MAX_LOOPS:-2000}"
SLEEP_SEC="${REPOLENS_UNTIL_DONE_SLEEP_SEC:-120}"

resume_shell=()
forward=()
while [[ $# -gt 0 ]]; do
  case "$1" in
    --resume)
      [[ -n "${2:-}" ]] || {
        echo "repolens_until_done: --resume requires a run id" >&2
        exit 2
      }
      resume_shell=(--resume "$2")
      shift 2
      ;;
    *)
      forward+=("$1")
      shift
      ;;
  esac
done

RUN_ID_FILE="$(mktemp)"
trap 'rm -f "$RUN_ID_FILE"' EXIT

loop=0
while (( loop < MAX_LOOPS )); do
  loop=$((loop + 1))
  export REPOLENS_RUN_ID_FILE="$RUN_ID_FILE"
  set +e
  bash "$REPOLENS_BIN" "${resume_shell[@]}" "${forward[@]}"
  rc=$?
  set -e

  run_id=""
  [[ -s "$RUN_ID_FILE" ]] && run_id="$(head -1 "$RUN_ID_FILE")"
  sum=""
  [[ -n "$run_id" ]] && sum="$SCRIPT_DIR/logs/$run_id/summary.json"

  if [[ "$rc" -eq 0 ]]; then
    if [[ -z "$run_id" || ! -f "$sum" ]]; then
      echo "repolens_until_done: finished with exit 0 but no usable summary (run_id=${run_id:-empty})." >&2
      exit 0
    fi
    sr="$(jq -r '.stopped_reason // empty' "$sum")"
    if [[ "$sr" == "max-issues-reached" ]]; then
      echo "RepoLens stopped: global max-issues limit reached (by design)."
      exit 0
    fi
    pend="$(jq '[.lenses[] | select(.status == "rate-limited" or .status == "skipped" or .status == "agent-timeout" or .status == "agent-capacity")] | length' "$sum")"
    if [[ "${pend:-0}" -eq 0 ]]; then
      echo "RepoLens run $run_id finished — all lenses completed."
      exit 0
    fi
    echo "repolens_until_done: $pend lens(es) still incomplete — sleeping ${SLEEP_SEC}s, then resuming $run_id ($loop/$MAX_LOOPS)" >&2
    sleep "$SLEEP_SEC"
    resume_shell=(--resume "$run_id")
    continue
  fi

  # Non-zero: only auto-resume when we have persisted state
  if [[ -z "$run_id" || ! -d "$SCRIPT_DIR/logs/$run_id" ]]; then
    echo "repolens_until_done: repolens exited $rc before a log run id was available — not resuming." >&2
    exit "$rc"
  fi
  if [[ ! -f "$sum" ]]; then
    echo "repolens_until_done: repolens exited $rc with no summary.json — not resuming." >&2
    exit "$rc"
  fi

  abort_file="$SCRIPT_DIR/logs/$run_id/.rate-limit-abort"
  sr="$(jq -r '.stopped_reason // empty' "$sum" 2>/dev/null || true)"
  pend="$(jq '[.lenses[] | select(.status == "rate-limited" or .status == "skipped" or .status == "agent-timeout" or .status == "agent-capacity")] | length' "$sum" 2>/dev/null || echo 0)"

  if [[ -f "$abort_file" ]] || [[ "$sr" == "rate-limited" ]] || [[ "${pend:-0}" -gt 0 ]]; then
    echo "repolens_until_done: quota/pause or incomplete lenses — sleeping ${SLEEP_SEC}s, then resuming $run_id ($loop/$MAX_LOOPS)" >&2
    sleep "$SLEEP_SEC"
    resume_shell=(--resume "$run_id")
    continue
  fi

  echo "repolens_until_done: repolens exited $rc (stopped_reason=${sr:-unknown}) — not auto-resuming." >&2
  exit "$rc"
done

echo "repolens_until_done: exceeded REPOLENS_UNTIL_DONE_MAX_LOOPS=$MAX_LOOPS" >&2
exit 1
