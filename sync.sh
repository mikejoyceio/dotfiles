#!/bin/sh
# sync.sh — generate the public `dotlayer` template from this `dotfiles` repo.
#
# `dotfiles` is the source of truth (Mike's personal baseline). `dotlayer` is a
# generated, public "Use this template" mirror. This script mirrors the synced
# code verbatim and applies a mechanical rebrand (dotfiles -> dotlayer,
# DOTFILES_* -> DOTLAYER_*, ~/.config/dotfiles -> ~/.config/dotlayer) plus one
# named transform that makes the template's bootstrap fail fast on the owner.
#
# It never auto-pushes: it writes files and stops at a reviewable diff. A
# private -> public copier must not publish on its own.
#
# Usage:
#   ./sync.sh           Generate into ../dotlayer (review, then commit by hand).
#   ./sync.sh --check   Dry run: exit non-zero if ../dotlayer is out of date.
#
# Owned by `dotlayer` and never written by this script: README.md, LICENSE,
# .github/ (a public template legitimately uses "dotfiles" as a concept and
# needs its own framing + license). sync.sh itself is excluded from the mirror.
set -eu

SCRIPT_DIR=$(cd "$(dirname "$0")" && pwd)
SRC="$SCRIPT_DIR"
DEST=${DOTLAYER_DEST:-"$SCRIPT_DIR/../dotlayer"}

CHECK=false
case "${1:-}" in
  "") ;;
  --check) CHECK=true ;;
  *)
    echo "Usage: $0 [--check]" >&2
    exit 2
    ;;
esac

# Files/dirs the mirror must never touch. .git, .claude and .DS_Store are local;
# the rest are owned by dotlayer (hand-maintained there). Excluded files are
# protected from --delete, so the owned set survives a regeneration.
rsync_mirror() {
  target=$1
  rsync -a --delete \
    --exclude='/.git' \
    --exclude='/.github' \
    --exclude='/.claude' \
    --exclude='/sync.sh' \
    --exclude='/README.md' \
    --exclude='/LICENSE' \
    --exclude='.DS_Store' \
    "$SRC"/ "$target"/
}

# Global rebrand over every synced text file. Three cased passes cover repo
# names, dir defaults, DOTFILES_* vars, ~/.config/dotfiles, and prose/comments
# ("Dotfiles are ready." needs the capitalized form). The owned files are never
# in this set, so the README's intentional "dotfiles" concept-uses are safe.
apply_renames() {
  target=$1
  find "$target" \
    \( -name .git -o -name .github -o -name .claude \) -prune -o \
    -type f ! -name README.md ! -name LICENSE ! -name .DS_Store -print |
    while IFS= read -r f; do
      tmp="$f.synctmp.$$"
      sed -e 's/dotfiles/dotlayer/g' \
        -e 's/DOTFILES/DOTLAYER/g' \
        -e 's/Dotfiles/Dotlayer/g' \
        "$f" >"$tmp"
      mv "$tmp" "$f"
    done
}

# The one non-global rule: make the template's owner fail fast. After the global
# rebrand the source line reads `${DOTLAYER_GITHUB_OWNER:-mikejoyceio}`; replace
# the silent fallback with POSIX `${VAR:?word}` so a bare run aborts with a clear
# message while the documented one-liner (which sets the var) still works.
#
# Assert the expected line is present exactly once first: if the upstream line
# changes shape this errors loudly instead of silently dropping the guard.
patch_owner_failfast() {
  bs="$1/bootstrap.sh"
  before='GITHUB_OWNER=${DOTLAYER_GITHUB_OWNER:-mikejoyceio}'
  after='GITHUB_OWNER=${DOTLAYER_GITHUB_OWNER:?Set DOTLAYER_GITHUB_OWNER to your GitHub account}'

  count=$(grep -F -c "$before" "$bs" || true)
  if [ "$count" -ne 1 ]; then
    echo "sync.sh: expected exactly one owner line in bootstrap.sh, found $count." >&2
    echo "  looking for: $before" >&2
    echo "  the upstream owner line changed shape; update sync.sh." >&2
    exit 1
  fi

  tmp="$bs.synctmp.$$"
  sed 's|^GITHUB_OWNER=.*|'"$after"'|' "$bs" >"$tmp"
  mv "$tmp" "$bs"

  newcount=$(grep -F -c "$after" "$bs" || true)
  if [ "$newcount" -ne 1 ]; then
    echo "sync.sh: owner fail-fast transform did not apply cleanly." >&2
    exit 1
  fi
}

generate() {
  target=$1
  mkdir -p "$target"
  rsync_mirror "$target"
  apply_renames "$target"
  patch_owner_failfast "$target"
}

if [ "$CHECK" = true ]; then
  if [ ! -d "$DEST" ]; then
    echo "drift: $DEST does not exist — run sync.sh to generate it." >&2
    exit 1
  fi
  staging=$(mktemp -d "${TMPDIR:-/tmp}/dotlayer-sync.XXXXXX")
  trap 'rm -rf "$staging"' EXIT
  generate "$staging"

  # Compare only the synced surface: owned files and local dirs are excluded on
  # both sides. Any add/remove/content change is drift.
  if diff -r \
    -x .git -x .github -x .claude -x .DS_Store \
    -x README.md -x LICENSE \
    "$staging" "$DEST"; then
    echo "sync.sh --check: $DEST is up to date."
  else
    echo "" >&2
    echo "drift: $DEST is out of date — run sync.sh to regenerate." >&2
    exit 1
  fi
  exit 0
fi

generate "$DEST"

echo "Generated the dotlayer template in $DEST."
echo ""
echo "Review before publishing (sync.sh never pushes):"
echo "  git -C \"$DEST\" status"
echo "  git -C \"$DEST\" add -A && git -C \"$DEST\" diff --cached"
echo ""
echo "Publish by hand once it looks right:"
echo "  git -C \"$DEST\" commit -m \"Sync from dotfiles\" && git -C \"$DEST\" push"
