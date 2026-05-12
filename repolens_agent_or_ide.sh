#!/usr/bin/env bash
# Copyright 2025-2026 benjarogit / Sunny C. (RepoLens Cursor Edition)
#
# Run pending RepoLens lenses one-by-one on an existing run: try `cursor` (CLI)
# first for each lens; if it is still not marked in logs/<run-id>/.completed
# afterward, run the same lens with `cursor-ide` (Composer handoff). Then
# continue with the next lens in domain order (same order as repolens.sh).
#
# Usage (same flags as repolens.sh except --agent/--focus/--dry-run, which
# this script controls):
#   ./repolens_agent_or_ide.sh --resume <run-id> --project <path> --local --yes [--domain <id>] [--mode audit] ...
#
# Environment:
#   REPOLENS_ORCH_IDE              If 0/false/no, only run cursor (no IDE fallback). Default: true
#   REPOLENS_ORCH_CURSOR_RL_RETRIES If set, overrides REPOLENS_CURSOR_RATE_LIMIT_MAX_RETRIES for cursor waves only
#
set -uo pipefail

if (( BASH_VERSINFO[0] < 4 )); then
  echo "repolens_agent_or_ide.sh requires bash 4.0 or newer" >&2
  exit 1
fi

die() {
  printf 'repolens_agent_or_ide: %s\n' "$*" >&2
  exit 2
}

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPOLENS_BIN="$SCRIPT_DIR/repolens.sh"
DOMAINS_FILE="$SCRIPT_DIR/config/domains.json"

usage() {
  cat <<'EOF'
repolens_agent_or_ide.sh — for each pending lens (same order as repolens.sh), run
  --agent cursor first; if logs/<run-id>/.completed still lacks that lens, run
  --agent cursor-ide (Composer handoff), then continue.

Required: --resume <run-id>
Pass the same flags as repolens.sh except do not use --agent, --focus, or --dry-run
(this script sets them per wave). Optional: --dry-run on this script only.

Example:
  ./repolens_agent_or_ide.sh --resume RUN --project ~/app --local --yes --domain security

Environment:
  REPOLENS_ORCH_IDE=false          — cursor only, no IDE fallback
  REPOLENS_ORCH_CURSOR_RL_RETRIES  — sets REPOLENS_CURSOR_RATE_LIMIT_MAX_RETRIES for cursor waves
EOF
}

forward=()
resume_id=""
dry_run=false
while [[ $# -gt 0 ]]; do
  case "$1" in
    -h|--help)
      usage
      exit 0
      ;;
    --resume)
      [[ -n "${2:-}" ]] || die "--resume requires a run id"
      resume_id="$2"
      shift 2
      ;;
    --dry-run)
      dry_run=true
      shift
      ;;
    *)
      forward+=("$1")
      shift
      ;;
  esac
done

[[ -n "$resume_id" ]] || die "missing required --resume <run-id> (see --help)"

[[ -f "$DOMAINS_FILE" ]] || die "missing $DOMAINS_FILE"

# Strip flags this orchestrator owns; repolens will get explicit --agent / --domain / --focus.
base=()
i=0
while (( i < ${#forward[@]} )); do
  case "${forward[i]}" in
    --agent)
      (( i < ${#forward[@]} - 1 )) || die "incomplete --agent in arguments"
      i=$((i + 2))
      ;;
    --focus)
      die "do not pass --focus; the orchestrator selects each lens in order"
      ;;
    --dry-run)
      i=$((i + 1))
      ;;
    --resume)
      (( i < ${#forward[@]} - 1 )) || die "incomplete --resume in arguments"
      i=$((i + 2))
      ;;
    *)
      base+=("${forward[i]}")
      i=$((i + 1))
      ;;
  esac
done

# Parse --mode / --domain from base for lens enumeration (defaults match repolens.sh).
mode=audit
domain_filter=""
j=0
while (( j < ${#base[@]} )); do
  case "${base[j]}" in
    --mode)
      [[ -n "${base[j + 1]:-}" ]] || die "incomplete --mode"
      mode="${base[j + 1]}"
      j=$((j + 2))
      ;;
    --domain)
      [[ -n "${base[j + 1]:-}" ]] || die "incomplete --domain"
      domain_filter="${base[j + 1]}"
      j=$((j + 2))
      ;;
    *)
      j=$((j + 1))
      ;;
  esac
done

case "$mode" in
  audit|feature|bugfix|discover|deploy|custom|opensource|content) ;;
  *) die "unsupported --mode for orchestrator: $mode" ;;
esac

# Base args without --domain (we always pass --domain from the loop entry to pin duplicate lens ids).
base_no_domain=()
j=0
while (( j < ${#base[@]} )); do
  case "${base[j]}" in
    --domain)
      j=$((j + 2))
      ;;
    *)
      base_no_domain+=("${base[j]}")
      j=$((j + 1))
      ;;
  esac
done

LOG_BASE="$SCRIPT_DIR/logs/$resume_id"
[[ -d "$LOG_BASE" ]] || die "log directory not found: $LOG_BASE"
completed_file="$LOG_BASE/.completed"
touch "$completed_file"

# Mode-aware domain filter (same logic as repolens resolve_lenses).
_jq_mode_domain_filter='
  (if $mode == "discover" then select(.mode == "discover")
   elif $mode == "deploy" then select(.mode == "deploy")
   elif $mode == "opensource" then select(.mode == "opensource")
   elif $mode == "content" then select(.mode == "content")
   else select(.mode != "discover" and .mode != "deploy" and .mode != "opensource" and .mode != "content")
   end)
'

orch_emit_lens_entries() {
  if [[ -n "$domain_filter" ]]; then
    jq -r --arg d "$domain_filter" --arg mode "$mode" \
      ".domains[] | $_jq_mode_domain_filter | select(.id == \$d) | .lenses[] | \$d + \"/\" + ." "$DOMAINS_FILE" \
      || die "jq failed listing lenses for domain $domain_filter"
  else
    jq -r --arg mode "$mode" \
      ".domains | sort_by(.order)[] | $_jq_mode_domain_filter | .id as \$d | .lenses[] | \$d + \"/\" + ." "$DOMAINS_FILE" \
      || die "jq failed listing lenses for mode $mode"
  fi
}

lens_done() {
  grep -qxF "$1" "$completed_file" 2>/dev/null
}

use_ide=true
case "${REPOLENS_ORCH_IDE:-true}" in
  0|false|no|FALSE|NO) use_ide=false ;;
esac

pending=()
while IFS= read -r entry; do
  [[ -n "$entry" ]] || continue
  if ! lens_done "$entry"; then
    pending+=("$entry")
  fi
done < <(orch_emit_lens_entries)

if [[ "${#pending[@]}" -eq 0 ]]; then
  echo "repolens_agent_or_ide: no pending lenses for run $resume_id (mode=$mode domain=${domain_filter:-all})."
  exit 0
fi

echo "repolens_agent_or_ide: run=$resume_id pending=${#pending[@]} lens(es) (cursor first, then cursor-ide if needed)"

if $dry_run; then
  printf '  (dry-run) would process:\n'
  for e in "${pending[@]}"; do
    printf '    %s\n' "$e"
  done
  exit 0
fi

for entry in "${pending[@]}"; do
  domain="${entry%%/*}"
  lens_id="${entry#*/}"
  printf '\n=== repolens_agent_or_ide: %s ===\n' "$entry"

  set +e
  if [[ -n "${REPOLENS_ORCH_CURSOR_RL_RETRIES:-}" ]]; then
    env "REPOLENS_CURSOR_RATE_LIMIT_MAX_RETRIES=${REPOLENS_ORCH_CURSOR_RL_RETRIES}" \
      bash "$REPOLENS_BIN" "${base_no_domain[@]}" --resume "$resume_id" --agent cursor \
      --domain "$domain" --focus "$lens_id" --yes
  else
    bash "$REPOLENS_BIN" "${base_no_domain[@]}" --resume "$resume_id" --agent cursor \
      --domain "$domain" --focus "$lens_id" --yes
  fi
  rc_cursor=$?
  set -e

  if lens_done "$entry"; then
    echo "repolens_agent_or_ide: $entry completed via cursor (exit $rc_cursor)."
    continue
  fi

  echo "repolens_agent_or_ide: $entry still pending after cursor (exit $rc_cursor)." >&2

  if ! $use_ide; then
    die "lens $entry not completed and REPOLENS_ORCH_IDE disables cursor-ide fallback"
  fi

  echo "repolens_agent_or_ide: starting cursor-ide for $entry — respond in Cursor Composer (ide-prompt under $LOG_BASE)." >&2

  set +e
  bash "$REPOLENS_BIN" "${base_no_domain[@]}" --resume "$resume_id" --agent cursor-ide \
    --domain "$domain" --focus "$lens_id" --yes
  rc_ide=$?
  set -e

  if lens_done "$entry"; then
    echo "repolens_agent_or_ide: $entry completed via cursor-ide (exit $rc_ide)."
    continue
  fi

  die "lens $entry still not in $completed_file after cursor-ide (exit $rc_ide) — stop here"
done

echo ""
echo "repolens_agent_or_ide: finished pending queue for run $resume_id."
