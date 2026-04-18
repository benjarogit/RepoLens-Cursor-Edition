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

# Tests for issue #56: README must contain prominent warnings about
# (1) security / isolation, (2) warranty disclaimer, (3) rate limits /
# automated traffic, (4) AI cost.
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
README="$SCRIPT_DIR/README.md"

PASS=0
FAIL=0
TOTAL=0

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
  fi
}

assert_matches() {
  local desc="$1" pattern="$2" haystack="$3"
  TOTAL=$((TOTAL + 1))
  if grep -qE "$pattern" <<<"$haystack"; then
    PASS=$((PASS + 1))
    echo "  PASS: $desc"
  else
    FAIL=$((FAIL + 1))
    echo "  FAIL: $desc"
    echo "    Expected to match pattern: $pattern"
  fi
}

echo ""
echo "=== Test Suite: README warnings (issue #56) ==="
echo ""

if [[ ! -f "$README" ]]; then
  echo "FAIL: README.md not found at $README"
  exit 1
fi

readme_content="$(cat "$README")"

# Top-of-README IMPORTANT callout must precede Getting Started so first-time
# readers see it before any setup instructions.
echo "Test 1: README has a prominent top-of-file IMPORTANT callout before Getting Started"
top_block="$(awk '/^## Getting Started/{exit} {print}' "$README")"
assert_contains "top callout uses GitHub IMPORTANT block" \
  "> [!IMPORTANT]" "$top_block"
assert_contains "top callout links to Warnings & Limits anchor" \
  "(#warnings--limits)" "$top_block"

# Consolidated Warnings & Limits section
echo ""
echo "Test 2: README has a consolidated 'Warnings & Limits' section"
assert_contains "Warnings & Limits H2 heading exists" \
  "## Warnings & Limits" "$readme_content"

# Extract just the Warnings & Limits section so subsequent assertions are scoped.
warnings_section="$(awk '/^## Warnings & Limits/{flag=1} /^## Legal/{flag=0} flag' "$README")"

if [[ -z "$warnings_section" ]]; then
  TOTAL=$((TOTAL + 1))
  FAIL=$((FAIL + 1))
  echo "  FAIL: could not extract Warnings & Limits section"
fi

# (a) Security / isolation warning
echo ""
echo "Test 3: Security warning — NOT sandboxed, run on isolated environment, only own repos"
assert_contains "warns RepoLens is NOT sandboxed/hardened" \
  "NOT a sandboxed" "$warnings_section"
assert_contains "warns about prompt injection from scanned repo" \
  "Prompt injection" "$warnings_section"
assert_contains "warns about scripts in scanned repo executing" \
  "docker-compose" "$warnings_section"
assert_matches "recommends isolated VM/container" \
  "isolated VM|isolated container|dedicated.*VM|VM or container" "$warnings_section"
assert_matches "tells user to only scan own/trusted repos" \
  "[Oo]nly scan repositories you own|only scan repos you own|repositories you own" "$warnings_section"
assert_contains "links to SECURITY.md" \
  "SECURITY.md" "$warnings_section"
assert_contains "Security & Safe Use subsection exists" \
  "### Security & Safe Use" "$warnings_section"

# (b) Warranty disclaimer
echo ""
echo "Test 4: Warranty disclaimer — AS IS, at your own risk, references LICENSE"
assert_contains "uses AS IS phrasing" \
  "AS IS" "$warnings_section"
assert_contains "states no warranty of any kind" \
  "without warranty of any kind" "$warnings_section"
assert_contains "states use at your own risk" \
  "at your own risk" "$warnings_section"
assert_contains "Disclaimer subsection exists" \
  "### Disclaimer" "$warnings_section"
assert_contains "links to LICENSE for full legal text" \
  "LICENSE" "$warnings_section"

# (c) Rate limits / automated traffic
echo ""
echo "Test 5: Rate-limit warning — GitHub API, AI provider limits, ToS/abuse risk"
assert_contains "Rate Limits subsection exists" \
  "### Rate Limits" "$warnings_section"
assert_contains "warns about GitHub API rate limits" \
  "GitHub API" "$warnings_section"
assert_matches "warns about AI provider RPM/TPM limits" \
  "RPM|TPM|provider rate limit" "$warnings_section"
assert_matches "warns about ToS/abuse risk on third-party repos" \
  "[Tt]erms of [Ss]ervice|abuse|spam|flagged|suspended" "$warnings_section"
assert_contains "mentions --max-issues as a cap" \
  "--max-issues" "$warnings_section"

# (d) AI cost warning
echo ""
echo "Test 6: Cost warning — can be very expensive, references --max-cost / --dry-run"
assert_contains "Cost subsection exists" \
  "### Cost" "$warnings_section"
assert_matches "warns cost can be very expensive / hundreds of dollars" \
  "very expensive|hundreds of dollars|expensive" "$warnings_section"
assert_contains "mentions --max-cost flag" \
  "--max-cost" "$warnings_section"
assert_contains "mentions --dry-run preview" \
  "--dry-run" "$warnings_section"
assert_matches "explains scale (hundreds of agent invocations)" \
  "hundreds.*invocations|hundreds.*agent|thousands" "$warnings_section"

# Cross-reference integrity: top-of-README anchor must resolve to the new H2.
echo ""
echo "Test 7: Anchor target #warnings--limits resolves to the H2 heading"
TOTAL=$((TOTAL + 1))
if grep -qE '^## Warnings & Limits[[:space:]]*$' "$README"; then
  PASS=$((PASS + 1))
  echo "  PASS: H2 'Warnings & Limits' is present (anchor resolves)"
else
  FAIL=$((FAIL + 1))
  echo "  FAIL: H2 'Warnings & Limits' missing — top callout link would 404"
fi

# Make sure we didn't accidentally leave a duplicated 'No Warranty' subsection
# in ## Legal (the warranty content moved into Warnings & Limits).
echo ""
echo "Test 8: ## Legal section does not duplicate '### No Warranty' (moved to Warnings & Limits)"
TOTAL=$((TOTAL + 1))
legal_section="$(awk '/^## Legal/{flag=1; next} /^## /{flag=0} flag' "$README")"
if grep -qE '^### No Warranty[[:space:]]*$' <<<"$legal_section"; then
  FAIL=$((FAIL + 1))
  echo "  FAIL: ## Legal still has '### No Warranty' subsection — duplication risk"
else
  PASS=$((PASS + 1))
  echo "  PASS: ## Legal does not duplicate '### No Warranty'"
fi

# --- Summary ---
echo ""
echo "================================"
echo "Results: $PASS/$TOTAL passed, $FAIL failed"
echo "================================"

if [[ "$FAIL" -gt 0 ]]; then
  exit 1
fi
