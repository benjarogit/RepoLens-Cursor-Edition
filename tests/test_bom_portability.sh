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

# Tests for portable BOM stripping in read_spec_file (issue #49)
# Verifies that lib/template.sh does not use GNU-specific \x hex escapes
# in sed, which silently fail on macOS/BSD sed.
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$SCRIPT_DIR/lib/template.sh"

PASS=0
FAIL=0
TOTAL=0
TMPDIR="$(mktemp -d)"
trap 'rm -rf "$TMPDIR"' EXIT

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

echo ""
echo "=== Test Suite: BOM stripping portability (issue #49) ==="
echo ""

# --- Test 1: read_spec_file sed does not use \x hex escapes (portability) ---
# This is the core regression test. The bug is that sed '1s/^\xEF\xBB\xBF//'
# uses GNU-specific \xHH hex escapes that BSD sed treats as literal characters.
# The fix uses a bash variable with $'\xEF\xBB\xBF' and interpolates it, so
# sed receives literal BOM bytes rather than hex escape syntax.
echo "Test 1: No \\x hex escapes in sed within read_spec_file"
func_sed_lines="$(sed -n '/^read_spec_file()/,/^}/{ /sed/p; }' "$SCRIPT_DIR/lib/template.sh")"
TOTAL=$((TOTAL + 1))
if printf '%s\n' "$func_sed_lines" | grep -qF '\xEF'; then
  FAIL=$((FAIL + 1))
  printf '  FAIL: read_spec_file sed command uses \\xEF hex escape (non-portable)\n'
  echo "    Sed line: $(echo "$func_sed_lines" | head -1 | sed 's/^[[:space:]]*/    /')"
else
  PASS=$((PASS + 1))
  echo "  PASS: read_spec_file sed command does not use \\x hex escapes"
fi

# --- Test 2: BOM stripped — byte-level verification ---
# Verifies that the output starts with content bytes, not BOM bytes (EF BB BF).
echo ""
echo "Test 2: BOM stripped — byte-level verification"
printf '\xEF\xBB\xBFHello' > "$TMPDIR/bom.txt"
result="$(read_spec_file "$TMPDIR/bom.txt")"
first_bytes="$(printf '%s' "$result" | od -An -tx1 -N3 | tr -d ' ')"
TOTAL=$((TOTAL + 1))
if [[ "$first_bytes" == "48656c" ]]; then  # "Hel" in hex
  PASS=$((PASS + 1))
  echo "  PASS: first bytes are 48 65 6c ('Hel'), BOM absent"
else
  FAIL=$((FAIL + 1))
  echo "  FAIL: first bytes are '$first_bytes', expected '48656c' ('Hel')"
fi

# --- Test 3: BOM + CRLF combined (Windows-created file) ---
# Windows editors often produce files with both BOM and CRLF line endings.
echo ""
echo "Test 3: BOM + CRLF combined (Windows-created file)"
printf '\xEF\xBB\xBFLine one.\r\nLine two.\r\n' > "$TMPDIR/bom-crlf.txt"
result="$(read_spec_file "$TMPDIR/bom-crlf.txt")"
assert_eq "BOM + CRLF both stripped" "Line one.
Line two." "$result"

# --- Test 4: BOM-only file (no content after BOM) ---
echo ""
echo "Test 4: BOM-only file (no content after BOM)"
printf '\xEF\xBB\xBF' > "$TMPDIR/bom-only.txt"
result="$(read_spec_file "$TMPDIR/bom-only.txt")"
assert_eq "BOM-only file becomes empty" "" "$result"

# --- Test 5: No BOM — content passes through unchanged ---
echo ""
echo "Test 5: No BOM — content passes through unchanged"
printf 'Clean content.\nNo BOM here.\n' > "$TMPDIR/no-bom.txt"
result="$(read_spec_file "$TMPDIR/no-bom.txt")"
assert_eq "No BOM — content unchanged" "Clean content.
No BOM here." "$result"

# --- Test 6: Empty file (0 bytes) handled gracefully ---
echo ""
echo "Test 6: Empty file (0 bytes) handled gracefully"
: > "$TMPDIR/empty.txt"
result="$(read_spec_file "$TMPDIR/empty.txt")"
assert_eq "Empty file produces empty output" "" "$result"

# --- Test 7: BOM on second line is preserved (only first-line BOM stripped) ---
echo ""
echo "Test 7: BOM-like bytes on non-first line are preserved"
bom=$'\xEF\xBB\xBF'
printf 'First line.\n\xEF\xBB\xBFSecond with BOM.\n' > "$TMPDIR/bom-line2.txt"
result="$(read_spec_file "$TMPDIR/bom-line2.txt")"
expected="First line.
${bom}Second with BOM."
assert_eq "BOM on line 2 preserved" "$expected" "$result"

# --- Summary ---
echo ""
echo "================================"
echo "Results: $PASS/$TOTAL passed, $FAIL failed"
echo "================================"

if [[ "$FAIL" -gt 0 ]]; then
  exit 1
fi
