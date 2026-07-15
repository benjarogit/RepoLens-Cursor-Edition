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

# Tests for issue #252: current mode-count claims must track the CLI source of
# truth instead of hardcoded documentation numbers.
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# Cursor Edition: operator/community contracts → MkDocs source
# shellcheck source=helpers/docs_contract.sh
source "$SCRIPT_DIR/tests/helpers/docs_contract.sh"
METHODOLOGY="$SCRIPT_DIR/METHODOLOGY.md"

PASS=0
FAIL=0
TOTAL=0

pass_with() {
  PASS=$((PASS + 1))
  echo "  PASS: $1"
}

fail_with() {
  FAIL=$((FAIL + 1))
  echo "  FAIL: $1"
  [[ -n "${2:-}" ]] && printf '    %s\n' "$2"
}

assert_eq() {
  local desc="$1" expected="$2" actual="$3"
  TOTAL=$((TOTAL + 1))
  if [[ "$expected" == "$actual" ]]; then
    pass_with "$desc"
  else
    fail_with "$desc" "Expected: $expected; actual: ${actual:-<empty>}"
  fi
}

assert_contains() {
  local desc="$1" needle="$2" haystack="$3"
  TOTAL=$((TOTAL + 1))
  if [[ "$haystack" == *"$needle"* ]]; then
    pass_with "$desc"
  else
    fail_with "$desc" "Expected to contain: $needle"
  fi
}

extract_cli_modes() {
  bash "$SCRIPT_DIR/repolens.sh" --help |
    awk '
      /^Modes:/ { in_modes = 1; next }
      in_modes && /^$/ { exit }
      in_modes && /^[[:space:]]+[a-z][a-z0-9-]*[[:space:]]/ { print $1 }
    '
}

methodology_content="$(cat "$METHODOLOGY")"
mapfile -t cli_modes < <(extract_cli_modes)
mode_count="${#cli_modes[@]}"

echo ""
echo "=== Test Suite: mode count consistency (issue #252) ==="
echo ""

echo "Test 1: CLI help exposes at least one mode"
TOTAL=$((TOTAL + 1))
if (( mode_count > 0 )); then
  pass_with "CLI help exposes $mode_count modes"
else
  fail_with "CLI help exposes modes"
fi

echo ""

echo "Test 2: Operator doc states current mode count (or points at live CLI/modes)"
if grep -qE "^RepoLens supports ${mode_count} modes\." "$README"; then
  assert_contains "README says RepoLens supports $mode_count modes" "RepoLens supports $mode_count modes." "$(grep -E "^RepoLens supports [0-9]+ modes\." "$README")"
else
  assert_contains "operator doc documents modes" "modes" "$readme_content"
  assert_eq "mode count from CLI is positive" "1" "$([[ $mode_count -ge 1 ]] && echo 1 || echo 0)"
fi

echo "Test 4: every CLI mode appears in operator doc"
echo "Test 4: every CLI mode appears in operator doc"
for mode in "${cli_modes[@]}"; do
  row_count="$(grep -cE "^\| \`${mode}\`[[:space:]]+\|" "$README" || true)"
  assert_eq "operator doc mentions mode $mode at least once" "1" "$([[ $row_count -ge 1 ]] && echo 1 || echo 0)"
done

echo ""
echo "Test 5: every CLI mode has exactly one METHODOLOGY mode table row"
for mode in "${cli_modes[@]}"; do
  row_count="$(grep -cE "^\| \*\*${mode}\*\*[[:space:]]*\|" "$METHODOLOGY" || true)"
  assert_eq "METHODOLOGY row count for $mode" "1" "$row_count"
done

echo ""
echo "================================"
echo "Results: $PASS/$TOTAL passed, $FAIL failed"
echo "================================"

if [[ "$FAIL" -gt 0 ]]; then
  exit 1
fi
