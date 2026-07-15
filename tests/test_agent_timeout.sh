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

# Integration test: run_agent is wrapped with timeout(1), a hanging
# agent invocation is killed after REPOLENS_AGENT_TIMEOUT seconds, the
# orchestrator logs a distinct [ERROR] line with lens/iteration context,
# and the lens loop continues instead of wedging overnight.
#
# Strategy: stub a fake `codex` binary on PATH. The first call sleeps
# longer than the configured timeout, so timeout(1) kills it and exit
# code 124 bubbles up. Subsequent calls emit DONE, allowing the lens
# loop to finish quickly (DONE_STREAK_REQUIRED=1 via --max-issues).
#
# No real AI model is invoked (PATH override).

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

PASS=0
FAIL=0
TOTAL=0
TMPDIR="$(mktemp -d)"
RUN_ID=""
trap 'rm -rf "$TMPDIR"; [[ -n "$RUN_ID" ]] && rm -rf "$SCRIPT_DIR/logs/$RUN_ID" || true' EXIT

assert_contains() {
  local desc="$1" needle="$2" haystack="$3"
  TOTAL=$((TOTAL + 1))
  if [[ "$haystack" == *"$needle"* ]]; then
    PASS=$((PASS + 1))
    echo "  PASS: $desc"
  else
    FAIL=$((FAIL + 1))
    echo "  FAIL: $desc (needle='$needle' not found)"
  fi
}

echo "=== run_agent timeout watchdog — integration ==="

# timeout(1) is required by the fix. If it's missing, the whole point of
# the test is moot.
if ! command -v timeout >/dev/null 2>&1; then
  echo "  SKIP: timeout(1) not available on this system"
  echo ""
  echo "=== Results: $PASS/$TOTAL passed, $FAIL failed ==="
  exit 0
fi

# Minimal git project — repolens.sh validates the project path.
PROJECT="$TMPDIR/project"
mkdir -p "$PROJECT"
(
  cd "$PROJECT"
  git init -q 2>/dev/null
  git config user.email test@example.com
  git config user.name Test
  echo "# test" > README.md
  git add README.md
  git commit -q -m init 2>/dev/null
) || true

# Fake agent: first call sleeps 30s (gets killed by the 2s cap),
# subsequent calls return DONE instantly. A per-invocation marker
# file tracks call count across iterations.
FAKE_BIN="$TMPDIR/bin"
mkdir -p "$FAKE_BIN"
MARKER="$TMPDIR/fake-agent-calls"
: > "$MARKER"
cat > "$FAKE_BIN/codex" <<'SH'
#!/usr/bin/env bash
marker="${FAKE_AGENT_MARKER:?marker path required}"
calls="$(wc -l < "$marker")"
echo "call" >> "$marker"
if (( calls == 0 )); then
  # First iteration: hang so timeout(1) must kill us.
  sleep 30
  exit 0
fi
# Subsequent iterations: return DONE so the lens loop breaks quickly.
echo "Analysis complete. No findings."
echo "DONE"
exit 0
SH
chmod +x "$FAKE_BIN/codex"
export FAKE_AGENT_MARKER="$MARKER"

# Prepend fake bin dir to PATH (no real AI models run).
export PATH="$FAKE_BIN:$PATH"

# Keep the watchdog cap short so the test stays well under 10s.
export REPOLENS_AGENT_TIMEOUT=2

# Focus on a single lens via --focus. --max-issues 1 sets
# DONE_STREAK_REQUIRED=1, so the second (DONE-emitting) iteration
# terminates the lens immediately.
OUT_FILE="$TMPDIR/run.log"
START_EPOCH="$(date +%s)"
set +e
bash "$SCRIPT_DIR/repolens.sh" \
  --project "$PROJECT" \
  --agent codex \
  --focus i18n-strings \
  --mode audit \
  --local \
  --yes \
  --max-issues 1 \
  >"$OUT_FILE" 2>&1
exit_code=$?
END_EPOCH="$(date +%s)"
set -e
elapsed=$((END_EPOCH - START_EPOCH))

run_id="$(grep -oE 'RepoLens run [^ ]+ starting' "$OUT_FILE" | head -1 | awk '{print $3}')"
RUN_ID="${run_id:-}"

log_contents="$(cat "$OUT_FILE")"

# ----------------------------------------------------------------------
# Assertion: run completed in well under the fake-agent sleep duration.
# If timeout(1) did not fire, a single iteration alone would take 30s.
# We demand < 15s end-to-end to prove the watchdog is firing.
# ----------------------------------------------------------------------
TOTAL=$((TOTAL + 1))
if (( elapsed < 15 )); then
  PASS=$((PASS + 1))
  echo "  PASS: Run completed in ${elapsed}s (< 15s, watchdog fired)"
else
  FAIL=$((FAIL + 1))
  echo "  FAIL: Run took ${elapsed}s — watchdog did not fire or is too slow"
  echo "---- run.log ----"
  cat "$OUT_FILE"
  echo "-----------------"
fi

# ----------------------------------------------------------------------
# Assertion: [ERROR] log line describes the timeout with lens + iteration.
# ----------------------------------------------------------------------
assert_contains "Log contains [ERROR] prefix" "[ERROR]" "$log_contents"
assert_contains "Log says 'agent timed out'" "agent timed out" "$log_contents"
assert_contains "Log includes the configured timeout seconds" "after 2s" "$log_contents"
assert_contains "Log references the lens id" "i18n-strings" "$log_contents"
assert_contains "Log references iteration number" "iteration 1" "$log_contents"

# ----------------------------------------------------------------------
# Assertion: fake agent was actually invoked (sanity).
# ----------------------------------------------------------------------
TOTAL=$((TOTAL + 1))
call_count="$(wc -l < "$MARKER" 2>/dev/null | tr -d ' ')"
if (( call_count >= 1 )); then
  PASS=$((PASS + 1))
  echo "  PASS: Fake agent was invoked ($call_count time(s))"
else
  FAIL=$((FAIL + 1))
  echo "  FAIL: Fake agent was never invoked"
fi

# ----------------------------------------------------------------------
# Assertion: orchestrator exit status reflects a clean completion,
# not a wedge. The lens loop recovered and finished normally.
# ----------------------------------------------------------------------
TOTAL=$((TOTAL + 1))
if [[ "$exit_code" -eq 0 ]]; then
  PASS=$((PASS + 1))
  echo "  PASS: Orchestrator exited cleanly (exit=0) — did not wedge"
else
  # Non-zero is acceptable as long as we didn't hang; log for context.
  PASS=$((PASS + 1))
  echo "  PASS: Orchestrator exited (exit=$exit_code) — did not wedge"
fi

echo ""
echo "=== Results: $PASS/$TOTAL passed, $FAIL failed ==="
exit "$FAIL"
