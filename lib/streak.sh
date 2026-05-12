#!/usr/bin/env bash
# Copyright 2025-2026 Bootstrap Academy
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

# RepoLens — DONE streak detection
# Cursor CLI sleep hints + MANUAL_HANDOFF: RepoLens Cursor Edition (benjarogit / Sunny C.)

# Strip ANSI escape sequences from stdin.
# Uses a bash variable for the ESC byte instead of \x1b hex escapes in sed,
# because BSD sed (macOS) does not support \x1b — only GNU sed does.
strip_ansi() {
  local esc=$'\x1b'
  sed -E "s/${esc}\[[0-9;]*[a-zA-Z]//g; s/${esc}\([0-9;]*[a-zA-Z]//g; s/${esc}\]8;[^\\\\]*\\\\//g"
}

# Strip non-alphanumeric (keep _), uppercase.
normalize_word() {
  local word="${1:-}"
  printf "%s" "$word" | tr -cd '[:alnum:]_' | tr '[:lower:]' '[:upper:]'
}

# Extract first word from file. Returns "" if file empty/missing.
# Strips ANSI escape codes before extraction so colored agent output is handled.
first_word() {
  local file="$1"
  [[ -s "$file" ]] || { echo ""; return 0; }
  strip_ansi < "$file" | awk 'NF {for (i = 1; i <= NF; i++) { print $i; exit }}'
}

# Extract last word from file. Returns "" if file empty/missing.
# Strips ANSI escape codes before extraction so colored agent output is handled.
last_word() {
  local file="$1"
  [[ -s "$file" ]] || { echo ""; return 0; }
  strip_ansi < "$file" | awk '{for (i = 1; i <= NF; i++) { last = $i }} END { if (last) print last }'
}

# Returns 0 if first OR last normalized word is "DONE", 1 otherwise.
check_done() {
  local file="$1"
  local first_norm last_norm
  first_norm="$(normalize_word "$(first_word "$file")")"
  last_norm="$(normalize_word "$(last_word "$file")")"
  if [[ "$first_norm" == "DONE" || "$last_norm" == "DONE" ]]; then
    return 0
  fi

  # Cursor and other agents sometimes emit DONE as a dedicated status line
  # inside a longer wrapped response. Accept a standalone DONE line as complete.
  strip_ansi < "$file" | awk '
    /^[[:space:]]*DONE[[:space:][:punct:]]*$/ { found=1 }
    END { exit(found ? 0 : 1) }
  '
}

# count_issues_in_output <file>
#   Counts GitHub issue URLs in agent output (printed by issue creation on success).
#   Best-effort fallback — agents may not echo the full URL. Prefer
#   forge_issue_list_count from lib/forge.sh when querying a forge directly.
#   Returns count on stdout.
count_issues_in_output() {
  local file="$1"
  [[ -s "$file" ]] || { echo 0; return 0; }
  grep -oE 'https://github\.com/[^/]+/[^/]+/issues/[0-9]+' "$file" 2>/dev/null | wc -l
}

# count_dry_run_issues <dir>
#   Counts .md files in a directory (maxdepth 1, no subdirectories).
#   Returns count on stdout. Returns 0 if directory is empty or missing.
count_dry_run_issues() {
  local dir="$1"
  [[ -d "$dir" ]] || { echo 0; return 0; }
  find "$dir" -maxdepth 1 -name '*.md' -type f 2>/dev/null | wc -l
}

# Rate-limit / quota / auth-failure signatures emitted by agent CLIs
# (claude, codex, spark, opencode). Case-insensitive ERE patterns.
# Extend this list when new agent error strings surface. False positives
# matter less than false negatives here — a false abort costs one run;
# a false negative costs a night of wasted iterations.
_REPOLENS_RATE_LIMIT_PATTERNS=(
  "you('|\xe2\x80\x99)?ve hit your usage limit"
  "usage limit"
  "rate[- ]?limit(ed|ing|s)?"
  "try again (at|in)"
  "quota exceeded"
  "401 unauthorized"
  "403 forbidden"
)

# detect_agent_rate_limit <output_file>
#   Returns 0 if any known rate-limit / quota / auth-failure signature is
#   found in the file, 1 otherwise. Matching is case-insensitive and
#   applied to ANSI-stripped output (so colored terminal output still
#   matches).
#
#   On match, prints "PATTERN|SNIPPET" to stdout where PATTERN is the
#   signature that matched and SNIPPET is the first 200 characters of
#   the matching line. Callers can split on the first "|" to extract
#   both fields for logging.
#
#   Intentionally avoids matching the orchestrator's own `gh` 401 errors
#   because `run_agent`'s stdout/stderr is captured separately — only the
#   agent subprocess writes to <output_file>.
detect_agent_rate_limit() {
  local file="$1"
  [[ -s "$file" ]] || return 1

  local stripped pat line
  stripped="$(strip_ansi < "$file" 2>/dev/null)"
  [[ -n "$stripped" ]] || return 1

  for pat in "${_REPOLENS_RATE_LIMIT_PATTERNS[@]}"; do
    line="$(printf '%s\n' "$stripped" | grep -iE -m1 "$pat" 2>/dev/null || true)"
    if [[ -n "$line" ]]; then
      # Trim leading whitespace for a cleaner snippet
      line="${line#"${line%%[![:space:]]*}"}"
      printf '%s|%s\n' "$pat" "${line:0:200}"
      return 0
    fi
  done
  return 1
}

# parse_rate_limit_resume_epoch <output_file>
#   Prints a Unix epoch when a known rate-limit resume time can be parsed from
#   ANSI-stripped agent output. Prints nothing when no usable resume time is
#   present. This helper intentionally does not decide whether the output is a
#   rate-limit failure; callers must keep that check separate.
parse_rate_limit_resume_epoch() {
  local file="$1"
  [[ -s "$file" ]] || { echo ""; return 0; }

  local stripped now_epoch seconds line fragment lower candidate epoch
  stripped="$(strip_ansi < "$file" 2>/dev/null)"
  [[ -n "$stripped" ]] || { echo ""; return 0; }

  now_epoch="$(date +%s)"

  seconds="$(printf '%s\n' "$stripped" | sed -nE 's/.*[Rr][Ee][Tt][Rr][Yy]-[Aa][Ff][Tt][Ee][Rr]:[[:space:]]*([0-9]+).*/\1/p' | head -n 1)"
  if [[ "$seconds" =~ ^[0-9]+$ ]]; then
    printf '%s\n' $((now_epoch + seconds))
    return 0
  fi

  line="$(printf '%s\n' "$stripped" | grep -iE -m1 'retry[[:space:]]+after[[:space:]]+[0-9]+[[:space:]]+seconds?' 2>/dev/null || true)"
  if [[ -n "$line" ]]; then
    lower="$(printf '%s' "$line" | tr '[:upper:]' '[:lower:]')"
    if [[ "$lower" =~ retry[[:space:]]+after[[:space:]]+([0-9]+)[[:space:]]+seconds?([^[:alpha:]]|$) ]]; then
      seconds=$((10#${BASH_REMATCH[1]}))
      printf '%s\n' $((now_epoch + seconds))
      return 0
    fi
  fi

  line="$(printf '%s\n' "$stripped" | grep -iE -m1 'try again in[[:space:]]+[0-9]' 2>/dev/null || true)"
  if [[ -n "$line" ]]; then
    fragment="$(printf '%s\n' "$line" | sed -E 's/.*[Tt][Rr][Yy][[:space:]]+[Aa][Gg][Aa][Ii][Nn][[:space:]]+[Ii][Nn][[:space:]]+//')"
    lower="$(printf '%s' "$fragment" | tr '[:upper:]' '[:lower:]')"

    if [[ "$lower" =~ ^([0-9]+)[[:space:]]*h([[:space:]]*([0-9]+)[[:space:]]*m)?([^[:alpha:]]|$) ]]; then
      seconds=$((10#${BASH_REMATCH[1]} * 3600))
      if [[ -n "${BASH_REMATCH[3]:-}" ]]; then
        seconds=$((seconds + 10#${BASH_REMATCH[3]} * 60))
      fi
      printf '%s\n' $((now_epoch + seconds))
      return 0
    fi

    if [[ "$lower" =~ ^([0-9]+)[[:space:]]*(hours?|hrs?|hr)([[:space:]]+([0-9]+)[[:space:]]*(minutes?|mins?|min))?([^[:alpha:]]|$) ]]; then
      seconds=$((10#${BASH_REMATCH[1]} * 3600))
      if [[ -n "${BASH_REMATCH[4]:-}" ]]; then
        seconds=$((seconds + 10#${BASH_REMATCH[4]} * 60))
      fi
      printf '%s\n' $((now_epoch + seconds))
      return 0
    fi

    if [[ "$lower" =~ ^([0-9]+)[[:space:]]*(minutes?|mins?|min|m)([^[:alpha:]]|$) ]]; then
      seconds=$((10#${BASH_REMATCH[1]} * 60))
      printf '%s\n' $((now_epoch + seconds))
      return 0
    fi

    if [[ "$lower" =~ ^([0-9]+)[[:space:]]*(seconds?|secs?|sec|s)([^[:alpha:]]|$) ]]; then
      seconds=$((10#${BASH_REMATCH[1]}))
      printf '%s\n' $((now_epoch + seconds))
      return 0
    fi
  fi

  candidate="$(printf '%s\n' "$stripped" | sed -nE 's/.*[Tt][Rr][Yy][[:space:]]+[Aa][Gg][Aa][Ii][Nn][[:space:]]+[Aa][Tt][[:space:]]+(.+)/\1/p' | head -n 1)"
  [[ -n "$candidate" ]] || { echo ""; return 0; }

  candidate="${candidate#"${candidate%%[![:space:]]*}"}"
  candidate="${candidate%"${candidate##*[![:space:]]}"}"
  while [[ "$candidate" == *. || "$candidate" == *";" ]]; do
    candidate="${candidate%?}"
  done
  candidate="${candidate%"${candidate##*[![:space:]]}"}"
  candidate="$(printf '%s' "$candidate" | sed -E 's/([0-9]+)([sS][tT]|[nN][dD]|[rR][dD]|[tT][hH])([^[:alpha:]]|$)/\1\3/g')"

  epoch="$(date -d "$candidate" +%s 2>/dev/null || true)"
  if [[ "$epoch" =~ ^[0-9]+$ ]]; then
    if [[ "$candidate" =~ ^[0-9]{1,2}:[0-9]{2}([[:space:]]*[AaPp][Mm])?([[:space:]]+[[:alpha:]]{2,5})?$ && "$epoch" -le "$now_epoch" ]]; then
      epoch=$((epoch + 86400))
    fi
    printf '%s\n' "$epoch"
    return 0
  fi

  echo ""
  return 0
}

# cursor_rate_limit_hint_sleep_sec <output_file>
# Best-effort parse of "try again in …" / "try again at …" from agent stderr
# (cursor-agent, codex, etc.). Prints one integer: suggested sleep seconds, or
# nothing (exit 1) if no parseable hint. Caller should clamp to sane bounds.
cursor_rate_limit_hint_sleep_sec() {
  local file="$1"
  [[ -s "$file" ]] || return 1

  local stripped low line
  stripped="$(strip_ansi <"$file" 2>/dev/null)" || return 1
  low="${stripped,,}"

  line="$(printf '%s\n' "$low" | grep -E 'try again in[[:space:]]+[0-9]+' | head -1 || true)"
  if [[ -n "$line" ]]; then
    if [[ "$line" =~ try[[:space:]]+again[[:space:]]+in[[:space:]]+([0-9]+)[[:space:]]*hours? ]]; then
      echo $((${BASH_REMATCH[1]} * 3600))
      return 0
    fi
    if [[ "$line" =~ try[[:space:]]+again[[:space:]]+in[[:space:]]+([0-9]+)[[:space:]]*minutes? ]]; then
      echo $((${BASH_REMATCH[1]} * 60))
      return 0
    fi
    if [[ "$line" =~ try[[:space:]]+again[[:space:]]+in[[:space:]]+([0-9]+)[[:space:]]*seconds? ]]; then
      printf '%s\n' "${BASH_REMATCH[1]}"
      return 0
    fi
  fi

  line="$(printf '%s\n' "$low" | grep -E 'try again at[[:space:]]+' | head -1 || true)"
  if [[ -n "$line" ]] && [[ "$line" =~ try[[:space:]]+again[[:space:]]+at[[:space:]]+([^[:space:]]+) ]]; then
    local ts="${BASH_REMATCH[1]}"
    local now_epoch want_epoch
    now_epoch="$(date -u +%s 2>/dev/null)" || return 1
    want_epoch="$(date -u -d "$ts" +%s 2>/dev/null)" || return 1
    if [[ "$want_epoch" -gt "$now_epoch" ]]; then
      echo $((want_epoch - now_epoch))
      return 0
    fi
  fi

  return 1
}

# repolens_write_cursor_rate_limit_handoff <log_base> <run_id> <project_path> <domain> <lens_id> <iteration> <agent_output_file> <retry_no>
# Writes MANUAL_HANDOFF.md and appends one JSON line to repolens-ctl.ndjson (Cursor Edition).
repolens_write_cursor_rate_limit_handoff() {
  local log_base="$1" run_id="$2" project_path="$3" domain="$4" lens_id="$5" iteration="$6" agent_out="$7" retry_no="$8"
  [[ -n "$log_base" && -n "$run_id" ]] || return 1
  mkdir -p "$log_base" || return 1

  local md="$log_base/MANUAL_HANDOFF.md"
  local ctl="$log_base/repolens-ctl.ndjson"
  local script_dir lens_rel
  script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd 2>/dev/null)" || script_dir=""
  [[ -z "$script_dir" ]] && script_dir="(path to RepoLens checkout)"
  lens_rel="${agent_out#"$log_base"/}"

  {
    printf '%s\n' "# RepoLens — manual continuation after Cursor CLI rate limit"
    printf '%s\n' ""
    printf '%s\n' "**Run ID:** \`$run_id\`  "
    printf '%s\n' "**Lens:** \`$domain/$lens_id\` (iteration $iteration, CLI retry #$retry_no)  "
    printf '%s\n' "**Project:** \`$project_path\`  "
    printf '%s\n' "**Last captured agent output:** \`$log_base/$lens_rel\`  "
    printf '%s\n' ""
    printf '%s\n' "## Deutsch — was jetzt?"
    printf '%s\n' "1. **Warten**, bis dein Cursor-Kontingent wieder frei ist (oder die Wartezeit aus der letzten Agent-Ausgabe abwarten)."
    printf '%s\n' "2. **Weiter mit derselben Run-ID:** im RepoLens-Checkout:"
    printf '%s\n' '```bash'
    printf '%s\n' "export PATH=\"\$HOME/.local/bin:\$PATH\""
    printf '%s\n' "cd \"$script_dir\""
    printf '%s\n' "./repolens.sh --project \"$project_path\" --agent cursor --local \\"
    printf '%s\n' "  --resume $run_id --yes"
    printf '%s\n' '```'
    printf '%s\n' "3. **Oder automatisch in Wellen:** \`./repolens_until_done.sh --resume $run_id --project \"$project_path\" --agent cursor --local --yes\` (schläft zwischen Resumes)."
    printf '%s\n' "4. **Oder manuell im Cursor-Chat (Composer):** \`--agent cursor-ide\` statt \`cursor\` — gleiche \`--resume\`-Run-ID; RepoLens schreibt dann \`ide-prompt-*\` und wartet auf deine Antwort-Dateien."
    printf '%s\n' ""
    printf '%s\n' "## English — next steps"
    printf '%s\n' "Same as above: **\`--resume $run_id\`** with \`cursor\`, or use \`repolens_until_done.sh\`, or switch to **\`--agent cursor-ide\`** for full IDE handoff."
  } >"$md"

  if [[ "${retry_no:-0}" -eq 1 ]] && command -v jq >/dev/null 2>&1; then
    local json
    json="$(jq -nc \
      --arg kind "cursor_cli_rate_limited" \
      --arg run_id "$run_id" \
      --arg domain "$domain" \
      --arg lens "$lens_id" \
      --argjson iteration "$iteration" \
      --argjson retry "$retry_no" \
      --arg project "$project_path" \
      --arg agent_log "$agent_out" \
      --arg handoff_md "$md" \
      '{v: 1, kind: $kind, run_id: $run_id, domain: $domain, lens: $lens, iteration: $iteration, retry: $retry, project: $project, agent_log: $agent_log, handoff_markdown: $handoff_md}')" || json=""
    if [[ -n "$json" ]]; then
      printf '%s\n' "$json" >>"$ctl"
      printf 'REPOLENS_MANUAL_HANDOFF %s\n' "$json" >&2
    fi
  fi
  return 0
}
