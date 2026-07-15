#!/usr/bin/env bash
# Print Compare + commit list for a Cursor Edition release body.
#
# Usage:
#   ci/release-commit-range.sh <tag> [end-ref]
#
# end-ref defaults to <tag> if it exists, else HEAD.
# Previous tag = newest other cursor-edition-* by creator date.

set -euo pipefail

tag="${1:-}"
end_ref="${2:-}"

if [[ -z "$tag" ]]; then
  echo "usage: $0 <cursor-edition-YYYY.MM.DD> [end-ref]" >&2
  exit 2
fi

repo_url="${REPO_URL:-https://github.com/benjarogit/RepoLens-Cursor-Edition}"
max_commits="${RELEASE_COMMIT_LIMIT:-40}"

if [[ -z "$end_ref" ]]; then
  if git rev-parse -q --verify "refs/tags/$tag" >/dev/null; then
    end_ref="$tag"
  else
    end_ref="HEAD"
  fi
fi

mapfile -t tags < <(git tag -l 'cursor-edition-*' --sort=-creatordate)

prev=""
for t in "${tags[@]}"; do
  if [[ "$t" != "$tag" ]]; then
    prev="$t"
    break
  fi
done

echo "## Commits"
echo

if [[ -z "$prev" ]]; then
  echo "No previous \`cursor-edition-*\` tag found — skipping compare range."
  exit 0
fi

echo "Compare: [\`${prev}...${tag}\`](${repo_url}/compare/${prev}...${tag})"
echo

count="$(git rev-list --count "${prev}..${end_ref}" 2>/dev/null || echo 0)"
if [[ "$count" == "0" ]]; then
  echo "_No commits between \`${prev}\` and \`${end_ref}\`._"
  exit 0
fi

if (( count > max_commits )); then
  echo "Commits since \`${prev}\` (${count} total, showing latest ${max_commits}):"
else
  echo "Commits since \`${prev}\` (${count}):"
fi
echo

git log --no-merges --pretty=format:'- [`%h`]('"${repo_url}"'/commit/%H) %s' \
  -n "$max_commits" "${prev}..${end_ref}"
echo
echo

if (( count > max_commits )); then
  echo "_…and $((count - max_commits)) older commits in the [full compare](${repo_url}/compare/${prev}...${tag})._"
  echo
fi
