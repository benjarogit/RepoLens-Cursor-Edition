#!/usr/bin/env bash
# Copyright 2025-2026 benjarogit / Sunny C. (RepoLens Cursor Edition)
#
# Asserts --domain + --focus pins duplicate lens ids (dependency-management).
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DOMAINS_FILE="$SCRIPT_DIR/config/domains.json"

die() {
  printf 'test_focus_domain_pin: %s\n' "$*" >&2
  exit 1
}

_jq_mode_domain_filter='
  (if $mode == "discover" then select(.mode == "discover")
   elif $mode == "deploy" then select(.mode == "deploy")
   elif $mode == "opensource" then select(.mode == "opensource")
   elif $mode == "content" then select(.mode == "content")
   else select(.mode != "discover" and .mode != "deploy" and .mode != "opensource" and .mode != "content")
   end)
'

pin_domain_lens() {
  local dom="$1" lens="$2"
  jq -r --arg d "$dom" --arg lens "$lens" --arg mode "audit" \
    ".domains[] | $_jq_mode_domain_filter | select(.id == \$d) | select(.lenses[] == \$lens) | .id + \"/\" + \$lens" "$DOMAINS_FILE" | head -1
}

o="$(pin_domain_lens maintainability dependency-management)"
[[ "$o" == "maintainability/dependency-management" ]] || die "maintainability pin got: $o"

o="$(pin_domain_lens devops dependency-management)"
[[ "$o" == "devops/dependency-management" ]] || die "devops pin got: $o"

empty="$(jq -r --arg lens "dependency-management" --arg d "security" --arg mode "audit" \
  ".domains[] | $_jq_mode_domain_filter | select(.id == \$d) | select(.lenses[] == \$lens) | .id" "$DOMAINS_FILE" | head -1)"
[[ -z "$empty" ]] || die "expected empty pin for security/dependency-management, got: $empty"

echo "test_focus_domain_pin: OK"
