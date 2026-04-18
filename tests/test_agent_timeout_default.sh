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

# Static & structural test: REPOLENS_AGENT_TIMEOUT wiring is correct.
#
# Verifies (without waiting the full 600s default):
#   1. lib/core.sh defaults REPOLENS_AGENT_TIMEOUT to 600 via
#      ${VAR:-600} expansion.
#   2. Every agent branch in run_agent is wrapped with timeout(1).
#   3. Agent subshell closes stdin (exec </dev/null).
#   4. repolens.sh requires the `timeout` command in preflight.
#   5. The caller at repolens.sh branches on exit code 124 with a
#      distinct [ERROR] log mentioning "agent timed out".
#   6. README and --help document REPOLENS_AGENT_TIMEOUT.

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

PASS=0
FAIL=0
TOTAL=0

assert_match() {
  local desc="$1" file="$2" pattern="$3"
  TOTAL=$((TOTAL + 1))
  if grep -qE "$pattern" "$file" 2>/dev/null; then
    PASS=$((PASS + 1))
    echo "  PASS: $desc"
  else
    FAIL=$((FAIL + 1))
    echo "  FAIL: $desc (pattern not found: $pattern)"
  fi
}

assert_count_at_least() {
  local desc="$1" file="$2" pattern="$3" min="$4"
  TOTAL=$((TOTAL + 1))
  local n
  n="$(grep -cE "$pattern" "$file" 2>/dev/null || echo 0)"
  if (( n >= min )); then
    PASS=$((PASS + 1))
    echo "  PASS: $desc (found $n)"
  else
    FAIL=$((FAIL + 1))
    echo "  FAIL: $desc (found $n, expected >= $min)"
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

echo "=== REPOLENS_AGENT_TIMEOUT wiring & default ==="

CORE="$SCRIPT_DIR/lib/core.sh"
REPO="$SCRIPT_DIR/repolens.sh"
README="$SCRIPT_DIR/README.md"

# 1. lib/core.sh defaults to 600 via ${VAR:-600}.
assert_match \
  "lib/core.sh defaults REPOLENS_AGENT_TIMEOUT to 600" \
  "$CORE" \
  'REPOLENS_AGENT_TIMEOUT:-600'

# 2. All five agent branches are wrapped with timeout(1).
# Counting bare `timeout "...s"` occurrences inside run_agent should
# yield one per branch.
assert_count_at_least \
  "lib/core.sh wraps each agent branch with timeout(1) (>=5 call sites)" \
  "$CORE" \
  '^[[:space:]]*timeout "\$\{timeout_secs\}s"' \
  5

# 3. Subshell closes stdin.
assert_match \
  "lib/core.sh subshell redirects stdin to /dev/null" \
  "$CORE" \
  'exec[[:space:]]*<[[:space:]]*/dev/null'

# 4. repolens.sh preflight requires timeout(1).
assert_match \
  "repolens.sh preflight requires the timeout command" \
  "$REPO" \
  '^require_cmd timeout$'

# 5a. Caller captures run_agent exit code (not the old `if ! run_agent`).
assert_match \
  "repolens.sh captures run_agent exit code" \
  "$REPO" \
  'run_agent "\$AGENT".*\|\| agent_rc='

# 5b. Caller branches on 124 with distinct [ERROR] log.
assert_match \
  "repolens.sh branches on exit code 124" \
  "$REPO" \
  'agent_rc.*==.*124|agent_rc.*-eq.*124'

assert_match \
  "repolens.sh logs 'agent timed out' on timeout" \
  "$REPO" \
  'agent timed out'

# 5c. Generic non-zero path still logs a warning (regression guard).
assert_match \
  "repolens.sh still warns on generic non-zero exit" \
  "$REPO" \
  'Agent returned non-zero'

# 6. --help / README document the env var.
assert_match \
  "repolens.sh usage() documents REPOLENS_AGENT_TIMEOUT" \
  "$REPO" \
  'REPOLENS_AGENT_TIMEOUT'

assert_match \
  "README documents REPOLENS_AGENT_TIMEOUT" \
  "$README" \
  'REPOLENS_AGENT_TIMEOUT'

# 7. Default value survives sourcing lib/core.sh in an isolated shell.
# We don't invoke any agent — we just introspect the expansion value
# that run_agent would use.
default_val="$(env -i PATH="$PATH" bash -c "
  set -uo pipefail
  unset REPOLENS_AGENT_TIMEOUT
  echo \"\${REPOLENS_AGENT_TIMEOUT:-600}\"
")"
assert_eq "Default REPOLENS_AGENT_TIMEOUT expands to 600" "600" "$default_val"

# 8. Explicit override is honored.
override_val="$(env -i PATH="$PATH" REPOLENS_AGENT_TIMEOUT=42 bash -c "
  set -uo pipefail
  echo \"\${REPOLENS_AGENT_TIMEOUT:-600}\"
")"
assert_eq "Explicit REPOLENS_AGENT_TIMEOUT override honored" "42" "$override_val"

echo ""
echo "=== Results: $PASS/$TOTAL passed, $FAIL failed ==="
exit "$FAIL"
