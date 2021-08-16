#!/usr/bin/env bash

# Setup script for macOS

# Homebrew packages
PACKAGES=(
  bash-completion
  bash-git-prompt
  docker
  gatsby-cli
  mas
  netlify-cli
  node
  nvm
  spoof-mac
  tldr
  yarn
)

# Homebrew casks
CASKS=(
  1password
  1password-cli
  atom
  gifox
  gimp
  google-chrome
  keybase
  lepton
  pixelsnap
  postman
  sip
  sizzy
  sketch
  skitch
  skype
  slack
)

# Mac App Store apps
MAS=(
  # Bear
  1091189122
  # LINE
  539883307
  # Numbers
  409203825
  # Pages
  409201541
  # Pocket
  568494494
  # Spark
  1176895641
)

echo "Starting macOS bootstrap"

# Check if Install Xcode CLI is present, install if not
if test ! $(which xcode-select); then
 echo "Install Xcode CLI..."
 xcode-select --install
fi

if [ ! -f ~/.vim/autoload/plug.vim ]; then
 echo "Installing Vim Plug..."
 curl -fLo ~/.vim/autoload/plug.vim --create-dirs \
    https://raw.githubusercontent.com/junegunn/vim-plug/master/plug.vim
fi

# Check if Homebrew is present, install if not
if test ! $(which brew); then
 echo "Installing Homebrew..."
 ruby -e "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/master/install)"
fi

# Update Homebrew
brew update

echo "Install Homebrew packages..."
brew install ${PACKAGES[@]}

echo "Install Homebrew casks..."
brew install --cask ${CASKS[@]}

echo "Install Mac App Store apps..."
mas install ${MAS[@]}

# Install Shopify Theme Kit
brew tap shopify/shopify
brew install themekit

echo "Clean up Homebrew"
brew cleanup

echo "macOS bootstrap complete!"
