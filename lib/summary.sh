#!/usr/bin/env bash
# Copyright 2025-2026 Bootstrap Academy (upstream RepoLens).
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

# RepoLens — JSON summary generation

# init_summary <summary_file> <run_id> <project_path> <mode> <agent> [spec_file] [max_issues] [output_mode] [output_dir]
#   Creates initial summary.json skeleton
init_summary() {
  local file="$1" run_id="$2" project="$3" mode="$4" agent="$5"
  local spec_file="${6:-}" max_issues="${7:-}"
  local output_mode="${8:-github}" output_dir="${9:-}"
  local spec_json="null"
  if [[ -n "$spec_file" ]]; then
    spec_json="$(jq -n --arg p "$spec_file" '$p')"
  fi
  local max_issues_json="null"
  if [[ -n "$max_issues" ]]; then
    max_issues_json="$max_issues"
  fi
  local output_dir_json="null"
  if [[ -n "$output_dir" ]]; then
    output_dir_json="$(jq -n --arg p "$output_dir" '$p')"
  fi
  local output_mode_json
  output_mode_json="$(jq -n --arg m "$output_mode" '$m')"
  cat > "$file" <<ENDJSON
{
  "run_id": "$run_id",
  "project": "$project",
  "mode": "$mode",
  "agent": "$agent",
  "spec": $spec_json,
  "max_issues": $max_issues_json,
  "output_mode": $output_mode_json,
  "output_dir": $output_dir_json,
  "started_at": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
  "completed_at": null,
  "stopped_reason": null,
  "lenses": [],
  "totals": {"lenses_run": 0, "iterations_total": 0, "issues_created": 0}
}
ENDJSON
}

# record_lens <summary_file> <domain> <lens_id> <iterations> <status> [issues]
#   Appends a lens result to the summary
record_lens() {
  local file="$1" domain="$2" lens_id="$3" iterations="$4" status="$5"
  local issues="${6:-0}"
  local tmp="${file}.tmp"
  local lenses_increment=1
  if [[ "$status" == "skipped" ]]; then
    lenses_increment=0
  fi
  jq --arg d "$domain" --arg l "$lens_id" --argjson i "$iterations" --arg s "$status" \
     --argjson iss "$issues" --argjson lr "$lenses_increment" \
    '.lenses += [{"domain": $d, "lens": $l, "iterations": $i, "status": $s, "issues_created": $iss}] |
     .totals.lenses_run += $lr |
     .totals.iterations_total += $i |
     .totals.issues_created += $iss' "$file" > "$tmp" && mv "$tmp" "$file"
}

# set_stop_reason <summary_file> <reason>
#   Sets the stopped_reason field in summary.json
set_stop_reason() {
  local file="$1" reason="${2:-}"
  [[ -n "$reason" ]] || return 0
  local tmp="${file}.tmp"
  jq --arg r "$reason" '.stopped_reason = $r' "$file" > "$tmp" && mv "$tmp" "$file"
}

# finalize_summary <summary_file>
#   Sets completed_at timestamp
finalize_summary() {
  local file="$1"
  local tmp="${file}.tmp"
  jq --arg t "$(date -u +%Y-%m-%dT%H:%M:%SZ)" '.completed_at = $t' "$file" > "$tmp" && mv "$tmp" "$file"
}

# append_repolens_error_event <log_base> <run_id> <domain> <lens_id> <iteration> <code> <message> <detail_file>
#   Appends one NDJSON line for IDE/agent failures (review + automation).
append_repolens_error_event() {
  local log_base="$1" run_id="$2" domain="$3" lens_id="$4" iteration="$5" code="$6" message="$7" detail_path="$8"
  local errfile="$log_base/repolens-errors.ndjson"
  local line
  line="$(jq -nc \
    --arg ts "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
    --arg rid "$run_id" \
    --arg d "$domain" --arg l "$lens_id" \
    --argjson iter "$iteration" \
    --arg c "$code" \
    --arg m "$message" \
    --arg p "$detail_path" \
    '{ts:$ts,run_id:$rid,domain:$d,lens:$l,iteration:$iter,code:$c,message:$m,detail_file:$p}')"
  printf '%s\n' "$line" >>"$errfile"
}

# enhance_summary_with_run_outcome <summary_file> <log_base>
#   Adds run_outcome, errors_log; optional rate-limit abort file is on disk.
enhance_summary_with_run_outcome() {
  local file="$1" log_base="$2"
  local tmp="${file}.tmp"
  local abort_json="false"
  [[ -f "$log_base/.rate-limit-abort" ]] && abort_json="true"
  jq \
    --argjson rl_abort "$abort_json" \
    --arg el "$log_base/repolens-errors.ndjson" \
    '.errors_log = $el |
     .run_outcome = (
       if $rl_abort == true then "failed"
       elif .stopped_reason == "rate-limited" then "failed"
       elif (.lenses | any(.status == "ide-handoff-failed" or .status == "agent-timeout" or .status == "rate-limited" or .status == "agent-capacity" or .status == "max-iterations")) then "failed"
       elif (.lenses | length) == 0 then "success"
       elif (.lenses | all(.status == "completed" or .status == "skipped")) then
         (if (.lenses | any(.status == "skipped")) then "partial" else "success" end)
       else "failed" end
     )' "$file" > "$tmp" && mv "$tmp" "$file"
}

# repolens_run_failed <summary_file> <log_base>
#   Exit status 0 = run should be treated as failure (non-zero exit code).
repolens_run_failed() {
  local summary="$1" log_base="$2"
  [[ -f "$log_base/.rate-limit-abort" ]] && return 0
  if jq -e '.run_outcome == "failed"' "$summary" >/dev/null 2>&1; then
    return 0
  fi
  return 1
}
