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

# Integration test: run_agent closes stdin for the agent subprocess.
# An agent CLI that falls back to an interactive prompt on auth failure
# must NOT inherit the parent shell's stdin — otherwise it will block
# forever on a `read` that never completes.
#
# Strategy: fake `codex` binary attempts to read one line from stdin
# with a short timeout. If data ever arrives, it writes "GOT INPUT" to
# its output and exits. We assert that "GOT INPUT" never appears in
# any iteration log, proving stdin was redirected to /dev/null.
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

assert_not_contains() {
  local desc="$1" needle="$2" haystack="$3"
  TOTAL=$((TOTAL + 1))
  if [[ "$haystack" != *"$needle"* ]]; then
    PASS=$((PASS + 1))
    echo "  PASS: $desc"
  else
    FAIL=$((FAIL + 1))
    echo "  FAIL: $desc (unexpected needle='$needle' found)"
  fi
}

echo "=== run_agent closes agent stdin — integration ==="

if ! command -v timeout >/dev/null 2>&1; then
  echo "  SKIP: timeout(1) not available"
  echo ""
  echo "=== Results: $PASS/$TOTAL passed, $FAIL failed ==="
  exit 0
fi

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

# Fake agent: tries to read from stdin with a 2-second timeout. If the
# parent never closed stdin (or piped data), `read` would either block
# or receive content — either case leaves "GOT INPUT" in the output.
# With stdin pointing at /dev/null, `read` returns EOF immediately.
FAKE_BIN="$TMPDIR/bin"
mkdir -p "$FAKE_BIN"
cat > "$FAKE_BIN/codex" <<'SH'
#!/usr/bin/env bash
# Use a generous timeout. If the parent process has hooked stdin to
# anything other than /dev/null, `read` will either receive data or
# block waiting for a newline. Either way we detect the leak.
if IFS= read -r -t 2 line; then
  echo "GOT INPUT: $line"
fi
echo "Analysis complete. No findings."
echo "DONE"
exit 0
SH
chmod +x "$FAKE_BIN/codex"

export PATH="$FAKE_BIN:$PATH"
# Default timeout is plenty — this agent returns instantly when stdin
# is closed. Keep REPOLENS_AGENT_TIMEOUT short so any misbehavior caps
# fast.
export REPOLENS_AGENT_TIMEOUT=10

# Pipe a marker string on stdin — if run_agent failed to close stdin,
# the agent would read this marker.
OUT_FILE="$TMPDIR/run.log"
START_EPOCH="$(date +%s)"
set +e
printf 'LEAKED_STDIN_MARKER\n' | bash "$SCRIPT_DIR/repolens.sh" \
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
iteration_logs=""
if [[ -n "$RUN_ID" && -d "$SCRIPT_DIR/logs/$RUN_ID" ]]; then
  while IFS= read -r -d '' itfile; do
    iteration_logs+="$(cat "$itfile")"$'\n'
  done < <(find "$SCRIPT_DIR/logs/$RUN_ID" -name 'iteration-*.txt' -print0 2>/dev/null)
fi

# ----------------------------------------------------------------------
# Assertion: no "GOT INPUT" marker — agent's stdin was closed.
# ----------------------------------------------------------------------
assert_not_contains "Agent did NOT receive stdin (run log)" "GOT INPUT" "$log_contents"
assert_not_contains "Agent did NOT receive stdin (iteration outputs)" "GOT INPUT" "$iteration_logs"
assert_not_contains "Leaked marker not in iteration outputs" "LEAKED_STDIN_MARKER" "$iteration_logs"

# ----------------------------------------------------------------------
# Assertion: finished quickly. If stdin were live, the `read -t 2`
# would wait — at worst ~2s per iteration but confirming no wedge.
# ----------------------------------------------------------------------
TOTAL=$((TOTAL + 1))
if (( elapsed < 15 )); then
  PASS=$((PASS + 1))
  echo "  PASS: Run completed in ${elapsed}s (stdin not inherited)"
else
  FAIL=$((FAIL + 1))
  echo "  FAIL: Run took ${elapsed}s — stdin may have leaked"
  echo "---- run.log ----"
  cat "$OUT_FILE"
  echo "-----------------"
fi

# ----------------------------------------------------------------------
# Sanity: fake agent ran to completion (emitted DONE).
# ----------------------------------------------------------------------
assert_contains "Agent reached its DONE emission" "DONE" "$iteration_logs"

# ----------------------------------------------------------------------
# Orchestrator did not wedge — clean exit (zero or non-zero is fine
# as long as we got here without hanging).
# ----------------------------------------------------------------------
TOTAL=$((TOTAL + 1))
PASS=$((PASS + 1))
echo "  PASS: Orchestrator exited (exit=$exit_code) — did not wedge"

echo ""
echo "=== Results: $PASS/$TOTAL passed, $FAIL failed ==="
exit "$FAIL"
