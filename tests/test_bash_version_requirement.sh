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

# Tests for issues #37, #39: bash 4.0+ is a documented and enforced prerequisite.
#
# Behavioral contract:
# 1. repolens.sh aborts early with a clear message if BASH_VERSINFO[0] < 4
# 2. The runtime guard runs BEFORE any bash-4-specific syntax is evaluated
#    (so the error message surfaces, not a cryptic "syntax error")
# 3. README prerequisites table documents the 4.0+ requirement
# 4. Error message points users to `brew install bash` for macOS
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
REPOLENS="$SCRIPT_DIR/repolens.sh"
README="$SCRIPT_DIR/README.md"

PASS=0
FAIL=0
TOTAL=0

assert_matches() {
  local desc="$1" pattern="$2" haystack="$3"
  local flags="-qE"
  TOTAL=$((TOTAL + 1))
  # Here-string (not a pipe) because 'set -o pipefail' + 'grep -q' closing
  # stdin early on a large haystack yields SIGPIPE (exit 141), which would
  # make this branch mis-report a successful match as a failure.
  if [[ "$pattern" == '(?im)'* ]]; then
    flags="-qiE"
    pattern="${pattern#'(?im)'}"
  elif [[ "$pattern" == '(?i)'* ]]; then
    flags="-qiE"
    pattern="${pattern#'(?i)'}"
  fi
  if grep $flags "$pattern" <<< "$haystack"; then
    PASS=$((PASS + 1))
    echo "  PASS: $desc"
  else
    FAIL=$((FAIL + 1))
    echo "  FAIL: $desc"
    echo "    Expected to match pattern: $pattern"
  fi
}

echo ""
echo "=== Test Suite: bash 4.0+ requirement (issues #37, #39) ==="
echo ""

# =====================================================================
# 1. repolens.sh contains a BASH_VERSINFO runtime guard
# =====================================================================

echo "Test 1: repolens.sh has a BASH_VERSINFO runtime check"
repolens_head="$(head -40 "$REPOLENS")"
assert_matches "BASH_VERSINFO check present" "BASH_VERSINFO\[0\]" "$repolens_head"

echo ""
echo "Test 2: guard rejects bash < 4"
assert_matches "guard compares against 4" "BASH_VERSINFO\[0\] < 4|BASH_VERSINFO\[0\] -lt 4" "$repolens_head"

echo ""
echo "Test 3: guard produces an error message mentioning bash 4"
assert_matches "error mentions bash 4" "bash 4" "$repolens_head"

echo ""
echo "Test 4: guard gives macOS upgrade hint (brew install bash)"
assert_matches "mentions brew install bash" "brew install bash" "$repolens_head"

echo ""
echo "Test 5: guard exits non-zero on failure"
assert_matches "exits non-zero" "exit 1" "$repolens_head"

# =====================================================================
# 2. Guard runs BEFORE any bash-4-specific feature in repolens.sh
# =====================================================================

echo ""
# For ordering tests, ignore comment lines (lines starting with optional
# whitespace then '#') — only the first executable occurrence matters.
first_code_line() {
  grep -nE "$1" "$REPOLENS" | grep -vE "^[0-9]+:[[:space:]]*#" | head -1 | cut -d: -f1
}

echo "Test 6: BASH_VERSINFO guard appears before first executable 'declare -A'"
guard_line=$(first_code_line "BASH_VERSINFO\[0\]")
decl_line=$(first_code_line "declare -A")
TOTAL=$((TOTAL + 1))
if [[ -n "$guard_line" && -n "$decl_line" && "$guard_line" -lt "$decl_line" ]]; then
  PASS=$((PASS + 1))
  echo "  PASS: guard at line $guard_line precedes first 'declare -A' at line $decl_line"
else
  FAIL=$((FAIL + 1))
  echo "  FAIL: guard must precede first 'declare -A' (guard=$guard_line, decl=$decl_line)"
fi

echo ""
echo "Test 7: BASH_VERSINFO guard appears before first executable 'read -ra'"
read_line=$(first_code_line "read -ra")
TOTAL=$((TOTAL + 1))
if [[ -n "$guard_line" && -n "$read_line" && "$guard_line" -lt "$read_line" ]]; then
  PASS=$((PASS + 1))
  echo "  PASS: guard at line $guard_line precedes first 'read -ra' at line $read_line"
else
  FAIL=$((FAIL + 1))
  echo "  FAIL: guard must precede first 'read -ra' (guard=$guard_line, read=$read_line)"
fi

# =====================================================================
# 3. README prerequisites table documents bash 4.0+
# =====================================================================

echo ""
echo "Test 8: README prerequisites table lists bash 4.0+"
readme_content="$(cat "$README")"
assert_matches "README prerequisites row mentions bash 4" "\`bash\`.*4\.0" "$readme_content"

echo ""
echo "Test 9: README mentions macOS bash upgrade path"
assert_matches "README mentions 'brew install bash'" "brew install bash" "$readme_content"

# =====================================================================
# Summary
# =====================================================================

echo ""
echo "================================"
echo "Results: $PASS/$TOTAL passed, $FAIL failed"
echo "================================"

if [[ "$FAIL" -gt 0 ]]; then
  exit 1
fi
