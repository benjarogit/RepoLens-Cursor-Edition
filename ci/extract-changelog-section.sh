#!/usr/bin/env bash
# Extract one Cursor Edition section from CHANGELOG.md for GitHub Releases.
#
# Usage:
#   ci/extract-changelog-section.sh <YYYY.MM.DD> [CHANGELOG.md]
#   ci/extract-changelog-section.sh cursor-edition-YYYY.MM.DD [CHANGELOG.md]
#
# Prints the section body (without the ## heading). Exit 1 if missing/empty.

set -euo pipefail

raw="${1:-}"
changelog="${2:-CHANGELOG.md}"

if [[ -z "$raw" ]]; then
  echo "usage: $0 <YYYY.MM.DD|cursor-edition-YYYY.MM.DD> [CHANGELOG.md]" >&2
  exit 2
fi

if [[ "$raw" == cursor-edition-* ]]; then
  date="${raw#cursor-edition-}"
else
  date="$raw"
fi

if [[ ! "$date" =~ ^[0-9]{4}\.[0-9]{2}\.[0-9]{2}$ ]]; then
  echo "error: expected date YYYY.MM.DD, got: $date" >&2
  exit 2
fi

if [[ ! -f "$changelog" ]]; then
  echo "error: changelog not found: $changelog" >&2
  exit 1
fi

# Match: ## [Cursor Edition 2026.07.15] - 2026-07-15  (date suffix optional)
heading_re="^## \\[Cursor Edition ${date}\\]"

if ! grep -qE "$heading_re" "$changelog"; then
  echo "error: no CHANGELOG section for Cursor Edition ${date}" >&2
  echo "Add a heading like: ## [Cursor Edition ${date}] - ${date//./-}" >&2
  exit 1
fi

awk -v date="$date" '
  BEGIN { want = "Cursor Edition " date }
  /^## \[/ {
    if (in_section) exit
    title = $0
    sub(/^## \[/, "", title)
    sub(/\].*$/, "", title)
    if (title == want) {
      in_section = 1
      next
    }
  }
  in_section { print }
' "$changelog" | sed -e 's/[[:space:]]*$//' -e '/./,$!d' | awk '
  NF { seen = 1 }
  seen { print }
' >"${TMPDIR:-/tmp}/repolens-changelog-section.$$"

if [[ ! -s "${TMPDIR:-/tmp}/repolens-changelog-section.$$" ]]; then
  rm -f "${TMPDIR:-/tmp}/repolens-changelog-section.$$"
  echo "error: CHANGELOG section for Cursor Edition ${date} is empty" >&2
  exit 1
fi

cat "${TMPDIR:-/tmp}/repolens-changelog-section.$$"
rm -f "${TMPDIR:-/tmp}/repolens-changelog-section.$$"
