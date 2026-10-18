#!/usr/bin/env bash

input=$(cat)

# Already continuing because of this hook: let Claude stop instead of looping.
if grep -Eq '"stop_hook_active"[[:space:]]*:[[:space:]]*true' <<<"$input"; then
  exit 0
fi

command -v mix >/dev/null 2>&1 || exit 0
cd "$CLAUDE_PROJECT_DIR" || exit 0

if ! output=$(mix credo --strict --format oneline 2>&1); then
  printf 'mix credo --strict reports findings; fix them in the code, never in .credo.exs:\n%s\n' "$output" >&2
  exit 2
fi
