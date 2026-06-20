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

## Security boundary

Do not commit credentials, tokens, employer/client details, private hostnames,
or a revealing software inventory here. Put shared sensitive configuration in
`dotfiles-private`, employer/client tooling in `dotfiles-work`, and
personal-only apps in `dotfiles-personal`. Secrets themselves should come from
a password manager or another dedicated secret store, not Git.

The split reduces future exposure; it does not erase information from an older
repository's Git history.
