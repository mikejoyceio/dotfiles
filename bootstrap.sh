#!/bin/sh
set -eu

GITHUB_OWNER=${DOTFILES_GITHUB_OWNER:-mikejoyceio}
DEVELOPMENT_DIR=${DOTFILES_DEVELOPMENT_DIR:-"$HOME/Development"}
PUBLIC_DIR=${DOTFILES_PUBLIC_DIR:-"$DEVELOPMENT_DIR/dotfiles"}
PRIVATE_DIR=${DOTFILES_PRIVATE_DIR:-"$DEVELOPMENT_DIR/dotfiles-private"}
WORK_DIR=${DOTFILES_WORK_DIR:-"$DEVELOPMENT_DIR/dotfiles-work"}
PERSONAL_DIR=${DOTFILES_PERSONAL_DIR:-"$DEVELOPMENT_DIR/dotfiles-personal"}
PROFILE=""
APPLY_MACOS=false

usage() {
  echo "Usage: $0 (--work|--personal) [--macos]" >&2
}

for argument in "$@"; do
  case "$argument" in
    --work)
      if [ -n "$PROFILE" ] && [ "$PROFILE" != "work" ]; then
        echo "Choose exactly one machine profile: --work or --personal." >&2
        exit 2
      fi
      PROFILE=work
      ;;
    --personal)
      if [ -n "$PROFILE" ] && [ "$PROFILE" != "personal" ]; then
        echo "Choose exactly one machine profile: --work or --personal." >&2
        exit 2
      fi
      PROFILE=personal
      ;;
    --macos) APPLY_MACOS=true ;;
    *) usage; exit 2 ;;
  esac
done

if [ -z "$PROFILE" ]; then
  usage
  exit 2
fi

if [ "$(uname -s)" != "Darwin" ]; then
  echo "This bootstrap currently supports macOS only." >&2
  exit 1
fi

activate_homebrew() {
  if command -v brew >/dev/null 2>&1; then
    return
  fi

  if [ -x /opt/homebrew/bin/brew ]; then
    eval "$(/opt/homebrew/bin/brew shellenv)"
  elif [ -x /usr/local/bin/brew ]; then
    eval "$(/usr/local/bin/brew shellenv)"
  fi
}

activate_homebrew

if ! command -v brew >/dev/null 2>&1; then
  echo "Installing Homebrew..."
  /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
  activate_homebrew
fi

echo "Installing bootstrap dependencies..."
brew install git gh chezmoi

update_repository() {
  destination=$1

  if [ -n "$(git -C "$destination" status --porcelain)" ]; then
    echo "$destination has uncommitted changes; refusing to replace them with the remote repository." >&2
    exit 1
  fi

  branch=$(git -C "$destination" symbolic-ref --quiet --short HEAD) || {
    echo "$destination is not on a branch; check it out before bootstrapping." >&2
    exit 1
  }

  echo "Updating $destination..."
  git -C "$destination" fetch --prune origin

  upstream=$(git -C "$destination" rev-parse --abbrev-ref --symbolic-full-name '@{upstream}' 2>/dev/null) || {
    if git -C "$destination" show-ref --verify --quiet "refs/remotes/origin/$branch"; then
      upstream="origin/$branch"
      git -C "$destination" branch --set-upstream-to "$upstream" "$branch" >/dev/null
    else
      echo "No upstream branch found for $destination." >&2
      exit 1
    fi
  }

  local_revision=$(git -C "$destination" rev-parse HEAD)
  remote_revision=$(git -C "$destination" rev-parse "$upstream")

  if [ "$local_revision" = "$remote_revision" ]; then
    echo "$destination is up to date."
  elif git -C "$destination" merge-base --is-ancestor "$local_revision" "$remote_revision"; then
    git -C "$destination" merge --ff-only "$upstream"
  else
    echo "$destination is ahead of or has diverged from $upstream; refusing to change it." >&2
    exit 1
  fi
}

clone_or_update_public_repository() {
  destination=$1

  if [ -d "$destination/.git" ]; then
    update_repository "$destination"
  elif [ -e "$destination" ]; then
    echo "$destination exists but is not a Git repository." >&2
    exit 1
  else
    git clone "https://github.com/$GITHUB_OWNER/dotfiles.git" "$destination"
  fi
}

clone_or_update_private_repository() {
  repository=$1
  destination=$2

  if [ -d "$destination/.git" ]; then
    update_repository "$destination"
  elif [ -e "$destination" ]; then
    echo "$destination exists but is not a Git repository." >&2
    exit 1
  else
    gh repo clone "$GITHUB_OWNER/$repository" "$destination"
  fi
}

if [ "${DOTFILES_BOOTSTRAP_FROM_REPO:-false}" != true ]; then
  mkdir -p "$DEVELOPMENT_DIR"
  clone_or_update_public_repository "$PUBLIC_DIR"

  if ! gh auth status --hostname github.com >/dev/null 2>&1; then
    echo "GitHub authentication is required for the private dotfiles layers."
    gh auth login --hostname github.com --web --git-protocol ssh
  fi

  clone_or_update_private_repository dotfiles-private "$PRIVATE_DIR"

  case "$PROFILE" in
    work) clone_or_update_private_repository dotfiles-work "$WORK_DIR" ;;
    personal) clone_or_update_private_repository dotfiles-personal "$PERSONAL_DIR" ;;
  esac

  if [ ! -x "$PUBLIC_DIR/bootstrap.sh" ]; then
    echo "The repository bootstrap is missing or not executable at $PUBLIC_DIR/bootstrap.sh." >&2
    exit 1
  fi

  echo "Continuing with the bootstrap from $PUBLIC_DIR..."
  export DOTFILES_BOOTSTRAP_FROM_REPO=true
  exec "$PUBLIC_DIR/bootstrap.sh" "$@"
fi

echo "Installing public Homebrew bundle..."
brew bundle --file "$PUBLIC_DIR/Brewfile"

if [ ! -f "$PRIVATE_DIR/Brewfile" ]; then
  echo "Required private Brewfile not found at $PRIVATE_DIR/Brewfile." >&2
  exit 1
fi

echo "Installing shared private Homebrew bundle..."
brew bundle --file "$PRIVATE_DIR/Brewfile"

case "$PROFILE" in
  work) PROFILE_DIR=$WORK_DIR ;;
  personal) PROFILE_DIR=$PERSONAL_DIR ;;
esac

if [ ! -f "$PROFILE_DIR/Brewfile" ]; then
  echo "Required $PROFILE Brewfile not found at $PROFILE_DIR/Brewfile." >&2
  exit 1
fi

echo "Installing $PROFILE Homebrew bundle..."
brew bundle --file "$PROFILE_DIR/Brewfile"

PROFILE_FILE="${XDG_CONFIG_HOME:-$HOME/.config}/dotfiles/profile"
mkdir -p "$(dirname "$PROFILE_FILE")"
printf '%s\n' "$PROFILE" > "$PROFILE_FILE"

echo "Creating the Screenshots directory..."
mkdir -p "$HOME/Screenshots"

echo "Applying dotfiles..."
chezmoi -S "$PUBLIC_DIR" apply --init

if [ "$APPLY_MACOS" = true ]; then
  "$PUBLIC_DIR/macos.sh"
fi

echo "Dotfiles are ready."
