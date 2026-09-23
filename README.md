# dotfiles

Public, non-sensitive dotfiles for a repeatable macOS development environment.

This repository uses [chezmoi](https://www.chezmoi.io/) for dotfiles and
[Homebrew Bundle](https://docs.brew.sh/Brew-Bundle-and-Brewfile) for software.
It has a shared private layer plus separate work and personal machine profiles.
The public `Brewfile` intentionally contains only common baseline tools.

## Layout

```text
~/Development/
├── dotfiles/           # public baseline
├── dotfiles-private/   # shared private configuration and apps
├── dotfiles-work/      # work-only configuration and apps
└── dotfiles-personal/  # personal-only configuration and apps
```

All four repositories use the conventional filename `Brewfile`. Their paths
make the layers unambiguous.

## Bootstrap

### New machine

The public bootstrap is the unauthenticated entry point. It installs Homebrew
when needed, installs Git, `gh`, and chezmoi, authenticates GitHub, and clones
the shared private repository plus the selected profile. It then hands control
to `bootstrap.sh` in the public clone, making the repositories the source of
truth for the rest of the setup.

```sh
# Work computer
curl -fsSL https://raw.githubusercontent.com/mikejoyceio/dotfiles/main/bootstrap.sh \
  | sh -s -- --work

# Personal computer
curl -fsSL https://raw.githubusercontent.com/mikejoyceio/dotfiles/main/bootstrap.sh \
  | sh -s -- --personal
```

Add `--macos` after the profile to apply the macOS preferences too.

### Existing machine

Run the repository copy directly. Before installing anything, it updates all
three repositories used by the selected profile with fast-forward-only merges:

```sh
~/Development/dotfiles/bootstrap.sh --work
# or
~/Development/dotfiles/bootstrap.sh --personal
```

The bootstrap stops if a repository has uncommitted changes, is ahead of or
has diverged from its upstream branch, or is not currently on a branch. It
never discards local work to match the remote.

The work profile installs `public + private + work`. The personal profile
installs `public + private + personal`. The selected profile is saved locally
so `.zshrc` sources only its matching shell configuration.

Review changes before applying them manually with:

```sh
chezmoi -S "$HOME/Development/dotfiles" diff
```

## Worktree tmux sessions

`wtmux` and `agents` manage persistent tmux sessions for Git worktrees, so
long-running tools keep working after a disconnect and can be reattached
locally or over SSH.

```sh
# Enter or create a tmux session for the current worktree
wtmux

# Create the session and start Claude Code
wtmux claude

# Create the session and start Cursor CLI
wtmux agent

# Pass arguments to Claude Code
wtmux claude --resume

# Pass arguments to Cursor CLI
wtmux agent resume

# List and attach to running worktree sessions
agents

# Attach directly to a named session
agents repository--branch-name
```

The command runs only when the session is first created. Running `wtmux`
again for the same worktree, with or without a command, reattaches to the
existing session and never starts a second agent on top of the running one.
To switch agents, exit the running agent and start the other one from the
shell inside the same session (`exit`, then `agent` or `claude`).

Recent Cursor CLI installations expose the command as `agent`; older
installations may use the backward-compatible alias `cursor-agent`.

Detaching (`Ctrl+b`, then `d`) leaves the session and anything running in it,
such as Claude Code, alive.

## PKM Consume command

`consume` sends one exact source to the Hermes `pkm` profile and its existing
`consume` skill. The wrapper does not write Obsidian files, classify sources,
normalize URLs, or duplicate any other PKM behavior.

```sh
consume 'https://x.com/example/status/123?s=20'
consume 'https://www.linkedin.com/posts/example'
consume 'https://example.com/article?ref=home&campaign=reading'
consume 'A book title to read later'
consume "$HOME/Documents/Reading List/book draft.pdf"
```

Quote sources containing spaces or shell-sensitive characters such as `&`.
The v0.1 interface accepts exactly one argument and does not read stdin.

The command requires Hermes, a profile named `pkm`, a valid `terminal.cwd` for
that profile, and the `consume` skill installed in the profile.

The Raycast Script Command is installed by chezmoi at:

```text
~/.config/raycast/script-commands/consume.sh
```

In Raycast Preferences, open Extensions, click `+`, choose `Add Script
Directory`, and select `~/.config/raycast/script-commands`. The command accepts
an optional source argument and otherwise uses the clipboard. A global hotkey
can be assigned after Raycast indexes the command.

The reliable browser workflow is:

```text
copy the current URL → run Consume → Return
```

Current-browser automation is intentionally not included. A future full
Raycast extension may use Raycast's Browser Extension API if clipboard use
proves too costly; browser-specific AppleScript should not be added merely to
avoid one copy action.

## Security boundary

Do not commit credentials, tokens, employer/client details, private hostnames,
or a revealing software inventory here. Put shared sensitive configuration in
`dotfiles-private`, employer/client tooling in `dotfiles-work`, and
personal-only apps in `dotfiles-personal`. Secrets themselves should come from
a password manager or another dedicated secret store, not Git.

The split reduces future exposure; it does not erase information from an older
repository's Git history.
