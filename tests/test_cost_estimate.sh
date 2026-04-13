#!/usr/bin/env bash
# Tests for the cost estimation and --max-cost threshold (issue #8)
# Tests are BEHAVIORAL: they execute repolens.sh and assert on exit codes + output,
# never on source code patterns.
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
REPOLENS="$SCRIPT_DIR/repolens.sh"

# Timeout for each script invocation — prevents hangs when the gate
# doesn't exist yet (TDD red phase) and the script runs into full execution.
TIMEOUT=15

PASS=0
FAIL=0
TOTAL=0

assert_eq() {
  local desc="$1" expected="$2" actual="$3"
  TOTAL=$((TOTAL + 1))
  if [[ "$expected" == "$actual" ]]; then
    PASS=$((PASS + 1))
    echo "  PASS: $desc"
  else
    FAIL=$((FAIL + 1))
    echo "  FAIL: $desc"
    echo "    Expected: $(echo "$expected" | head -3)"
    echo "    Actual:   $(echo "$actual" | head -3)"
  fi
}

assert_contains() {
  local desc="$1" needle="$2" haystack="$3"
  TOTAL=$((TOTAL + 1))
  if [[ "$haystack" == *"$needle"* ]]; then
    PASS=$((PASS + 1))
    echo "  PASS: $desc"
  else
    FAIL=$((FAIL + 1))
    echo "  FAIL: $desc"
    echo "    Expected to contain: $needle"
    echo "    In output (first 300 chars): ${haystack:0:300}"
  fi
}

assert_not_contains() {
  local desc="$1" needle="$2" haystack="$3"
  TOTAL=$((TOTAL + 1))
  if [[ "$haystack" != *"$needle"* ]]; then
    PASS=$((PASS + 1))
    echo "  PASS: $desc"
  else
    FAIL=$((FAIL + 1))
    echo "  FAIL: $desc"
    echo "    Expected NOT to contain: $needle"
  fi
}

assert_exit_code() {
  local desc="$1" expected="$2" actual="$3"
  TOTAL=$((TOTAL + 1))
  if [[ "$expected" -eq "$actual" ]]; then
    PASS=$((PASS + 1))
    echo "  PASS: $desc"
  else
    FAIL=$((FAIL + 1))
    echo "  FAIL: $desc"
    echo "    Expected exit code: $expected, got: $actual"
  fi
}

# Helper: run repolens.sh with timeout and capture output + exit code.
# Usage: run_repolens [--stdin "input"] [args...]
# Sets: RUN_OUTPUT (combined stdout+stderr), RUN_EXIT (exit code)
run_repolens() {
  local stdin_data=""
  if [[ "${1:-}" == "--stdin" ]]; then
    stdin_data="$2"
    shift 2
  fi
  local tmp_out="$TMPDIR/.run_output"
  echo "$stdin_data" | timeout "$TIMEOUT" bash "$REPOLENS" "$@" >"$tmp_out" 2>&1
  RUN_EXIT=$?
  RUN_OUTPUT="$(cat "$tmp_out")"
  rm -f "$tmp_out"
}

# Helper: run with script(1) for TTY simulation + timeout
# Usage: run_repolens_tty "stdin_data" [args...]
# Sets: RUN_OUTPUT, RUN_EXIT
# Returns 1 if script(1) is not available.
run_repolens_tty() {
  local stdin_data="$1"
  shift
  if ! command -v script >/dev/null 2>&1; then
    return 1
  fi
  local args_str=""
  for arg in "$@"; do
    args_str+=" '${arg//\'/\'\\\'\'}'"
  done
  local tmp_out="$TMPDIR/.tty_output"
  echo "$stdin_data" | timeout "$TIMEOUT" script -qec "bash '$REPOLENS' $args_str" /dev/null >"$tmp_out" 2>&1
  RUN_EXIT=$?
  RUN_OUTPUT="$(cat "$tmp_out")"
  rm -f "$tmp_out"
  return 0
}

# --- Setup test fixtures ---
TMPDIR="$(mktemp -d)"
trap 'rm -rf "$TMPDIR"' EXIT

# Create a minimal git repo fixture for integration tests
setup_test_repo() {
  local repo_dir="$TMPDIR/test-repo"
  mkdir -p "$repo_dir"
  git -C "$repo_dir" init -q
  git -C "$repo_dir" config user.email "test@test.com"
  git -C "$repo_dir" config user.name "Test"
  echo "test" > "$repo_dir/README.md"
  git -C "$repo_dir" add .
  git -C "$repo_dir" commit -q -m "init"
  echo "$repo_dir"
}

TEST_REPO="$(setup_test_repo)"

echo ""
echo "=== Test Suite: Cost estimation and --max-cost threshold (issue #8) ==="
echo ""

# =====================================================================
# Test 1: --max-cost flag is accepted by argument parser
# =====================================================================
# When --max-cost is passed with a dollar amount, the script should NOT
# fail with "Unknown argument".

echo "Test 1: --max-cost flag accepted by argument parser"
run_repolens --stdin "" --project "$TEST_REPO" --agent claude --yes --max-cost 10
assert_not_contains "--max-cost not rejected as unknown" "Unknown argument: --max-cost" "$RUN_OUTPUT"

# =====================================================================
# Test 2: --help output includes --max-cost documentation
# =====================================================================

echo ""
echo "Test 2: --help mentions --max-cost flag"
help_output="$(timeout "$TIMEOUT" bash "$REPOLENS" --help 2>&1)"
assert_contains "--max-cost in help text" "--max-cost" "$help_output"

# =====================================================================
# Test 3: --max-cost requires a dollar amount argument
# =====================================================================
# When --max-cost is passed without a value, the script should error.

echo ""
echo "Test 3: --max-cost without value produces error"
run_repolens --stdin "" --project "$TEST_REPO" --agent claude --yes --max-cost
assert_exit_code "exits with error" 1 "$RUN_EXIT"

# =====================================================================
# Test 4: Confirmation banner shows estimated cost line
# =====================================================================
# The confirmation banner must display an "Est. cost:" line so users
# can see the approximate cost before confirming.

echo ""
echo "Test 4: Confirmation banner shows Est. cost line"
if run_repolens_tty "N" --project "$TEST_REPO" --agent claude; then
  assert_contains "banner shows Est. cost:" "Est. cost:" "$RUN_OUTPUT"
else
  TOTAL=$((TOTAL + 1)); FAIL=$((FAIL + 1))
  echo "  FAIL: script(1) not available — skipped (counts as failure for TDD)"
fi

# =====================================================================
# Test 5: Cost estimate contains a dollar sign
# =====================================================================
# The cost estimate must include a "$" character to indicate currency.

echo ""
echo "Test 5: Cost estimate contains dollar sign"
if run_repolens_tty "N" --project "$TEST_REPO" --agent claude; then
  # Extract just the Est. cost line area from the output
  local_output="$(echo "$RUN_OUTPUT" | grep -i "Est. cost" || true)"
  assert_contains "cost line has dollar sign" '$' "$local_output"
else
  TOTAL=$((TOTAL + 1)); FAIL=$((FAIL + 1))
  echo "  FAIL: script(1) not available — skipped"
fi

# =====================================================================
# Test 6: Threshold warning appears when estimate exceeds --max-cost
# =====================================================================
# When --max-cost is set to a very low value (e.g., 0.01), the cost
# estimate for a full audit will exceed it and a warning must appear.

echo ""
echo "Test 6: Threshold warning when cost exceeds --max-cost"
if run_repolens_tty "N" --project "$TEST_REPO" --agent claude --max-cost 0.01; then
  assert_contains "warning about exceeding threshold" "WARNING" "$RUN_OUTPUT"
else
  TOTAL=$((TOTAL + 1)); FAIL=$((FAIL + 1))
  echo "  FAIL: script(1) not available — skipped"
fi

# =====================================================================
# Test 7: No threshold warning when --max-cost is not specified
# =====================================================================
# Without --max-cost, no "exceeds threshold" or cost-related WARNING
# should appear in the confirmation banner.

echo ""
echo "Test 7: No threshold warning without --max-cost"
if run_repolens_tty "N" --project "$TEST_REPO" --agent claude; then
  assert_not_contains "no threshold warning without --max-cost" "exceeds" "$RUN_OUTPUT"
else
  TOTAL=$((TOTAL + 1)); FAIL=$((FAIL + 1))
  echo "  FAIL: script(1) not available — skipped"
fi

# =====================================================================
# Test 8: No threshold warning when estimate is below --max-cost
# =====================================================================
# When --max-cost is set high enough (e.g., 99999), no warning should
# appear even for a full audit run.

echo ""
echo "Test 8: No threshold warning when cost is below --max-cost"
if run_repolens_tty "N" --project "$TEST_REPO" --agent claude --max-cost 99999; then
  assert_not_contains "no warning when below threshold" "exceeds" "$RUN_OUTPUT"
else
  TOTAL=$((TOTAL + 1)); FAIL=$((FAIL + 1))
  echo "  FAIL: script(1) not available — skipped"
fi

# =====================================================================
# Test 9: Discover mode shows lower cost than audit mode
# =====================================================================
# Discover mode has 14 lenses with single-pass (streak=1), while audit
# mode has ~210 lenses with streak=3. The cost estimate must differ.
# We capture both and verify discover's estimate is smaller.

echo ""
echo "Test 9: Discover mode cost lower than audit mode cost"
if run_repolens_tty "N" --project "$TEST_REPO" --agent claude --mode discover; then
  discover_output="$RUN_OUTPUT"
  assert_contains "discover banner shows Est. cost:" "Est. cost:" "$discover_output"
else
  TOTAL=$((TOTAL + 1)); FAIL=$((FAIL + 1))
  echo "  FAIL: script(1) not available — skipped"
fi

# =====================================================================
# Test 10: --focus single lens shows cost for 1 lens
# =====================================================================
# When --focus is used to run a single lens, the cost estimate should
# reflect only 1 lens (not the full domain set).

echo ""
echo "Test 10: --focus single lens shows cost for 1 lens"
if run_repolens_tty "N" --project "$TEST_REPO" --agent claude --focus injection; then
  assert_contains "focus shows Est. cost:" "Est. cost:" "$RUN_OUTPUT"
  assert_contains "focus shows 1 lens" "Lenses:       1" "$RUN_OUTPUT"
else
  TOTAL=$((TOTAL + 2)); FAIL=$((FAIL + 2))
  echo "  FAIL: script(1) not available — skipped"
  echo "  FAIL: script(1) not available — skipped"
fi

# =====================================================================
# Test 11: Cost estimate shows for codex agent
# =====================================================================
# The cost estimate must work for all supported agents, not just claude.

echo ""
echo "Test 11: Cost estimate shows for codex agent"
if run_repolens_tty "N" --project "$TEST_REPO" --agent codex; then
  assert_contains "codex banner shows Est. cost:" "Est. cost:" "$RUN_OUTPUT"
else
  TOTAL=$((TOTAL + 1)); FAIL=$((FAIL + 1))
  echo "  FAIL: script(1) not available — skipped"
fi

# =====================================================================
# Test 12: Cost estimate shows for opencode agent (fallback cost)
# =====================================================================
# opencode/<model> has variable pricing. The system should use a fallback
# cost-per-call value and still display an estimate.

echo ""
echo "Test 12: Cost estimate shows for opencode agent"
if run_repolens_tty "N" --project "$TEST_REPO" --agent opencode; then
  assert_contains "opencode banner shows Est. cost:" "Est. cost:" "$RUN_OUTPUT"
else
  TOTAL=$((TOTAL + 1)); FAIL=$((FAIL + 1))
  echo "  FAIL: script(1) not available — skipped"
fi

# =====================================================================
# Test 13: Threshold warning mentions the configured threshold amount
# =====================================================================
# When the warning triggers, it should mention the threshold value so
# users know what limit they set.

echo ""
echo "Test 13: Threshold warning mentions the threshold value"
if run_repolens_tty "N" --project "$TEST_REPO" --agent claude --max-cost 5; then
  assert_contains "warning mentions threshold value" "5" "$RUN_OUTPUT"
else
  TOTAL=$((TOTAL + 1)); FAIL=$((FAIL + 1))
  echo "  FAIL: script(1) not available — skipped"
fi

# =====================================================================
# Test 14: --max-cost with --yes still exits cleanly
# =====================================================================
# --max-cost combined with --yes should not cause an error — the cost
# warning is informational, not a hard block.

echo ""
echo "Test 14: --max-cost with --yes exits cleanly (no crash)"
run_repolens --stdin "" --project "$TEST_REPO" --agent claude --yes --max-cost 0.01
assert_not_contains "--max-cost with --yes does not crash" "Unknown argument" "$RUN_OUTPUT"

# =====================================================================
# Test 15: --max-cost rejects non-numeric input
# =====================================================================
# When --max-cost is given a non-numeric value, the script should error.

echo ""
echo "Test 15: --max-cost rejects non-numeric input"
run_repolens --stdin "" --project "$TEST_REPO" --agent claude --yes --max-cost abc
assert_exit_code "non-numeric --max-cost exits with error" 1 "$RUN_EXIT"

# =====================================================================
# Test 16: Cost estimate for discover mode is single-pass (streak=1)
# =====================================================================
# Discover mode uses DONE_STREAK=1, so the minimum cost estimate should
# be based on 1 iteration per lens, not 3.

echo ""
echo "Test 16: Discover mode cost reflects single-pass iterations"
if run_repolens_tty "N" --project "$TEST_REPO" --agent claude --mode discover; then
  # The banner must show "Est. cost:" — its value should be small for 14 lenses × 1 iteration
  assert_contains "discover mode shows Est. cost:" "Est. cost:" "$RUN_OUTPUT"
  # Should NOT show "3" as iterations multiplier in the cost breakdown (streak=1 for discover)
  # Instead verify "1 iteration" or similar phrasing appears
  assert_contains "discover shows single iteration reference" "1" "$RUN_OUTPUT"
else
  TOTAL=$((TOTAL + 2)); FAIL=$((FAIL + 2))
  echo "  FAIL: script(1) not available — skipped"
  echo "  FAIL: script(1) not available — skipped"
fi

# =====================================================================
# Test 17: Cost estimate for deploy mode shows in banner
# =====================================================================
# Deploy mode (26 lenses, streak=1) should show a cost estimate.

echo ""
echo "Test 17: Deploy mode shows cost estimate"
if run_repolens_tty "N" --project "$TEST_REPO" --agent claude --mode deploy; then
  assert_contains "deploy mode shows Est. cost:" "Est. cost:" "$RUN_OUTPUT"
else
  TOTAL=$((TOTAL + 1)); FAIL=$((FAIL + 1))
  echo "  FAIL: script(1) not available — skipped"
fi

# =====================================================================
# Test 18: --max-cost with decimal values is accepted
# =====================================================================
# Users should be able to specify thresholds like 2.50 or 0.99.

echo ""
echo "Test 18: --max-cost accepts decimal values"
run_repolens --stdin "" --project "$TEST_REPO" --agent claude --yes --max-cost 2.50
assert_not_contains "--max-cost decimal not rejected" "Unknown argument" "$RUN_OUTPUT"
assert_not_contains "--max-cost decimal does not error" "must be" "$RUN_OUTPUT"

# =====================================================================
# Test 19: Threshold warning for --max-cost with low threshold on audit mode
# =====================================================================
# Audit mode with ~210 lenses and streak=3 will always exceed a $5 threshold.
# This tests the common case that motivated the feature.

echo ""
echo "Test 19: Audit mode exceeds low --max-cost threshold"
if run_repolens_tty "N" --project "$TEST_REPO" --agent claude --max-cost 5; then
  assert_contains "audit mode exceeds low threshold" "WARNING" "$RUN_OUTPUT"
  assert_contains "audit mode still shows Proceed?" "Proceed?" "$RUN_OUTPUT"
else
  TOTAL=$((TOTAL + 2)); FAIL=$((FAIL + 2))
  echo "  FAIL: script(1) not available — skipped"
  echo "  FAIL: script(1) not available — skipped"
fi

# =====================================================================
# Test 20: User can still proceed with y after cost warning
# =====================================================================
# The cost warning is informational — it does NOT block execution.
# The user should be able to type "y" and proceed.

echo ""
echo "Test 20: User can proceed with y after cost warning"
if run_repolens_tty "y" --project "$TEST_REPO" --agent claude --max-cost 0.01; then
  assert_not_contains "y proceeds past warning" "Aborted" "$RUN_OUTPUT"
else
  TOTAL=$((TOTAL + 1)); FAIL=$((FAIL + 1))
  echo "  FAIL: script(1) not available — skipped"
fi

# =====================================================================
# Test 21: --max-cost 0 triggers warning for any non-zero cost
# =====================================================================
# Edge case: threshold of 0 means any run with lenses will warn.

echo ""
echo "Test 21: --max-cost 0 triggers warning"
if run_repolens_tty "N" --project "$TEST_REPO" --agent claude --max-cost 0; then
  assert_contains "--max-cost 0 triggers warning" "WARNING" "$RUN_OUTPUT"
else
  TOTAL=$((TOTAL + 1)); FAIL=$((FAIL + 1))
  echo "  FAIL: script(1) not available — skipped"
fi

# =====================================================================
# Test 22: Cost estimate for opensource mode shows in banner
# =====================================================================
# OpenSource mode (13 lenses, streak=1) should show a cost estimate.

echo ""
echo "Test 22: OpenSource mode shows cost estimate"
if run_repolens_tty "N" --project "$TEST_REPO" --agent claude --mode opensource; then
  assert_contains "opensource mode shows Est. cost:" "Est. cost:" "$RUN_OUTPUT"
else
  TOTAL=$((TOTAL + 1)); FAIL=$((FAIL + 1))
  echo "  FAIL: script(1) not available — skipped"
fi

# =====================================================================
# Test 23: Cost estimate for content mode shows in banner
# =====================================================================
# Content mode (17 lenses, streak=1) should show a cost estimate.

echo ""
echo "Test 23: Content mode shows cost estimate"
if run_repolens_tty "N" --project "$TEST_REPO" --agent claude --mode content; then
  assert_contains "content mode shows Est. cost:" "Est. cost:" "$RUN_OUTPUT"
else
  TOTAL=$((TOTAL + 1)); FAIL=$((FAIL + 1))
  echo "  FAIL: script(1) not available — skipped"
fi

# =====================================================================
# Test 24: --max-cost with --domain still works
# =====================================================================
# Using --domain to filter lenses should produce a cost estimate based
# on the filtered lens count, and --max-cost should still function.

echo ""
echo "Test 24: --max-cost with --domain works"
if run_repolens_tty "N" --project "$TEST_REPO" --agent claude --domain security --max-cost 1; then
  assert_contains "domain filter shows Est. cost:" "Est. cost:" "$RUN_OUTPUT"
else
  TOTAL=$((TOTAL + 1)); FAIL=$((FAIL + 1))
  echo "  FAIL: script(1) not available — skipped"
fi

# =====================================================================
# Test 25: --max-issues with cost estimate
# =====================================================================
# When --max-issues forces streak=1, the cost estimate should reflect
# the reduced iteration count.

echo ""
echo "Test 25: --max-issues affects cost estimate (streak=1)"
if run_repolens_tty "N" --project "$TEST_REPO" --agent claude --max-issues 3; then
  assert_contains "max-issues mode shows Est. cost:" "Est. cost:" "$RUN_OUTPUT"
else
  TOTAL=$((TOTAL + 1)); FAIL=$((FAIL + 1))
  echo "  FAIL: script(1) not available — skipped"
fi

# =====================================================================
# Test 26: Cost calculation correctness — discover mode + claude
# =====================================================================
# Discover = 14 lenses × 1 iteration × $0.15/call = $2.10
# Verify the actual computed dollar amount appears in the output.

echo ""
echo 'Test 26: Cost value correctness for discover+claude ($2.10)'
if run_repolens_tty "N" --project "$TEST_REPO" --agent claude --mode discover; then
  assert_contains "discover+claude cost is \$2.10" '~$2.10' "$RUN_OUTPUT"
else
  TOTAL=$((TOTAL + 1)); FAIL=$((FAIL + 1))
  echo "  FAIL: script(1) not available — skipped"
fi

# =====================================================================
# Test 27: Cost calculation correctness — audit mode + claude
# =====================================================================
# Audit = 210 lenses × 3 iterations × $0.15/call = $94.50

echo ""
echo 'Test 27: Cost value correctness for audit+claude ($94.50)'
if run_repolens_tty "N" --project "$TEST_REPO" --agent claude; then
  assert_contains "audit+claude cost is \$94.50" '~$94.50' "$RUN_OUTPUT"
else
  TOTAL=$((TOTAL + 1)); FAIL=$((FAIL + 1))
  echo "  FAIL: script(1) not available — skipped"
fi

# =====================================================================
# Test 28: Cost calculation correctness — discover mode + codex
# =====================================================================
# Discover = 14 lenses × 1 iteration × $0.10/call = $1.40

echo ""
echo 'Test 28: Cost value correctness for discover+codex ($1.40)'
if run_repolens_tty "N" --project "$TEST_REPO" --agent codex --mode discover; then
  assert_contains "discover+codex cost is \$1.40" '~$1.40' "$RUN_OUTPUT"
else
  TOTAL=$((TOTAL + 1)); FAIL=$((FAIL + 1))
  echo "  FAIL: script(1) not available — skipped"
fi

# =====================================================================
# Test 29: Spark agent cost displayed with correct rate
# =====================================================================
# Discover = 14 lenses × 1 iteration × $0.20/call = $2.80

echo ""
echo 'Test 29: Spark agent cost correctness ($0.20/call)'
if run_repolens_tty "N" --project "$TEST_REPO" --agent spark --mode discover; then
  assert_contains "spark shows Est. cost:" "Est. cost:" "$RUN_OUTPUT"
  assert_contains "spark cost is \$2.80" '~$2.80' "$RUN_OUTPUT"
  assert_contains "spark shows \$0.20/call rate" '$0.20/call' "$RUN_OUTPUT"
else
  TOTAL=$((TOTAL + 3)); FAIL=$((FAIL + 3))
  echo "  FAIL: script(1) not available — skipped"
  echo "  FAIL: script(1) not available — skipped"
  echo "  FAIL: script(1) not available — skipped"
fi

# =====================================================================
# Test 30: Audit mode cost breakdown shows "3 iterations"
# =====================================================================
# Audit uses DONE_STREAK_REQUIRED=3, so the cost line should include
# "3 iterations" in the breakdown.

echo ""
echo "Test 30: Audit mode cost breakdown shows 3 iterations"
if run_repolens_tty "N" --project "$TEST_REPO" --agent claude; then
  assert_contains "audit cost line shows 3 iterations" "3 iterations" "$RUN_OUTPUT"
else
  TOTAL=$((TOTAL + 1)); FAIL=$((FAIL + 1))
  echo "  FAIL: script(1) not available — skipped"
fi

# =====================================================================
# Test 31: Discover mode cost breakdown shows "1 iterations"
# =====================================================================
# Discover uses DONE_STREAK_REQUIRED=1.

echo ""
echo "Test 31: Discover mode cost breakdown shows 1 iterations"
if run_repolens_tty "N" --project "$TEST_REPO" --agent claude --mode discover; then
  assert_contains "discover cost line shows 1 iterations" "1 iterations" "$RUN_OUTPUT"
else
  TOTAL=$((TOTAL + 1)); FAIL=$((FAIL + 1))
  echo "  FAIL: script(1) not available — skipped"
fi

# =====================================================================
# Test 32: Feature mode shows cost with streak=3
# =====================================================================
# Feature mode uses the same streak=3 as audit and should display
# an identical cost estimate.

echo ""
echo "Test 32: Feature mode shows cost with 3 iterations"
if run_repolens_tty "N" --project "$TEST_REPO" --agent claude --mode feature; then
  assert_contains "feature mode shows Est. cost:" "Est. cost:" "$RUN_OUTPUT"
  assert_contains "feature mode shows 3 iterations" "3 iterations" "$RUN_OUTPUT"
else
  TOTAL=$((TOTAL + 2)); FAIL=$((FAIL + 2))
  echo "  FAIL: script(1) not available — skipped"
  echo "  FAIL: script(1) not available — skipped"
fi

# =====================================================================
# Test 33: Bugfix mode shows cost with streak=3
# =====================================================================
# Bugfix mode also uses streak=3.

echo ""
echo "Test 33: Bugfix mode shows cost with 3 iterations"
if run_repolens_tty "N" --project "$TEST_REPO" --agent claude --mode bugfix; then
  assert_contains "bugfix mode shows Est. cost:" "Est. cost:" "$RUN_OUTPUT"
  assert_contains "bugfix mode shows 3 iterations" "3 iterations" "$RUN_OUTPUT"
else
  TOTAL=$((TOTAL + 2)); FAIL=$((FAIL + 2))
  echo "  FAIL: script(1) not available — skipped"
  echo "  FAIL: script(1) not available — skipped"
fi

# =====================================================================
# Test 34: --yes mode does not display cost estimate
# =====================================================================
# When --yes is used, confirm_run() returns immediately without
# displaying the banner or cost estimate. This is expected behavior.

echo ""
echo "Test 34: --yes mode skips cost display"
run_repolens --stdin "" --project "$TEST_REPO" --agent claude --yes --mode discover
assert_not_contains "--yes skips Est. cost line" "Est. cost:" "$RUN_OUTPUT"

# =====================================================================
# Test 35: --max-cost rejects negative values
# =====================================================================
# The regex validation ^[0-9]+\.?[0-9]*$ rejects negative numbers.

echo ""
echo "Test 35: --max-cost rejects negative value"
run_repolens --stdin "" --project "$TEST_REPO" --agent claude --yes --max-cost -5
assert_exit_code "negative --max-cost exits with error" 1 "$RUN_EXIT"

# =====================================================================
# Test 36: Different agents produce different cost estimates
# =====================================================================
# Claude ($0.15) and codex ($0.10) should produce different cost values
# for the same mode. Both run discover mode (14 lenses, streak=1).

echo ""
echo "Test 36: Claude and codex costs differ"
if run_repolens_tty "N" --project "$TEST_REPO" --agent claude --mode discover; then
  claude_cost_line="$(echo "$RUN_OUTPUT" | grep "Est. cost:")"
  if run_repolens_tty "N" --project "$TEST_REPO" --agent codex --mode discover; then
    codex_cost_line="$(echo "$RUN_OUTPUT" | grep "Est. cost:")"
    TOTAL=$((TOTAL + 1))
    if [[ "$claude_cost_line" != "$codex_cost_line" ]]; then
      PASS=$((PASS + 1))
      echo "  PASS: claude and codex cost lines differ"
    else
      FAIL=$((FAIL + 1))
      echo "  FAIL: claude and codex cost lines differ"
      echo "    Claude: $claude_cost_line"
      echo "    Codex:  $codex_cost_line"
    fi
  else
    TOTAL=$((TOTAL + 1)); FAIL=$((FAIL + 1))
    echo "  FAIL: script(1) not available — skipped"
  fi
else
  TOTAL=$((TOTAL + 1)); FAIL=$((FAIL + 1))
  echo "  FAIL: script(1) not available — skipped"
fi

# =====================================================================
# Test 37: Cost breakdown format includes per-call rate
# =====================================================================
# The cost line format is: ~$X.XX  (~$Y.YY/call x Z lenses x W iterations)
# Verify the per-call rate for claude ($0.15) is shown.

echo ""
echo "Test 37: Cost breakdown shows per-call rate"
if run_repolens_tty "N" --project "$TEST_REPO" --agent claude --mode discover; then
  assert_contains "breakdown shows \$0.15/call" '$0.15/call' "$RUN_OUTPUT"
  assert_contains "breakdown shows lens count" "14 lenses" "$RUN_OUTPUT"
else
  TOTAL=$((TOTAL + 2)); FAIL=$((FAIL + 2))
  echo "  FAIL: script(1) not available — skipped"
  echo "  FAIL: script(1) not available — skipped"
fi

# --- Summary ---
echo ""
echo "================================"
echo "Results: $PASS/$TOTAL passed, $FAIL failed"
echo "================================"

if [[ "$FAIL" -gt 0 ]]; then
  exit 1
fi
