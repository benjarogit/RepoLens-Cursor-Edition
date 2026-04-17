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

  if command -v timeout >/dev/null 2>&1; then
    timeout "${timeout_sec}s" "${cmd_parts[@]}" --print --workspace "$project_path" "$prompt"
    local status=$?
    if [[ "$status" -eq 124 ]]; then
      echo "REPOLENS_CURSOR_TIMEOUT after ${timeout_sec}s"
    fi
    return "$status"
  fi

  "${cmd_parts[@]}" --print --workspace "$project_path" "$prompt"
}
