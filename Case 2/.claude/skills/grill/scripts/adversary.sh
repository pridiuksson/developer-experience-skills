#!/usr/bin/env bash
# adversary.sh — Run the Adversary agent via the best available CLI.
# Exit codes: 0 success | 1 no prompt or CLI failed | 2 no CLI found

set -eo pipefail

PROMPT="${1:-}"
if [[ -z "$PROMPT" ]]; then PROMPT=$(cat); fi
if [[ -z "$PROMPT" ]]; then echo "Usage: adversary.sh \"<prompt>\" or pipe via stdin" >&2; exit 1; fi

if command -v command-code &>/dev/null; then
  command-code -p "$PROMPT" --max-turns 30 </dev/null && exit 0
fi

if command -v claude &>/dev/null; then
  claude -p "$PROMPT" --permission-mode dontAsk --no-session-persistence </dev/null && exit 0
fi

echo "Error: No CLI found (tried command-code, claude)." >&2
exit 2
