#!/bin/sh
set -eu

if [ "$(uname -s)" != "Darwin" ]; then
  echo "macos.sh only supports macOS." >&2
  exit 1
fi

version=$(sw_vers -productVersion)
echo "Applying conservative macOS preferences on macOS $version..."

# Finder: show all filename extensions.
defaults write NSGlobalDomain AppleShowAllExtensions -bool true

# Finder: show the path bar and status bar.
defaults write com.apple.finder ShowPathbar -bool true
defaults write com.apple.finder ShowStatusBar -bool true

# Save screenshots as PNG.
defaults write com.apple.screencapture type -string "png"

killall Finder >/dev/null 2>&1 || true
killall SystemUIServer >/dev/null 2>&1 || true

echo "macOS preferences applied. Some changes may require logging out."
