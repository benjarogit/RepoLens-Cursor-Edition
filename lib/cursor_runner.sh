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

# RepoLens — Cursor agent runner
#
# Phase 1 contract:
# - Supports local mode integration only (enforced by repolens.sh guardrail)
# - Uses Cursor Agent CLI in print mode with model control:
#     cursor-agent --force --approve-mcps --print --model <auto|named> --workspace <path> "<prompt>"
# - The runner command can be overridden via CURSOR_AGENT_RUNNER_CMD
# - The model can be overridden via CURSOR_AGENT_MODEL (default: auto)
# - If a named model is rejected by Cursor, RepoLens retries once with Auto.
#
# Example:
#   export CURSOR_AGENT_RUNNER_CMD="cursor-agent --force --approve-mcps"
#   export CURSOR_AGENT_MODEL="auto"
#   export CURSOR_AGENT_TIMEOUT_SEC=45

set -uo pipefail

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
