#!/usr/bin/env bash
set -uo pipefail

model=""
workspace=""
print_mode=false
prompt=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --model)
      model="${2:-}"
      shift 2
      ;;
    --model=*)
      model="${1#--model=}"
      shift
      ;;
    --workspace)
      workspace="${2:-}"
      shift 2
      ;;
    --print)
      print_mode=true
      shift
      ;;
    *)
      prompt="$1"
      shift
      ;;
  esac
done

if [[ "$print_mode" != true || -z "$workspace" || -z "$prompt" ]]; then
  echo "missing required args"
  exit 2
fi

if [[ "$model" != "auto" ]]; then
  echo "Named models unavailable Free plans can only use Auto. Switch to Auto or upgrade plans to continue."
  exit 1
fi

echo "DONE"
