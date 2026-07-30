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

# RepoLens — Cursor IDE / Composer filesystem handoff
#
# Cursor Edition (benjarogit): protocol hardened after upstream #390 / 8b19ca5,
# plus chat-loop progress, False-Green checks, and plan_mode on run_complete.
#
# Cursor IDE does not expose a supported unattended Composer API. This backend
# therefore keeps RepoLens as the state machine and uses a request-scoped,
# filesystem protocol:
#
#   request.json + prompt.md -> response.md + complete.json
#
# complete.json binds the response to a random request id and its Git object
# hash. A stale marker, a partial write, or a response for another prompt can
# never advance the lens. The handoff is intentionally sequential and local-only
# (enforced by repolens.sh).

set -uo pipefail

cursor_ide_uint() {
  local value="${1:-0}"
  [[ "$value" =~ ^[0-9]+$ ]] || value=0
  printf '%s\n' "$((10#$value))"
}

cursor_ide_safe_component() {
  local value="${1:-agent}"
  value="${value//[^A-Za-z0-9._-]/-}"
  value="${value#-}"
  value="${value%-}"
  [[ -n "$value" ]] || value="agent"
  printf '%s\n' "$value"
}

cursor_ide_new_request_id() {
  local random_hex
  random_hex="$(od -An -tx1 -N8 /dev/urandom 2>/dev/null | tr -d ' \n')"
  [[ -n "$random_hex" ]] || random_hex="${RANDOM}${RANDOM}"
  printf '%s-%s-%s\n' "$(date -u +%Y%m%dT%H%M%SZ)" "$BASHPID" "$random_hex"
}

# Write one JSON event to the durable NDJSON log and to the original terminal
# stderr preserved by repolens.sh. When this library is sourced independently,
# stderr is the fallback control channel.
cursor_ide_emit() {
  local json="$1"
  local control_fd="${REPOLENS_CURSOR_IDE_CONTROL_FD:-}"
  local ctl_log="${REPOLENS_CURSOR_IDE_CTL_LOG:-}"
  local legacy_log="${REPOLENS_CTL_LOG:-}"

  if [[ -n "$ctl_log" ]]; then
    mkdir -p "$(dirname "$ctl_log")" 2>/dev/null || true
    printf '%s\n' "$json" >> "$ctl_log" 2>/dev/null || true
  fi
  # Cursor Edition also appends to the legacy NDJSON path when set.
  if [[ -n "$legacy_log" && "$legacy_log" != "$ctl_log" ]]; then
    mkdir -p "$(dirname "$legacy_log")" 2>/dev/null || true
    printf '%s\n' "$json" >> "$legacy_log" 2>/dev/null || true
  fi

  if [[ "$control_fd" =~ ^[0-9]+$ ]] && { true >&"$control_fd"; } 2>/dev/null; then
    printf 'REPOLENS_CTL %s\n' "$json" >&"$control_fd"
  else
    printf 'REPOLENS_CTL %s\n' "$json" >&2
  fi
}

# Env aliases: REPOLENS_IDE_* (Cursor Edition) maps onto REPOLENS_CURSOR_IDE_*.
cursor_ide_apply_env_aliases() {
  if [[ -z "${REPOLENS_CURSOR_IDE_MIN_RESPONSE_BYTES:-}" && -n "${REPOLENS_IDE_MIN_RESPONSE_BYTES:-}" ]]; then
    REPOLENS_CURSOR_IDE_MIN_RESPONSE_BYTES="$REPOLENS_IDE_MIN_RESPONSE_BYTES"
  fi
  if [[ -z "${REPOLENS_CURSOR_IDE_MIN_PATH_LINE_ANCHORS:-}" && -n "${REPOLENS_IDE_MIN_PATH_LINE_ANCHORS:-}" ]]; then
    REPOLENS_CURSOR_IDE_MIN_PATH_LINE_ANCHORS="$REPOLENS_IDE_MIN_PATH_LINE_ANCHORS"
  fi
  # Edition defaults are stricter than upstream (400 bytes / 2 anchors).
  : "${REPOLENS_CURSOR_IDE_MIN_RESPONSE_BYTES:=${REPOLENS_IDE_MIN_RESPONSE_BYTES:-400}}"
  : "${REPOLENS_CURSOR_IDE_MIN_PATH_LINE_ANCHORS:=${REPOLENS_IDE_MIN_PATH_LINE_ANCHORS:-2}}"
  export REPOLENS_CURSOR_IDE_MIN_RESPONSE_BYTES REPOLENS_CURSOR_IDE_MIN_PATH_LINE_ANCHORS
}

cursor_ide_stub_allowed() {
  local allow="${REPOLENS_IDE_ALLOW_STUB-}"
  case "${allow,,}" in
    1|true|yes) return 0 ;;
  esac
  return 1
}

cursor_ide_strip_response_padding() {
  awk '
    {
      line = $0
      sub(/\r$/, "", line)
      lower = tolower(line)
    }
    lower ~ /^[[:space:]]*#[[:space:]]*(continuity|pad|filler|padding)([[:space:]]+|$)/ { next }
    { print line }
  '
}

cursor_ide_response_is_automation_template() {
  local f="$1"
  [[ -f "$f" ]] || return 1
  grep -qiE \
    'Distinct pass fingerprint|[[:space:]]uniq=[0-9a-f]{32,}|No new fileable finding with additional proof_anchors beyond|Shift evidence window and re-check related call sites|Expanded analysis for validator byte floor|Prose expansion for .+ pass .+ about|Evidence window \(iter-shifted\)|pass fingerprint uniq=' \
    "$f"
}

# Compatibility wrapper used by repolens.sh DONE-proof (≥N verified anchors).
repolens_ide_verified_anchor_files() {
  local f="$1" need="${2:-2}"
  local project="${REPOLENS_CURSOR_IDE_PROJECT:-}"
  [[ -n "$project" && -d "$project" ]] || return 0
  [[ "$need" =~ ^[0-9]+$ ]] || need=2
  local n
  n="$(cursor_ide_count_verified_anchors "$f" "$project")"
  [[ "$n" =~ ^[0-9]+$ ]] || n=0
  (( n >= need ))
}

# Count verified (preferred) or extracted path:line anchors for DONE-proof.
repolens_ide_count_path_line_anchors() {
  local f="$1"
  local project="${REPOLENS_CURSOR_IDE_PROJECT:-}"
  if [[ -n "$project" && -d "$project" ]]; then
    cursor_ide_count_verified_anchors "$f" "$project"
    return 0
  fi
  local n=0 anchor
  while IFS= read -r anchor; do
    [[ -n "$anchor" ]] || continue
    n=$((n + 1))
  done < <(cursor_ide_extract_path_line_anchors "$f")
  printf '%s\n' "$n"
}

repolens_ctl_emit_json() {
  cursor_ide_emit "$1"
}

repolens_ctl_uint() {
  cursor_ide_uint "${1:-}"
}

repolens_ctl_emit_lens_start() {
  printf 'REPOLENS_PHASE lens_start\n' >&2
  local idx total
  idx="$(cursor_ide_uint "${REPOLENS_CTL_LENS_INDEX:-${REPOLENS_CURSOR_IDE_LENS_INDEX:-}}")"
  total="$(cursor_ide_uint "${REPOLENS_CTL_LENS_TOTAL:-${REPOLENS_CURSOR_IDE_LENS_TOTAL:-}}")"
  local json
  json="$(jq -nc \
    --argjson v 1 \
    --arg kind "lens_start" \
    --arg run_id "${REPOLENS_RUN_ID:-${RUN_ID:-}}" \
    --arg domain "${REPOLENS_CTL_DOMAIN:-${REPOLENS_CURSOR_IDE_DOMAIN:-}}" \
    --arg lens "${REPOLENS_CTL_LENS_ID:-${REPOLENS_CURSOR_IDE_LENS:-}}" \
    --arg lens_name "${REPOLENS_CTL_LENS_NAME:-}" \
    --argjson lens_index "$idx" \
    --argjson lens_total "$total" \
    --argjson round "$(cursor_ide_uint "${REPOLENS_CTL_ROUND:-}")" \
    --argjson rounds_total "$(cursor_ide_uint "${REPOLENS_CTL_ROUNDS_TOTAL:-}")" \
    '{v: $v, kind: $kind, run_id: $run_id, domain: $domain, lens: $lens, lens_name: $lens_name,
      lens_index: $lens_index, lens_total: $lens_total, round: $round, rounds_total: $rounds_total}')"
  cursor_ide_emit "$json"
}

cursor_ide_response_git_hash() {
  git hash-object --no-filters "$1" 2>/dev/null
}

# Return a stable identity for one regular, non-symlink file. GNU and BSD stat
# use different switches, so support both without adding a new dependency.
cursor_ide_regular_file_identity() {
  local file="$1"
  [[ -f "$file" && ! -L "$file" ]] || return 1
  if stat -c '%d:%i:%s:%Y' -- "$file" 2>/dev/null; then
    return 0
  fi
  stat -f '%d:%i:%z:%m' "$file" 2>/dev/null
}

# Copy a handoff artifact into an invocation-private destination and prove the
# source stayed the same regular file throughout the copy. Validation and
# consumption use only this snapshot, never the Composer-writable source path.
cursor_ide_snapshot_regular_file() {
  local source="$1" destination="$2" description="${3:-handoff file}"
  local before_identity after_identity temp_snapshot

  [[ -f "$source" && ! -L "$source" ]] || {
    printf '%s\n' "$description is missing or is not a regular file"
    return 1
  }
  before_identity="$(cursor_ide_regular_file_identity "$source")" || {
    printf '%s\n' "unable to identify $description before snapshot"
    return 1
  }
  [[ ! -e "$destination" && ! -L "$destination" ]] || {
    printf '%s\n' "private snapshot destination already exists for $description"
    return 1
  }

  temp_snapshot="$(mktemp "${destination}.tmp.XXXXXX")" || {
    printf '%s\n' "unable to allocate private snapshot for $description"
    return 1
  }
  chmod 600 "$temp_snapshot" || {
    rm -f -- "$temp_snapshot"
    printf '%s\n' "unable to protect private snapshot for $description"
    return 1
  }
  if ! cp -- "$source" "$temp_snapshot"; then
    rm -f -- "$temp_snapshot"
    printf '%s\n' "unable to copy $description into a private snapshot"
    return 1
  fi
  [[ -f "$source" && ! -L "$source" ]] || {
    rm -f -- "$temp_snapshot"
    printf '%s\n' "$description changed type or became a symlink while it was being snapshotted"
    return 1
  }
  after_identity="$(cursor_ide_regular_file_identity "$source")" || {
    rm -f -- "$temp_snapshot"
    printf '%s\n' "unable to identify $description after snapshot"
    return 1
  }
  if [[ "$before_identity" != "$after_identity" ]]; then
    rm -f -- "$temp_snapshot"
    printf '%s\n' "$description was replaced or changed while it was being snapshotted"
    return 1
  fi
  [[ -f "$temp_snapshot" && ! -L "$temp_snapshot" ]] || {
    rm -f -- "$temp_snapshot"
    printf '%s\n' "private snapshot for $description is not a regular file"
    return 1
  }
  mv -- "$temp_snapshot" "$destination" || {
    rm -f -- "$temp_snapshot"
    printf '%s\n' "unable to publish private snapshot for $description"
    return 1
  }
  chmod 600 "$destination" || {
    rm -f -- "$destination"
    printf '%s\n' "unable to protect published snapshot for $description"
    return 1
  }
}

cursor_ide_extract_path_line_anchors() {
  local response_file="$1"
  [[ -f "$response_file" ]] || return 0
  grep -oE '[A-Za-z0-9_.+@/-]+\.[A-Za-z0-9]+:[0-9]+' "$response_file" 2>/dev/null \
    | sed 's#^\./##' \
    | sort -u
}

CURSOR_IDE_PROJECT_ANCHOR_FILE=""

# Resolve a citation without following any symlink component. A path that
# happens to exist through project/link -> /outside is not project evidence.
cursor_ide_resolve_project_anchor_file() {
  local project_path="$1" relative="$2"
  local project_root current component parent canonical_parent
  local -a components=()
  CURSOR_IDE_PROJECT_ANCHOR_FILE=""

  [[ -n "$relative" && "$relative" != /* ]] || return 1
  project_root="$(cd -- "$project_path" 2>/dev/null && pwd -P)" || return 1
  IFS='/' read -r -a components <<< "$relative"
  current="$project_root"
  for component in "${components[@]}"; do
    [[ -n "$component" && "$component" != "." && "$component" != ".." ]] || return 1
    current="$current/$component"
    [[ ! -L "$current" ]] || return 1
  done
  [[ -f "$current" ]] || return 1
  parent="$(dirname -- "$current")"
  canonical_parent="$(cd -- "$parent" 2>/dev/null && pwd -P)" || return 1
  case "$canonical_parent" in
    "$project_root"|"$project_root"/*) ;;
    *) return 1 ;;
  esac
  CURSOR_IDE_PROJECT_ANCHOR_FILE="$current"
}

cursor_ide_count_verified_anchors() {
  local response_file="$1" project_path="$2"
  local anchor relative cited_line count=0

  while IFS= read -r anchor; do
    [[ -n "$anchor" ]] || continue
    relative="${anchor%:*}"
    cited_line="${anchor##*:}"
    [[ "$relative" != /* && "$relative" != *"../"* && "$relative" != ".." ]] || continue
    cursor_ide_resolve_project_anchor_file "$project_path" "$relative" || continue
    if awk -v cited_line="$cited_line" '
        END {
          valid = cited_line ~ /^[0-9]+$/ && (cited_line + 0) >= 1 && (cited_line + 0) <= NR
          exit !valid
        }
      ' "$CURSOR_IDE_PROJECT_ANCHOR_FILE"; then
      count=$((count + 1))
    fi
  done < <(cursor_ide_extract_path_line_anchors "$response_file")

  printf '%s\n' "$count"
}

# cursor_ide_validate_response <response> <complete> <request-id> <project> <phase>
#
# Prints a rejection reason and returns non-zero. The caller removes only the
# completion marker, allowing Composer to correct the same response in place.
cursor_ide_validate_response() {
  local response_file="$1" complete_file="$2" request_id="$3"
  local project_path="$4" phase="$5"
  local marker_request marker_status marker_hash actual_hash

  [[ -f "$response_file" && ! -L "$response_file" ]] || {
    printf '%s\n' "response.md is missing or is not a regular file"
    return 1
  }
  [[ -f "$complete_file" && ! -L "$complete_file" ]] || {
    printf '%s\n' "complete.json is missing or is not a regular file"
    return 1
  }
  jq -e 'type == "object" and .schema_version == 1' "$complete_file" >/dev/null 2>&1 || {
    printf '%s\n' "complete.json is not a schema-version 1 JSON object"
    return 1
  }

  marker_request="$(jq -r '.request_id // empty' "$complete_file" 2>/dev/null)"
  marker_status="$(jq -r '.status // empty' "$complete_file" 2>/dev/null)"
  marker_hash="$(jq -r '.response_git_hash // empty' "$complete_file" 2>/dev/null)"
  [[ "$marker_request" == "$request_id" ]] || {
    printf '%s\n' "complete.json belongs to a different request"
    return 1
  }
  [[ "$marker_status" == "complete" ]] || {
    printf '%s\n' "complete.json status must be 'complete'"
    return 1
  }

  actual_hash="$(cursor_ide_response_git_hash "$response_file")"
  [[ -n "$actual_hash" && "$marker_hash" == "$actual_hash" ]] || {
    printf '%s\n' "response.md changed after complete.json was written"
    return 1
  }

  # shellcheck disable=SC2094 # Both readers are intentional; neither writes.
  if ! tr -d '\0' < "$response_file" | cmp -s - "$response_file"; then
    printf '%s\n' "response.md contains NUL bytes"
    return 1
  fi

  # Demo/CI escape hatch — never for real audits.
  if cursor_ide_stub_allowed; then
    return 0
  fi

  cursor_ide_apply_env_aliases

  if grep -qiE 'Automatischer Durchlauf \(Chat-Agent-Monitor\)|automated pass by monitoring agent|no substantive audit|Stub-Antwort|Chat-Agent-Monitor|stub run' "$response_file"; then
    printf '%s\n' "reply contains a known stub phrase — write a real analysis of this lens"
    return 1
  fi
  if cursor_ide_response_is_automation_template "$response_file"; then
    printf '%s\n' "reply looks like an automation/grep-worker template — describe what you actually read and concluded"
    return 1
  fi

  local pad_n
  pad_n="$(grep -ciE '^[[:space:]]*#[[:space:]]*(continuity|pad|filler|padding)([[:space:]]+|$)' "$response_file" 2>/dev/null || true)"
  [[ "$pad_n" =~ ^[0-9]+$ ]] || pad_n=0
  if (( pad_n >= 3 )); then
    printf '%s\n' "reply uses padding comment lines as byte filler — remove them and add real content"
    return 1
  fi

  local min_bytes stripped sz
  min_bytes="${REPOLENS_CURSOR_IDE_MIN_RESPONSE_BYTES:-400}"
  [[ "$min_bytes" =~ ^[1-9][0-9]*$ ]] || min_bytes=400
  stripped="$(cursor_ide_strip_response_padding <"$response_file")"
  sz="$(printf '%s' "$stripped" | wc -c)"
  sz="${sz//[[:space:]]/}"
  [[ "$sz" =~ ^[0-9]+$ ]] || sz=0
  if (( sz < min_bytes )); then
    printf 'reply is %s bytes after padding strip; at least %s are required\n' "$sz" "$min_bytes"
    return 1
  fi

  # Lens handoffs need enough evidence to make a DONE result meaningful. Meta
  # stages are schema-validated by their existing consumers instead.
  if [[ "$phase" == "lens" ]]; then
    if ! grep -qiE '^#+[[:space:]]*method\b|^##[[:space:]]*method\b|^method[[:space:]]*$' "$response_file"; then
      if ! grep -qiE '^#+[[:space:]]*(investigation|analyse|analysis|follow-ups?)\b' "$response_file"; then
        printf '%s\n' "missing a '## Method' section (or Investigation/Analysis)"
        return 1
      fi
    fi
    if ! grep -qiE '^#+[[:space:]]*findings?\b|^##[[:space:]]*findings?\b' "$response_file"; then
      printf '%s\n' "missing a '## Findings' section (use it for 'no findings' too)"
      return 1
    fi

    local min_anchors verified_anchors
    min_anchors="${REPOLENS_CURSOR_IDE_MIN_PATH_LINE_ANCHORS:-2}"
    [[ "$min_anchors" =~ ^[1-9][0-9]*$ ]] || min_anchors=2
    verified_anchors="$(cursor_ide_count_verified_anchors "$response_file" "$project_path")"
    [[ "$verified_anchors" =~ ^[0-9]+$ ]] || verified_anchors=0
    if (( verified_anchors < min_anchors )); then
      printf 'lens response cites %s in-bounds project path:line anchor(s); at least %s are required\n' \
        "$verified_anchors" "$min_anchors"
      return 1
    fi

    # Near-duplicate of previous accepted response (False-Green template reuse).
    local prev="${REPOLENS_CURSOR_IDE_PREV_RESPONSE:-}"
    if [[ -n "$prev" && -f "$prev" && -s "$prev" ]]; then
      local cur_norm prev_norm prev_stripped
      prev_stripped="$(cursor_ide_strip_response_padding <"$prev")"
      cur_norm="$(printf '%s\n' "$stripped" | sed -E \
        -e 's/iteration[[:space:]]*[0-9]+/iteration N/Ig' \
        -e 's/uniq=[0-9a-fA-F]+/uniq=X/g' \
        -e 's|^#[[:space:]]*[^/[:space:]]+/[^[:space:]]+|# lens|')"
      prev_norm="$(printf '%s\n' "$prev_stripped" | sed -E \
        -e 's/iteration[[:space:]]*[0-9]+/iteration N/Ig' \
        -e 's/uniq=[0-9a-fA-F]+/uniq=X/g' \
        -e 's|^#[[:space:]]*[^/[:space:]]+/[^[:space:]]+|# lens|')"
      if [[ -n "$cur_norm" && "$cur_norm" == "$prev_norm" ]]; then
        printf '%s\n' "reply is a near-duplicate of the previous iteration — add new evidence or answer DONE with proof"
        return 1
      fi
    fi
  fi

  return 0
}

cursor_ide_prompt_footer() {
  local request_id="$1" response_file="$2" complete_file="$3" phase="$4"
  local response_q complete_q response_tmp_q complete_tmp_q request_q
  local idx total position
  printf -v response_q '%q' "$response_file"
  printf -v complete_q '%q' "$complete_file"
  printf -v response_tmp_q '%q' "${response_file}.tmp"
  printf -v complete_tmp_q '%q' "${complete_file}.tmp"
  printf -v request_q '%q' "$request_id"

  idx="$(cursor_ide_uint "${REPOLENS_CTL_LENS_INDEX:-${REPOLENS_CURSOR_IDE_LENS_INDEX:-}}")"
  total="$(cursor_ide_uint "${REPOLENS_CTL_LENS_TOTAL:-${REPOLENS_CURSOR_IDE_LENS_TOTAL:-}}")"
  if (( total > 0 )); then
    position="lens ${idx}/${total}"
    if (( idx >= total )); then
      position="$position (last lens in the queue)"
    fi
  else
    position="lens ${REPOLENS_CURSOR_IDE_DOMAIN:-domain}/${REPOLENS_CURSOR_IDE_LENS:-?}"
  fi

  cursor_ide_apply_env_aliases

  cat <<EOF

---

## RepoLens handoff protocol — ${position}, phase ${phase}

This is a RepoLens \`${phase}\` request. Complete the prompt above in Cursor
Composer/Chat. Keep the full write-up out of chat and write it to \`response.md\`.

For a lens response, include \`## Method\` (or \`## Investigation\` /
\`## Analysis\`), \`## Findings\`, at least ${REPOLENS_CURSOR_IDE_MIN_PATH_LINE_ANCHORS} real
project-relative \`path/to/file:line\` citations whose files exist (no symlink
escapes) and whose line numbers are in-bounds, and a short evidence-based
explanation even when the result is \`DONE\` or \`NOT APPLICABLE\`.

**Chat discipline.** Post exactly one status line per handoff, for example
\`${position} ${REPOLENS_CURSOR_IDE_DOMAIN:-domain}/${REPOLENS_CURSOR_IDE_LENS:-lens} — 3 findings (1 high)\`
or \`… — no findings\`. The analysis belongs in the response file. A complete
audit is a long queue of handoffs — that is expected. Do not ask whether to
continue, do not offer to shorten the run, and do not declare it too large for
the chat.

**Lens does not fit this project?** Do not stop. Write \`NOT APPLICABLE\`, the
reason, and at least two real \`path:line\` anchors proving what you inspected.
Then finalize.

Finalize atomically only after the response is complete:

\`\`\`bash
# Write the full result to ${response_tmp_q}, then:
mv -- ${response_tmp_q} ${response_q}
response_hash="\$(git hash-object --no-filters ${response_q})"
jq -n --arg request_id ${request_q} --arg response_git_hash "\$response_hash" \\
  '{schema_version: 1, request_id: \$request_id, status: "complete", response_git_hash: \$response_git_hash}' \\
  > ${complete_tmp_q}
mv -- ${complete_tmp_q} ${complete_q}
\`\`\`

Do not reuse files or completion data from another request. RepoLens validates
the request id, response hash, response substance, and lens evidence before it
advances. On reject it removes only \`complete.json\` and waits — fix the named
\`reason\` and republish. Continue servicing \`REPOLENS_CTL\` handoffs until
\`kind\` is \`run_complete\`.
EOF
}

# run_cursor_ide_agent <prompt> <project-path> <timeout-seconds> [envelope-file]
run_cursor_ide_agent() {
  local prompt="$1" project_path="$2" timeout_seconds="${3:-1800}"
  local envelope_file="${4:-}"
  local phase request_id request_root request_dir prompt_file response_file
  local complete_file request_file prompt_tmp request_tmp

  phase="$(cursor_ide_safe_component "${REPOLENS_CURSOR_IDE_PHASE:-agent}")"
  request_id="$(cursor_ide_new_request_id)"
  cursor_ide_apply_env_aliases

  if [[ -n "$project_path" && -d "$project_path" ]]; then
    local project_abs
    project_abs="$(cd -- "$project_path" && pwd)"
    export REPOLENS_CURSOR_IDE_PROJECT="$project_abs"
    project_path="$project_abs"
  fi

  if [[ -n "${REPOLENS_CURSOR_IDE_HANDOFF_DIR:-}" ]]; then
    request_root="$REPOLENS_CURSOR_IDE_HANDOFF_DIR"
  elif [[ -n "$envelope_file" ]]; then
    request_root="$(dirname "$envelope_file")/cursor-ide"
  elif [[ -n "${LOG_BASE:-}" ]]; then
    request_root="$LOG_BASE/cursor-ide"
  else
    request_root="$project_path/.repolens-cursor-ide"
  fi

  request_dir="$request_root/$phase/$request_id"
  prompt_file="$request_dir/prompt.md"
  response_file="$request_dir/response.md"
  complete_file="$request_dir/complete.json"
  request_file="$request_dir/request.json"
  prompt_tmp="${prompt_file}.tmp"
  request_tmp="${request_file}.tmp"

  if [[ -z "${REPOLENS_CURSOR_IDE_CTL_LOG:-}" ]]; then
    REPOLENS_CURSOR_IDE_CTL_LOG="$request_root/events.ndjson"
  fi

  mkdir -p "$request_dir" || {
    printf '%s\n' "REPOLENS_CURSOR_IDE_ERROR unable to create $request_dir"
    return 1
  }
  chmod 700 "$request_dir" 2>/dev/null || true

  # Near-duplicate guard: newest sibling response under this phase root.
  unset REPOLENS_CURSOR_IDE_PREV_RESPONSE
  if [[ -d "$request_root/$phase" ]]; then
    local prev_candidate
    prev_candidate="$(
      find "$request_root/$phase" -mindepth 2 -maxdepth 2 -type f -name response.md ! -path "$request_dir/*" -printf '%T@ %p\n' 2>/dev/null \
        | sort -nr | head -1 | cut -d' ' -f2-
    )"
    if [[ -n "$prev_candidate" && -s "$prev_candidate" ]]; then
      export REPOLENS_CURSOR_IDE_PREV_RESPONSE="$prev_candidate"
    fi
  fi

  {
    printf '%s\n' "$prompt"
    cursor_ide_prompt_footer "$request_id" "$response_file" "$complete_file" "$phase"
  } > "$prompt_tmp" || return 1
  chmod 600 "$prompt_tmp" 2>/dev/null || true
  mv -f "$prompt_tmp" "$prompt_file" || return 1

  local lens_index lens_total is_last
  lens_index="$(cursor_ide_uint "${REPOLENS_CTL_LENS_INDEX:-${REPOLENS_CURSOR_IDE_LENS_INDEX:-}}")"
  lens_total="$(cursor_ide_uint "${REPOLENS_CTL_LENS_TOTAL:-${REPOLENS_CURSOR_IDE_LENS_TOTAL:-}}")"
  if (( lens_total > 0 && lens_index >= lens_total )); then is_last=true; else is_last=false; fi

  jq -n \
    --argjson schema_version 1 \
    --arg kind "ide_handoff" \
    --arg request_id "$request_id" \
    --arg run_id "${RUN_ID:-${REPOLENS_RUN_ID:-}}" \
    --arg phase "$phase" \
    --arg domain "${REPOLENS_CURSOR_IDE_DOMAIN:-${REPOLENS_CTL_DOMAIN:-}}" \
    --arg lens "${REPOLENS_CURSOR_IDE_LENS:-${REPOLENS_CTL_LENS_ID:-}}" \
    --argjson iteration "$(cursor_ide_uint "${REPOLENS_CURSOR_IDE_ITERATION:-0}")" \
    --argjson lens_index "$lens_index" \
    --argjson lens_total "$lens_total" \
    --argjson last_lens "$is_last" \
    --arg project "$project_path" \
    --arg prompt "$prompt_file" \
    --arg response "$response_file" \
    --arg complete "$complete_file" \
    '{
      schema_version: $schema_version,
      v: $schema_version,
      kind: $kind,
      request_id: $request_id,
      run_id: $run_id,
      phase: $phase,
      domain: $domain,
      lens: $lens,
      iteration: $iteration,
      lens_index: $lens_index,
      lens_total: $lens_total,
      last_lens: $last_lens,
      project: $project,
      files: {prompt: $prompt, response: $response, complete: $complete},
      instruction: "IDE/Agent: read files.prompt, execute lens, write files.response, publish hashed files.complete, keep serving until kind=run_complete"
    }' > "$request_tmp" || return 1
  chmod 600 "$request_tmp" 2>/dev/null || true
  mv -f "$request_tmp" "$request_file" || return 1

  local handoff_json
  handoff_json="$(jq -c . "$request_file")"
  cursor_ide_emit "$handoff_json"

  local control_fd="${REPOLENS_CURSOR_IDE_CONTROL_FD:-}"
  local message
  message="[RepoLens cursor-ide] Waiting for Cursor Composer: $request_file"
  if [[ "$control_fd" =~ ^[0-9]+$ ]] && { true >&"$control_fd"; } 2>/dev/null; then
    printf '%s\n' "$message" >&"$control_fd"
  else
    printf '%s\n' "$message" >&2
  fi

  local poll_seconds max_wait waited=0 rejection_reason rejection_json
  local snapshot_dir response_snapshot complete_snapshot snapshot_ok
  poll_seconds="${REPOLENS_CURSOR_IDE_POLL_SEC:-1}"
  max_wait="${REPOLENS_CURSOR_IDE_MAX_WAIT_SEC:-$timeout_seconds}"
  [[ "$poll_seconds" =~ ^[1-9][0-9]*$ ]] || poll_seconds=1
  [[ "$max_wait" =~ ^[1-9][0-9]*$ ]] || max_wait="$timeout_seconds"
  [[ "$max_wait" =~ ^[1-9][0-9]*$ ]] || max_wait=1800

  while (( waited < max_wait )); do
    if [[ -e "$complete_file" ]]; then
      snapshot_ok=true
      rejection_reason=""
      if ! snapshot_dir="$(
        mktemp -d "${TMPDIR:-/tmp}/repolens-cursor-ide.${BASHPID}.XXXXXX"
      )"; then
        rejection_reason="unable to allocate invocation-private Cursor IDE snapshot directory"
        snapshot_ok=false
      fi
      if $snapshot_ok && ! chmod 700 "$snapshot_dir"; then
        rejection_reason="unable to protect invocation-private Cursor IDE snapshot directory"
        snapshot_ok=false
      fi
      response_snapshot="$snapshot_dir/response.md"
      complete_snapshot="$snapshot_dir/complete.json"
      if $snapshot_ok; then
        if ! rejection_reason="$(
          cursor_ide_snapshot_regular_file \
            "$response_file" "$response_snapshot" "response.md"
        )"; then
          snapshot_ok=false
        elif ! rejection_reason="$(
          cursor_ide_snapshot_regular_file \
            "$complete_file" "$complete_snapshot" "complete.json"
        )"; then
          snapshot_ok=false
        elif ! rejection_reason="$(
          cursor_ide_validate_response \
            "$response_snapshot" "$complete_snapshot" \
            "$request_id" "$project_path" "$phase"
        )"; then
          snapshot_ok=false
        fi
      fi

      if $snapshot_ok; then
        local accepted_json
        accepted_json="$(jq -nc \
          --argjson schema_version 1 \
          --arg kind "ide_handoff_ok" \
          --arg request_id "$request_id" \
          --arg phase "$phase" \
          --arg domain "${REPOLENS_CURSOR_IDE_DOMAIN:-}" \
          --arg lens "${REPOLENS_CURSOR_IDE_LENS:-}" \
          --argjson iteration "$(cursor_ide_uint "${REPOLENS_CURSOR_IDE_ITERATION:-0}")" \
          '{schema_version: $schema_version, v: $schema_version, kind: $kind, request_id: $request_id, phase: $phase, domain: $domain, lens: $lens, iteration: $iteration}')"
        cursor_ide_emit "$accepted_json"
        export REPOLENS_CURSOR_IDE_PREV_RESPONSE="$response_file"
        if ! cat -- "$response_snapshot"; then
          rm -f -- "$response_snapshot" "$complete_snapshot"
          rmdir -- "$snapshot_dir" 2>/dev/null || true
          return 1
        fi
        rm -f -- "$response_snapshot" "$complete_snapshot"
        rmdir -- "$snapshot_dir" 2>/dev/null || true
        return 0
      fi

      if [[ -n "$snapshot_dir" && -d "$snapshot_dir" && ! -L "$snapshot_dir" ]]; then
        rm -f -- "$response_snapshot" "$complete_snapshot"
        rmdir -- "$snapshot_dir" 2>/dev/null || true
      fi
      rejection_json="$(jq -nc \
        --argjson schema_version 1 \
        --arg kind "error" \
        --arg code "IDE_RESPONSE_REJECTED" \
        --arg request_id "$request_id" \
        --arg reason "$rejection_reason" \
        --arg response "$response_file" \
        --arg complete "$complete_file" \
        '{
          schema_version: $schema_version,
          v: $schema_version,
          kind: $kind,
          code: $code,
          request_id: $request_id,
          reason: $reason,
          files: {response: $response, complete: $complete},
          hint: "Fix exactly what reason names, rewrite response.md, republish complete.json"
        }')"
      cursor_ide_emit "$rejection_json"
      printf 'REPOLENS_ERROR IDE_RESPONSE_REJECTED request_id=%s reason=%s\n' \
        "$request_id" "$rejection_reason" >&2
      echo "REPOLENS_IDE_RESPONSE_REJECTED: $rejection_reason. Fix $response_file and republish $complete_file." >&2
      rm -f "$complete_file"
    fi
    sleep "$poll_seconds"
    waited=$((waited + poll_seconds))
  done

  local timeout_json
  timeout_json="$(jq -nc \
    --argjson schema_version 1 \
    --arg kind "cursor_ide_timeout" \
    --arg request_id "$request_id" \
    --argjson waited_seconds "$waited" \
    --arg request "$request_file" \
    '{
      schema_version: $schema_version,
      kind: $kind,
      request_id: $request_id,
      waited_seconds: $waited_seconds,
      request_file: $request
    }')"
  cursor_ide_emit "$timeout_json"
  printf 'REPOLENS_CURSOR_IDE_TIMEOUT request_id=%s waited_seconds=%s request=%s\n' \
    "$request_id" "$waited" "$request_file"
  return 124
}

# cursor_ide_emit_run_complete <run_id> <outcome> <summary_file> [findings_dir]
cursor_ide_emit_run_complete() {
  local run_id="${1:-}" outcome="${2:-unknown}" summary_file="${3:-}" findings_dir="${4:-}"
  printf 'REPOLENS_PHASE run_complete\n' >&2
  local json
  json="$(jq -nc \
    --argjson schema_version 1 \
    --arg kind "run_complete" \
    --arg run_id "$run_id" \
    --arg outcome "$outcome" \
    --arg summary_file "$summary_file" \
    --arg findings_dir "$findings_dir" \
    --arg next_action "plan_mode" \
    '{
      schema_version: $schema_version,
      v: $schema_version,
      kind: $kind,
      run_id: $run_id,
      outcome: $outcome,
      files: {summary: $summary_file, findings_dir: $findings_dir},
      summary_file: $summary_file,
      next_action: $next_action,
      instruction: "No further handoff. Aggregate every collected finding, switch to Plan mode, run batch-grilling, and raise open decisions as interactive questions where option A is the best-practice default."
    }')"
  cursor_ide_emit "$json"
}

repolens_ctl_emit_run_complete() {
  cursor_ide_emit_run_complete "$@"
}
