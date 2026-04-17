#!/usr/bin/env bash
set -uo pipefail

project=""
prompt_file=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --project)
      project="${2:-}"
      shift 2
      ;;
    --prompt-file)
      prompt_file="${2:-}"
      shift 2
      ;;
    *)
      shift
      ;;
  esac
done

if [[ -z "$project" || -z "$prompt_file" ]]; then
  echo "missing required args"
  exit 2
fi

if [[ ! -f "$prompt_file" ]]; then
  echo "prompt file not found"
  exit 3
fi

echo "DONE"
