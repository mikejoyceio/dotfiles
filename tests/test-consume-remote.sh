#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
bridge="$repo_root/dot_local/bin/executable_consume-remote"
client="$repo_root/.chezmoitemplates/consume-remote-client"
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT

passes=0

fail() {
  printf 'FAIL: %s\n' "$1" >&2
  exit 1
}

pass() {
  passes=$((passes + 1))
  printf 'PASS: %s\n' "$1"
}

assert_status() {
  local expected=$1
  local actual=$2
  local label=$3
  [[ "$actual" -eq "$expected" ]] || fail "$label (expected status $expected, got $actual)"
  pass "$label"
}

assert_equals() {
  local expected=$1
  local actual=$2
  local label=$3
  [[ "$actual" == "$expected" ]] || fail "$label (expected <$expected>, got <$actual>)"
  pass "$label"
}

assert_contains() {
  local haystack=$1
  local needle=$2
  local label=$3
  [[ "$haystack" == *"$needle"* ]] || fail "$label (missing <$needle>)"
  pass "$label"
}

assert_not_contains() {
  local haystack=$1
  local needle=$2
  local label=$3
  [[ "$haystack" != *"$needle"* ]] || fail "$label (unexpected <$needle>)"
  pass "$label"
}

assert_files_equal() {
  local expected=$1
  local actual=$2
  local label=$3
  /usr/bin/cmp -s "$expected" "$actual" || fail "$label (files differ)"
  pass "$label"
}

assert_path_exists() {
  local path=$1
  local label=$2
  [[ -e "$path" ]] || fail "$label (missing <$path>)"
  pass "$label"
}

assert_path_missing() {
  local path=$1
  local label=$2
  [[ ! -e "$path" ]] || fail "$label (unexpected <$path>)"
  pass "$label"
}

cat > "$tmp/canonical-consume" <<'STUB'
#!/usr/bin/env bash
set -euo pipefail
printf '%s' "$1" > "$CAPTURE_SOURCE"
[[ -n "${CANONICAL_STDOUT:-}" ]] && printf '%s' "$CANONICAL_STDOUT"
[[ -n "${CANONICAL_STDERR:-}" ]] && printf '%s' "$CANONICAL_STDERR" >&2
exit "${CANONICAL_STATUS:-0}"
STUB
chmod +x "$tmp/canonical-consume"

run_bridge() {
  local input_file=$1
  local stdout_file=$2
  local stderr_file=$3
  shift 3

  : > "$stdout_file"
  : > "$stderr_file"
  : > "$tmp/captured-source"

  set +e
  env -u SSH_CONNECTION -u SSH_CLIENT -u SSH_TTY -u SSH_ORIGINAL_COMMAND \
    HOME="$tmp/home" \
    CONSUME_BIN="$tmp/canonical-consume" \
    CAPTURE_SOURCE="$tmp/captured-source" \
    "$@" \
    "$bridge" <"$input_file" >"$stdout_file" 2>"$stderr_file"
  RUN_STATUS=$?
  set -e
}

mkdir -p "$tmp/home/.local/bin"
cp "$tmp/canonical-consume" "$tmp/home/.local/bin/consume"
stdout="$tmp/stdout"
stderr="$tmp/stderr"
input="$tmp/input"

printf '%s' 'https://example.com/article?x=1&y=2#part%20one' > "$input"
run_bridge "$input" "$stdout" "$stderr"
assert_status 0 "$RUN_STATUS" 'direct bridge invocation succeeds'
assert_files_equal "$input" "$tmp/captured-source" 'direct bridge preserves URL punctuation exactly'

printf '%s' $'  A source with \'single\' and "double" quotes\n\n' > "$input"
run_bridge "$input" "$stdout" "$stderr"
assert_status 0 "$RUN_STATUS" 'bridge accepts spaces quotes and newlines'
assert_files_equal "$input" "$tmp/captured-source" 'bridge preserves trailing newlines byte-for-byte'

: > "$input"
run_bridge "$input" "$stdout" "$stderr"
assert_status 64 "$RUN_STATUS" 'bridge rejects empty stdin'
assert_contains "$(<"$stderr")" 'provide one source on stdin' 'bridge explains empty stdin'

printf ' \t\n ' > "$input"
run_bridge "$input" "$stdout" "$stderr"
assert_status 64 "$RUN_STATUS" 'bridge rejects whitespace-only stdin'

/bin/dd if=/dev/zero bs=1 count=65537 2>/dev/null | /usr/bin/tr '\000' x > "$input"
run_bridge "$input" "$stdout" "$stderr"
assert_status 64 "$RUN_STATUS" 'bridge rejects a source larger than 64 KiB'
assert_contains "$(<"$stderr")" 'source exceeds 65536 bytes' 'oversized source is diagnosed'
assert_equals '' "$(<"$tmp/captured-source")" 'oversized source never reaches canonical consume'

printf '%s' 'https://example.com/ssh' > "$input"
run_bridge "$input" "$stdout" "$stderr" \
  SSH_CONNECTION='100.64.0.2 50000 100.64.0.1 22' \
  SSH_ORIGINAL_COMMAND='consume-remote'
assert_status 0 "$RUN_STATUS" 'SSH bridge accepts the fixed original command'
assert_files_equal "$input" "$tmp/captured-source" 'SSH bridge preserves source data'

cat > "$tmp/override-consume" <<'STUB'
#!/usr/bin/env bash
set -euo pipefail
: > "$OVERRIDE_EXECUTED"
STUB
chmod +x "$tmp/override-consume"
rm -f "$tmp/override-executed"
run_bridge "$input" "$stdout" "$stderr" \
  SSH_CONNECTION='100.64.0.2 50000 100.64.0.1 22' \
  SSH_ORIGINAL_COMMAND='consume-remote' \
  CONSUME_BIN="$tmp/override-consume" \
  OVERRIDE_EXECUTED="$tmp/override-executed"
assert_status 0 "$RUN_STATUS" 'SSH bridge ignores a consume executable override'
assert_path_missing "$tmp/override-executed" 'SSH bridge keeps the canonical executable fixed'
assert_files_equal "$input" "$tmp/captured-source" 'SSH bridge still delegates source data canonically'

run_bridge "$input" "$stdout" "$stderr" \
  SSH_CONNECTION='100.64.0.2 50000 100.64.0.1 22' \
  SSH_ORIGINAL_COMMAND=''
assert_status 64 "$RUN_STATUS" 'SSH bridge rejects an empty original command'
assert_contains "$(<"$stderr")" 'unsupported remote command' 'empty SSH command is diagnosed'

run_bridge "$input" "$stdout" "$stderr" \
  SSH_CONNECTION='100.64.0.2 50000 100.64.0.1 22' \
  SSH_ORIGINAL_COMMAND='other-command'
assert_status 64 "$RUN_STATUS" 'SSH bridge rejects a different original command'

CANONICAL_STDOUT='Saved: Consume/Remote.md\n' \
run_bridge "$input" "$stdout" "$stderr"
assert_status 0 "$RUN_STATUS" 'bridge preserves canonical success status'
assert_equals 'Saved: Consume/Remote.md\n' "$(<"$stdout")" 'bridge preserves canonical stdout'

CANONICAL_STDERR='Error: Consume failed\n' CANONICAL_STATUS=1 \
run_bridge "$input" "$stdout" "$stderr"
assert_status 1 "$RUN_STATUS" 'bridge preserves canonical semantic error status'
assert_equals 'Error: Consume failed\n' "$(<"$stderr")" 'bridge preserves canonical stderr'

CANONICAL_STDERR='provider unavailable\n' CANONICAL_STATUS=42 \
run_bridge "$input" "$stdout" "$stderr"
assert_status 42 "$RUN_STATUS" 'bridge preserves arbitrary canonical failure status'

set +e
CONSUME_BIN="$tmp/missing-consume" "$bridge" <"$input" >"$stdout" 2>"$stderr"
status=$?
set -e
assert_status 1 "$status" 'bridge fails when canonical consume is unavailable'
assert_contains "$(<"$stderr")" 'canonical consume command is unavailable' 'missing canonical consume is explained'

set +e
CONSUME_BIN="$tmp/canonical-consume" "$bridge" unexpected <"$input" >"$stdout" 2>"$stderr"
status=$?
set -e
assert_status 64 "$status" 'bridge rejects argv input'

cat > "$tmp/ssh" <<'STUB'
#!/usr/bin/env bash
set -euo pipefail
printf '%s\n' "$@" > "$SSH_ARGS_FILE"
/bin/cat > "$SSH_STDIN_FILE"
[[ -n "${FAKE_SSH_STDOUT:-}" ]] && printf '%s' "$FAKE_SSH_STDOUT"
[[ -n "${FAKE_SSH_STDERR:-}" ]] && printf '%s' "$FAKE_SSH_STDERR" >&2
exit "${FAKE_SSH_STATUS:-0}"
STUB
chmod +x "$tmp/ssh"

run_client() {
  local stdout_file=$1
  local stderr_file=$2
  shift 2

  : > "$stdout_file"
  : > "$stderr_file"
  : > "$tmp/ssh-args"
  : > "$tmp/ssh-stdin"

  set +e
  SSH_BIN="$tmp/ssh" \
  SSH_ARGS_FILE="$tmp/ssh-args" \
  SSH_STDIN_FILE="$tmp/ssh-stdin" \
  "$client" "$@" >"$stdout_file" 2>"$stderr_file"
  RUN_STATUS=$?
  set -e
}

source_value='https://example.com/article?x=1&y=two#part%20one'
printf '%s' "$source_value" > "$tmp/expected-source"
FAKE_SSH_STDOUT='Saved: Consume/Remote.md\n' \
run_client "$stdout" "$stderr" "$source_value"
assert_status 0 "$RUN_STATUS" 'remote client preserves SSH success status'
assert_files_equal "$tmp/expected-source" "$tmp/ssh-stdin" 'remote client sends URL only on stdin'
assert_equals 'Saved: Consume/Remote.md\n' "$(<"$stdout")" 'remote client preserves SSH stdout'
assert_contains "$(<"$tmp/ssh-args")" 'pkm-consume' 'remote client uses the fixed host alias'
assert_contains "$(<"$tmp/ssh-args")" 'consume-remote' 'remote client requests the fixed helper'
assert_contains "$(<"$tmp/ssh-args")" 'BatchMode=yes' 'remote client disables interactive SSH prompts'
assert_contains "$(<"$tmp/ssh-args")" 'ConnectTimeout=10' 'remote client bounds SSH connection time'
assert_not_contains "$(<"$tmp/ssh-args")" "$source_value" 'remote client excludes source data from SSH argv'
assert_not_contains "$(<"$tmp/ssh-args")" '-G' 'remote client does not gate execution with ssh -G'

CONSUME_REMOTE_HOST='redirected-host' \
run_client "$stdout" "$stderr" 'https://example.com/fixed-host'
assert_contains "$(<"$tmp/ssh-args")" 'pkm-consume' 'remote client keeps the fixed host when an override is supplied'
assert_not_contains "$(<"$tmp/ssh-args")" 'redirected-host' 'remote client cannot redirect source data with an environment override'

source_with_newlines=$'  A source with \'single\' and "double" quotes\n\n'
printf '%s' "$source_with_newlines" > "$tmp/expected-source"
run_client "$stdout" "$stderr" "$source_with_newlines"
assert_status 0 "$RUN_STATUS" 'remote client accepts spaces quotes and newlines'
assert_files_equal "$tmp/expected-source" "$tmp/ssh-stdin" 'remote client preserves trailing newlines byte-for-byte'

FAKE_SSH_STDOUT='Already in Consume: Consume/Existing.md\n' \
run_client "$stdout" "$stderr" 'https://example.com/existing'
assert_status 0 "$RUN_STATUS" 'remote client preserves duplicate status'
assert_equals 'Already in Consume: Consume/Existing.md\n' "$(<"$stdout")" 'remote client preserves duplicate output'

FAKE_SSH_STDERR='Error: Consume folder unavailable\n' FAKE_SSH_STATUS=1 \
run_client "$stdout" "$stderr" 'https://example.com/semantic-error'
assert_status 1 "$RUN_STATUS" 'remote client preserves semantic error status'
assert_equals 'Error: Consume folder unavailable\n' "$(<"$stderr")" 'remote client preserves semantic error output'

FAKE_SSH_STDERR='ssh: connect to host pkm-consume port 22: Operation timed out\n' FAKE_SSH_STATUS=255 \
run_client "$stdout" "$stderr" 'https://example.com/network-error'
assert_status 255 "$RUN_STATUS" 'remote client preserves SSH network failure status'
assert_contains "$(<"$stderr")" 'Operation timed out' 'remote client preserves SSH network diagnostic'

run_client "$stdout" "$stderr"
assert_status 64 "$RUN_STATUS" 'remote client rejects a missing source'

run_client "$stdout" "$stderr" one two
assert_status 64 "$RUN_STATUS" 'remote client rejects multiple sources'

run_client "$stdout" "$stderr" $' \t\n '
assert_status 64 "$RUN_STATUS" 'remote client rejects whitespace-only source'

set +e
SSH_BIN="$tmp/missing-ssh" "$client" 'https://example.com/no-ssh' >"$stdout" 2>"$stderr"
status=$?
set -e
assert_status 1 "$status" 'remote client fails when SSH is unavailable'
assert_contains "$(<"$stderr")" 'SSH is not installed or executable' 'missing SSH is explained'

write_chezmoi_config() {
  local path=$1
  local mode=$2
  cat > "$path" <<EOF
sourceDir = "$repo_root"

[data.consume]
    mode = "$mode"

[data.git]
    name = "Test User"
    email = "test@example.com"

[data.aliases.directories]
    dev = "~/Development"

[data.aliases.ssh]
EOF
}

write_legacy_chezmoi_config() {
  local path=$1
  cat > "$path" <<EOF
sourceDir = "$repo_root"

[data.git]
    name = "Test User"
    email = "test@example.com"

[data.aliases.directories]
    dev = "~/Development"

[data.aliases.ssh]
EOF
}

local_home="$tmp/local-home"
remote_home="$tmp/remote-home"
mkdir -p "$local_home/.local/bin" "$local_home/.config/raycast/script-commands"
mkdir -p "$remote_home/.local/bin" "$remote_home/.config/raycast/script-commands"
write_chezmoi_config "$tmp/local.toml" local
write_chezmoi_config "$tmp/remote.toml" remote
write_legacy_chezmoi_config "$tmp/legacy.toml"

legacy_home="$tmp/legacy-home"
mkdir -p "$legacy_home/.local/bin"
chezmoi -S "$repo_root" -D "$legacy_home" -c "$tmp/legacy.toml" \
  cat "$legacy_home/.local/bin/consume" > "$tmp/rendered-legacy"
assert_files_equal "$repo_root/.chezmoitemplates/consume-local" "$tmp/rendered-legacy" \
  'an existing config without consume mode defaults to the local role'
chezmoi -S "$repo_root" -D "$legacy_home" -c "$tmp/legacy.toml" ignored > "$tmp/legacy-ignored"
assert_not_contains "$(<"$tmp/legacy-ignored")" '.local/bin/consume-remote' \
  'an existing config without consume mode deploys the local bridge'
chezmoi -S "$repo_root" -D "$legacy_home" -c "$tmp/legacy.toml" apply
assert_path_exists "$legacy_home/.local/bin/consume-remote" \
  'an existing config without consume mode applies successfully'

chezmoi -S "$repo_root" -D "$local_home" -c "$tmp/local.toml" \
  cat "$local_home/.local/bin/consume" > "$tmp/rendered-local"
assert_files_equal "$repo_root/.chezmoitemplates/consume-local" "$tmp/rendered-local" \
  'local role renders the canonical consume implementation'

chezmoi -S "$repo_root" -D "$remote_home" -c "$tmp/remote.toml" \
  cat "$remote_home/.local/bin/consume" > "$tmp/rendered-remote"
assert_files_equal "$repo_root/.chezmoitemplates/consume-remote-client" "$tmp/rendered-remote" \
  'remote role renders the SSH consume client'

chezmoi -S "$repo_root" -D "$local_home" -c "$tmp/local.toml" ignored > "$tmp/local-ignored"
assert_not_contains "$(<"$tmp/local-ignored")" '.local/bin/consume-remote' \
  'local role deploys the consume bridge'

chezmoi -S "$repo_root" -D "$remote_home" -c "$tmp/remote.toml" ignored > "$tmp/remote-ignored"
assert_contains "$(<"$tmp/remote-ignored")" '.local/bin/consume-remote' \
  'remote role ignores the primary consume bridge'

chezmoi -S "$repo_root" -D "$local_home" -c "$tmp/local.toml" \
  cat "$local_home/.config/raycast/script-commands/consume.sh" > "$tmp/raycast-local"
chezmoi -S "$repo_root" -D "$remote_home" -c "$tmp/remote.toml" \
  cat "$remote_home/.config/raycast/script-commands/consume.sh" > "$tmp/raycast-remote"
assert_files_equal "$tmp/raycast-local" "$tmp/raycast-remote" \
  'local and remote roles render the identical Raycast script'
assert_files_equal "$repo_root/dot_config/raycast/script-commands/executable_consume.sh" "$tmp/raycast-local" \
  'Raycast source remains unchanged by role selection'

transition_home="$tmp/transition-home"
mkdir -p "$transition_home/.local"
chezmoi -S "$repo_root" -D "$transition_home" -c "$tmp/local.toml" \
  apply
assert_path_exists "$transition_home/.local/bin/consume-remote" \
  'local apply installs the primary consume bridge'

chezmoi -S "$repo_root" -D "$transition_home" -c "$tmp/remote.toml" \
  apply
assert_path_missing "$transition_home/.local/bin/consume-remote" \
  'switching to remote mode removes the stale primary bridge'
assert_files_equal "$repo_root/.chezmoitemplates/consume-remote-client" "$transition_home/.local/bin/consume" \
  'switching to remote mode installs the remote consume client'

printf 'PASS: %d assertions\n' "$passes"
