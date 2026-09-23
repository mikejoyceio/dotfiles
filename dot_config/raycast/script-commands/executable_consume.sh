#!/usr/bin/env bash

# Required parameters:
# @raycast.schemaVersion 1
# @raycast.title Consume
# @raycast.mode compact

# Optional parameters:
# @raycast.packageName PKM
# @raycast.icon 📥
# @raycast.argument1 { "type": "text", "placeholder": "Source (optional; uses clipboard when empty)", "optional": true }
# @raycast.description Save one source to the Obsidian Consume queue through Hermes.

set -euo pipefail

consume_bin=${CONSUME_BIN:-"$HOME/.local/bin/consume"}
pbpaste_bin=${PBPASTE_BIN:-/usr/bin/pbpaste}
source_value=${1:-}

if [[ "$source_value" != *[![:space:]]* ]]; then
  source_value=''
fi

if [[ -z "$source_value" ]]; then
  if [[ ! -x "$pbpaste_bin" ]]; then
    printf 'Error: clipboard reader is unavailable.\n' >&2
    exit 1
  fi
  set +e
  source_value="$("$pbpaste_bin"; clipboard_status=$?; printf '\034'; exit "$clipboard_status")"
  clipboard_status=$?
  set -e
  source_value=${source_value%$'\034'}
  if [[ $clipboard_status -ne 0 ]]; then
    printf 'Error: unable to read the clipboard.\n' >&2
    exit "$clipboard_status"
  fi
fi

if [[ "$source_value" != *[![:space:]]* ]]; then
  printf 'Error: provide a source or copy one to the clipboard.\n' >&2
  exit 64
fi

if [[ ! -x "$consume_bin" ]]; then
  printf 'Error: consume CLI is not installed at %s.\n' "$consume_bin" >&2
  exit 1
fi

exec "$consume_bin" "$source_value"
