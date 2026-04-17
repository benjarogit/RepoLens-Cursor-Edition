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

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$SCRIPT_DIR/lib/core.sh"
source "$SCRIPT_DIR/lib/cursor_runner.sh"

PASS=0
FAIL=0
TOTAL=0

assert_ok() {
  local desc="$1"
  shift
  TOTAL=$((TOTAL + 1))
  if "$@" >/dev/null 2>&1; then
    PASS=$((PASS + 1))
    echo "  PASS: $desc"
  else
    FAIL=$((FAIL + 1))
    echo "  FAIL: $desc"
  fi
}

assert_fail_with() {
  local desc="$1" needle="$2"
  shift 2
  TOTAL=$((TOTAL + 1))
  local output=""
  if output="$("$@" 2>&1)"; then
    FAIL=$((FAIL + 1))
    echo "  FAIL: $desc (expected failure)"
    return
  fi
  if grep -q -- "$needle" <<< "$output"; then
    PASS=$((PASS + 1))
    echo "  PASS: $desc"
  else
    FAIL=$((FAIL + 1))
    echo "  FAIL: $desc (missing '$needle')"
    echo "    Output: $output"
  fi
}

assert_eq() {
  local desc="$1" expected="$2" actual="$3"
  TOTAL=$((TOTAL + 1))
  if [[ "$expected" == "$actual" ]]; then
    PASS=$((PASS + 1))
    echo "  PASS: $desc"
  else
    FAIL=$((FAIL + 1))
    echo "  FAIL: $desc (expected='$expected' actual='$actual')"
  fi
}

echo "=== Cursor Agent Integration ==="

assert_ok "validate_agent accepts cursor" validate_agent cursor
assert_fail_with "validate_agent rejects invalid backend" "Invalid agent" validate_agent invalid-agent

assert_eq "cursor runner default binary is cursor-agent" "cursor-agent" "$(cursor_runner_required_cmd)"
assert_eq "cursor runner command parser extracts first token" "mock-runner" "$(CURSOR_AGENT_RUNNER_CMD='mock-runner --flag value' cursor_runner_required_cmd)"
assert_ok "cursor runner detects --model flag when split" bash -c 'source "'"$SCRIPT_DIR"'/lib/cursor_runner.sh"; cursor_runner_has_model_flag cursor-agent --model auto'
assert_ok "cursor runner detects --model=... form" bash -c 'source "'"$SCRIPT_DIR"'/lib/cursor_runner.sh"; cursor_runner_has_model_flag cursor-agent --model=auto'
assert_eq "strip --model value form" $'cursor-agent\n--force' "$(cursor_runner_strip_model_flag cursor-agent --model gpt-5 --force)"
assert_eq "strip --model= value form" $'cursor-agent\n--force' "$(cursor_runner_strip_model_flag cursor-agent --model=gpt-5 --force)"

assert_ok "runner falls back to auto when named model rejected" bash -c '
  source "'"$SCRIPT_DIR"'/lib/core.sh"
  source "'"$SCRIPT_DIR"'/lib/cursor_runner.sh"
  out="$(CURSOR_AGENT_RUNNER_CMD="'"$SCRIPT_DIR"'/tests/fixtures/mock_cursor_runner.sh" CURSOR_AGENT_MODEL="gpt-5" run_cursor_agent "Antworte mit DONE" "'"$SCRIPT_DIR"'" 2>/dev/null)"
  grep -q "DONE" <<< "$out"
'

assert_fail_with "cursor backend enforces local-only guardrail" "--agent cursor currently supports only --local mode in Phase 1." \
  bash "$SCRIPT_DIR/repolens.sh" --project "$SCRIPT_DIR" --agent cursor --dry-run

echo ""
echo "=== Results: $PASS/$TOTAL passed, $FAIL failed ==="
exit "$FAIL"
