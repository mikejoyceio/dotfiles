#!/bin/sh
set -eu

if [ "$(uname -s)" != "Darwin" ]; then
  echo "macos.sh only supports macOS." >&2
  exit 1
fi

version=$(sw_vers -productVersion)
echo "Applying conservative macOS preferences on macOS $version..."

# Appearance: use Dark Mode.
defaults write NSGlobalDomain AppleInterfaceStyle -string "Dark"

# Finder: show all filename extensions.
defaults write NSGlobalDomain AppleShowAllExtensions -bool true

# Finder: use list view and show the path bar and status bar.
defaults write com.apple.finder FXPreferredViewStyle -string "Nlsv"
defaults write com.apple.finder ShowPathbar -bool true
defaults write com.apple.finder ShowStatusBar -bool true

# Dock: position on the left and hide automatically.
defaults write com.apple.dock orientation -string "left"
defaults write com.apple.dock autohide -bool true

# Trackpad and mouse: use the traditional scroll direction.
defaults write NSGlobalDomain com.apple.swipescrolldirection -bool false

# Trackpad: enable tap to click.
defaults write com.apple.AppleMultitouchTrackpad Clicking -bool true
defaults write NSGlobalDomain com.apple.mouse.tapBehavior -int 1

# Menu bar clock: show the weekday and hide the date.
defaults write com.apple.menuextra.clock ShowDayOfWeek -bool true
defaults write com.apple.menuextra.clock ShowDate -int 0

# Keyboard: free Command-Space for the Raycast global hotkey.
defaults write com.apple.symbolichotkeys AppleSymbolicHotKeys -dict-add 64 \
  '<dict><key>enabled</key><false/></dict>'

killall Finder >/dev/null 2>&1 || true
killall Dock >/dev/null 2>&1 || true
killall SystemUIServer >/dev/null 2>&1 || true

echo "macOS preferences applied. Some changes may require logging out."
