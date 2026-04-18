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

# RepoLens — Cursor agent runner
#
# Phase 1 contract:
# - Supports local mode integration only (enforced by repolens.sh guardrail)
# - cursor-ide: no subprocess — writes prompts under the lens log dir and waits
#   for Composer output files (see run_cursor_ide_agent).
# - cursor: Cursor Agent CLI in print mode with model control:
#     cursor-agent --force --approve-mcps --print --model <auto|named> --workspace <path> "<prompt>"
# - The runner command can be overridden via CURSOR_AGENT_RUNNER_CMD
# - The model can be overridden via CURSOR_AGENT_MODEL (default: auto)
# - If a named model is rejected by Cursor, RepoLens retries once with Auto.
#
# Example:
#   export CURSOR_AGENT_RUNNER_CMD="cursor-agent --force --approve-mcps"
#   export CURSOR_AGENT_MODEL="auto"
#   export CURSOR_AGENT_TIMEOUT_SEC=45
#
# Cursor IDE local integration, REPOLENS_CTL protocol (csretro): Copyright 2025-2026 benjarogit / Sunny C.

set -uo pipefail

# ---------------------------------------------------------------------------
# Machine protocol for Cursor IDE / „Run Everything“ (cursor-ide)
# ---------------------------------------------------------------------------
# Emits one line to stderr: REPOLENS_CTL <json>  (and appends to REPOLENS_CTL_LOG)
# Plus plain lines: REPOLENS_PHASE …, REPOLENS_ERROR … for simple parsers.

repolens_ctl_autonomous_detect() {
  local _auto="${REPOLENS_IDE_AUTONOMOUS:-}"
  case "${_auto,,}" in
    1|true|yes) return 0 ;;
  esac
  # Integrated terminal hints (VS Code / Cursor); not officially documented.
  [[ "${TERM_PROGRAM:-}" == "vscode" ]] && return 0
  [[ -n "${CURSOR_TRACE_ID:-}" ]] && return 0
  [[ -n "${CURSOR_AGENT:-}" ]] && return 0
  return 1
}

repolens_ctl_emit_json() {
  local json="$1"
  printf 'REPOLENS_CTL %s\n' "$json" >&2
  if [[ -n "${REPOLENS_CTL_LOG:-}" ]]; then
    printf '%s\n' "$json" >>"$REPOLENS_CTL_LOG"
  fi
}

# Returns 0 if stub / empty responses are allowed (CI or explicit opt-in only).
repolens_ide_stub_allowed() {
  local _allow="${REPOLENS_IDE_ALLOW_STUB-}"
  case "${_allow,,}" in
    1|true|yes) return 0 ;;
  esac
  return 1
}

# Substantive cursor-ide reply check (default: strict). Set REPOLENS_IDE_ALLOW_STUB=1 to disable.
repolens_ide_validate_cursor_ide_response() {
  local f="$1"
  repolens_ide_stub_allowed && return 0
  [[ -f "$f" && -s "$f" ]] || return 1
  local min_b="${REPOLENS_IDE_MIN_RESPONSE_BYTES:-400}"
  [[ "$min_b" =~ ^[0-9]+$ ]] || min_b=400
  local sz
  sz=$(wc -c <"$f")
  [[ "$sz" -ge "$min_b" ]] || return 1
  if grep -qiE 'Automatischer Durchlauf \(Chat-Agent-Monitor\)|automated pass by monitoring agent|no substantive audit|Stub-Antwort|Chat-Agent-Monitor|stub run' "$f"; then
    return 1
  fi
  return 0
}

repolens_ctl_emit_lens_start() {
  printf 'REPOLENS_PHASE lens_start\n' >&2
  local json
  json="$(jq -nc \
    --argjson v 1 \
    --arg kind "lens_start" \
    --arg run_id "${REPOLENS_RUN_ID:-}" \
    --arg domain "${REPOLENS_CTL_DOMAIN:-}" \
    --arg lens "${REPOLENS_CTL_LENS_ID:-}" \
    --arg lens_name "${REPOLENS_CTL_LENS_NAME:-}" \
    '{v: $v, kind: $kind, run_id: $run_id, domain: $domain, lens: $lens, lens_name: $lens_name}')"
  repolens_ctl_emit_json "$json"
}

cursor_runner_required_cmd() {
  local runner_cmd="${CURSOR_AGENT_RUNNER_CMD:-cursor-agent --force --approve-mcps}"
  local -a parts=()
  read -r -a parts <<< "$runner_cmd"
  if [[ "${#parts[@]}" -eq 0 || -z "${parts[0]}" ]]; then
    echo "cursor-agent"
  else
    echo "${parts[0]}"
  fi
}

cursor_runner_has_model_flag() {
  local -a parts=("$@")
  local i
  for ((i = 0; i < ${#parts[@]}; i++)); do
    if [[ "${parts[i]}" == "--model" || "${parts[i]}" == --model=* ]]; then
      return 0
    fi
  done
  return 1
}

cursor_runner_strip_model_flag() {
  local -a parts=("$@")
  local -a out=()
  local i

  for ((i = 0; i < ${#parts[@]}; i++)); do
    if [[ "${parts[i]}" == "--model" ]]; then
      i=$((i + 1))
      continue
    fi
    if [[ "${parts[i]}" == --model=* ]]; then
      continue
    fi
    out+=("${parts[i]}")
  done

  printf "%s\n" "${out[@]}"
}

cursor_runner_model_unavailable() {
  local output_file="$1"
  grep -Eq "Named models unavailable|Free plans can only use Auto|Switch to Auto or upgrade plans" "$output_file" 2>/dev/null
}

run_cursor_agent_once() {
  local timeout_sec="$1"
  shift
  local -a cmd=("$@")

  if command -v timeout >/dev/null 2>&1; then
    timeout "${timeout_sec}s" "${cmd[@]}"
    local status=$?
    if [[ "$status" -eq 124 ]]; then
      echo "REPOLENS_CURSOR_TIMEOUT after ${timeout_sec}s"
    fi
    return "$status"
  fi

  "${cmd[@]}"
}

run_cursor_agent() {
  local prompt="$1"
  local project_path="$2"
  local runner_cmd="${CURSOR_AGENT_RUNNER_CMD:-cursor-agent --force --approve-mcps}"
  local cursor_model="${CURSOR_AGENT_MODEL:-auto}"
  local timeout_sec="${CURSOR_AGENT_TIMEOUT_SEC:-45}"
  local -a cmd_parts=()

  read -r -a cmd_parts <<< "$runner_cmd"
  [[ "${#cmd_parts[@]}" -gt 0 ]] || die "CURSOR_AGENT_RUNNER_CMD is empty"

  if ! [[ "$timeout_sec" =~ ^[1-9][0-9]*$ ]]; then
    die "CURSOR_AGENT_TIMEOUT_SEC must be a positive integer, got: $timeout_sec"
  fi

  if [[ -z "$cursor_model" ]]; then
    die "CURSOR_AGENT_MODEL must not be empty"
  fi

  if ! cursor_runner_has_model_flag "${cmd_parts[@]}"; then
    cmd_parts+=(--model "$cursor_model")
  fi

  local -a run_cmd=("${cmd_parts[@]}" --print --workspace "$project_path" "$prompt")
  local tmp_output
  tmp_output="$(mktemp)"

  if run_cursor_agent_once "$timeout_sec" "${run_cmd[@]}" >"$tmp_output" 2>&1; then
    cat "$tmp_output"
    rm -f "$tmp_output"
    return 0
  fi

  local status=$?
  cat "$tmp_output"

  if cursor_runner_model_unavailable "$tmp_output"; then
    local -a fallback_base=()
    mapfile -t fallback_base < <(cursor_runner_strip_model_flag "${cmd_parts[@]}")
    fallback_base+=(--model auto)

    echo "REPOLENS_CURSOR_MODEL_FALLBACK: retrying with --model auto" >&2
    rm -f "$tmp_output"
    run_cursor_agent_once "$timeout_sec" "${fallback_base[@]}" --print --workspace "$project_path" "$prompt"
    return $?
  fi

  rm -f "$tmp_output"
  return "$status"
}

# run_cursor_ide_agent <prompt> <project_path>
#
# Handoff to the Cursor IDE (Composer/Chat): no cursor-agent. RepoLens writes
# ide-prompt-iter-N.md; you run the agent in the IDE, save the reply to
# ide-response-iter-N.txt, then: touch ide-done-iter-N
#
# Requires REPOLENS_CURSOR_IDE_LENS_LOG_DIR and REPOLENS_CURSOR_IDE_ITERATION
# (set by repolens.sh run_lens).
#
# REPOLENS_CURSOR_IDE_POLL_SEC (default 2)
# REPOLENS_CURSOR_IDE_MAX_WAIT_SEC (default 0 = no cap)

run_cursor_ide_agent() {
  local prompt="$1"
  local project_path="$2"
  local ide_dir="${REPOLENS_CURSOR_IDE_LENS_LOG_DIR:-}"
  local iteration="${REPOLENS_CURSOR_IDE_ITERATION:-1}"
  local poll_sec="${REPOLENS_CURSOR_IDE_POLL_SEC:-2}"
  local max_wait="${REPOLENS_CURSOR_IDE_MAX_WAIT_SEC:-0}"

  [[ -n "$ide_dir" ]] || die "REPOLENS_CURSOR_IDE_LENS_LOG_DIR must be set for --agent cursor-ide"
  [[ "$iteration" =~ ^[1-9][0-9]*$ ]] || die "REPOLENS_CURSOR_IDE_ITERATION must be a positive integer"
  [[ "$poll_sec" =~ ^[1-9][0-9]*$ ]] || die "REPOLENS_CURSOR_IDE_POLL_SEC must be a positive integer"
  [[ "$max_wait" =~ ^[0-9]+$ ]] || die "REPOLENS_CURSOR_IDE_MAX_WAIT_SEC must be a non-negative integer"

  mkdir -p "$ide_dir"
  local prompt_f response_f done_f
  prompt_f="$ide_dir/ide-prompt-iter-${iteration}.md"
  response_f="$ide_dir/ide-response-iter-${iteration}.txt"
  done_f="$ide_dir/ide-done-iter-${iteration}"

  rm -f "$done_f"
  printf '%s\n' "$prompt" >"$prompt_f"

  local auto_json=false
  repolens_ctl_autonomous_detect && auto_json=true

  local handoff_json
  handoff_json="$(jq -nc \
    --argjson v 1 \
    --arg kind "ide_handoff" \
    --arg run_id "${REPOLENS_RUN_ID:-}" \
    --arg domain "${REPOLENS_CTL_DOMAIN:-}" \
    --arg lens "${REPOLENS_CTL_LENS_ID:-}" \
    --argjson iteration "$iteration" \
    --arg prompt_file "$prompt_f" \
    --arg response_file "$response_f" \
    --arg done_file "$done_f" \
    --argjson autonomous_env "$auto_json" \
    '{
      v: $v,
      kind: $kind,
      run_id: $run_id,
      domain: $domain,
      lens: $lens,
      iteration: $iteration,
      files: {prompt: $prompt_file, response: $response_file, done: $done_file},
      autonomous_env_hint: $autonomous_env,
      instruction: "IDE/Agent: read files.prompt, execute lens in Composer, write full reply to files.response, then touch files.done"
    }')"

  printf 'REPOLENS_PHASE handoff_wait\n' >&2
  printf 'REPOLENS_AWAIT done_file=%s\n' "$done_f" >&2
  repolens_ctl_emit_json "$handoff_json"

  cat <<EOF >&2
[RepoLens cursor-ide] Iteration ${iteration} — kein cursor-agent.
  1) Datei im Editor öffnen: $prompt_f
  2) In Cursor Composer/Agent den Inhalt bearbeiten lassen (@-mention der Datei oder einfügen).
  3) Vollständige Assistenten-Antwort speichern nach: $response_f
  4) Abschluss signalisieren: touch $done_f
[RepoLens] Warte auf $done_f … (Maschinenprotokoll: REPOLENS_CTL oben)
EOF

  local waited=0
  while [[ ! -f "$done_f" ]]; do
    if [[ "$max_wait" -gt 0 && "$waited" -ge "$max_wait" ]]; then
      printf 'REPOLENS_PHASE error\n' >&2
      printf 'REPOLENS_ERROR IDE_TIMEOUT max_wait_sec=%s waited_sec=%s\n' "$max_wait" "$waited" >&2
      local err_json
      err_json="$(jq -nc \
        --argjson v 1 \
        --arg kind "error" \
        --arg code "IDE_TIMEOUT" \
        --argjson max_wait "$max_wait" \
        --argjson waited "$waited" \
        --arg done_file "$done_f" \
        '{v: $v, kind: $kind, code: $code, max_wait_sec: $max_wait, waited_sec: $waited, done_file: $done_file}')"
      repolens_ctl_emit_json "$err_json"
      echo "REPOLENS_CURSOR_IDE_TIMEOUT after ${max_wait}s" >&2
      return 124
    fi
    sleep "$poll_sec"
    waited=$((waited + poll_sec))
  done

  if [[ ! -f "$response_f" ]] || [[ ! -s "$response_f" ]]; then
    if repolens_ide_stub_allowed; then
      printf 'REPOLENS_PHASE warn\n' >&2
      printf 'REPOLENS_ERROR IDE_MISSING_RESPONSE file=%s\n' "$response_f" >&2
      local wjson
      wjson="$(jq -nc \
        --argjson v 1 \
        --arg kind "warn" \
        --arg code "IDE_MISSING_RESPONSE" \
        --arg response_file "$response_f" \
        '{v: $v, kind: $kind, code: $code, response_file: $response_file}')"
      repolens_ctl_emit_json "$wjson"
      warn "cursor-ide: $response_f fehlt — leere Antwort (ALLOW_STUB)"
      printf '\n'
      return 0
    fi
    printf 'REPOLENS_PHASE error\n' >&2
    printf 'REPOLENS_ERROR IDE_MISSING_RESPONSE file=%s\n' "$response_f" >&2
    local miss_json
    miss_json="$(jq -nc \
      --argjson v 1 \
      --arg kind "error" \
      --arg code "IDE_MISSING_RESPONSE" \
      --arg response_file "$response_f" \
      '{v: $v, kind: $kind, code: $code, response_file: $response_file}')"
    repolens_ctl_emit_json "$miss_json"
    rm -f "$done_f"
    return 1
  fi

  if ! repolens_ide_validate_cursor_ide_response "$response_f"; then
    local _rj_min="${REPOLENS_IDE_MIN_RESPONSE_BYTES:-400}"
    [[ "$_rj_min" =~ ^[0-9]+$ ]] || _rj_min=400
    printf 'REPOLENS_PHASE error\n' >&2
    printf 'REPOLENS_ERROR IDE_RESPONSE_REJECTED file=%s min_bytes=%s\n' "$response_f" "$_rj_min" >&2
    local rj
    rj="$(jq -nc \
      --argjson v 1 \
      --arg kind "error" \
      --arg code "IDE_RESPONSE_REJECTED" \
      --arg response_file "$response_f" \
      --argjson min_bytes "$_rj_min" \
      '{v: $v, kind: $kind, code: $code, response_file: $response_file, min_bytes: $min_bytes, hint: "Write a real lens reply (see ide-prompt). Pipeline tests only: REPOLENS_IDE_ALLOW_STUB=1"}')"
    repolens_ctl_emit_json "$rj"
    rm -f "$done_f" "$response_f"
    echo "REPOLENS_IDE_RESPONSE_REJECTED: Antwort zu kurz, leer oder Stub-Platzhalter. Echte Analyse in $response_f erforderlich (oder REPOLENS_IDE_ALLOW_STUB=1)." >&2
    return 1
  fi

  printf 'REPOLENS_PHASE handoff_done\n' >&2
  local ok_json
  ok_json="$(jq -nc \
    --argjson v 1 \
    --arg kind "ide_handoff_ok" \
    --arg run_id "${REPOLENS_RUN_ID:-}" \
    --arg domain "${REPOLENS_CTL_DOMAIN:-}" \
    --arg lens "${REPOLENS_CTL_LENS_ID:-}" \
    --argjson iteration "$iteration" \
    '{v: $v, kind: $kind, run_id: $run_id, domain: $domain, lens: $lens, iteration: $iteration}')"
  repolens_ctl_emit_json "$ok_json"

  cat "$response_f"
  return 0
}
