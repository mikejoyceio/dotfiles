#!/usr/bin/env bash

# Setup script for macOS

# Homebrew packages
PACKAGES=(
  awscli
  bash-completion
  bash-git-prompt
  contentful-cli
  docker
  gatsby-cli
  gnupg
  localstack
  mas
  netlify-cli
  node
  nvm
  postgresql
  spoof-mac
  tldr
  yarn
)

# Homebrew casks
CASKS=(
  1password-cli
  atom
  firefox
  gifox
  gimp
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
  # 1password
  1333542190
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

# Install Xcode CLI
if test ! $(which xcode-select); then
 echo "Install Xcode CLI..."
 xcode-select --install
fi

# Install Vim Plug
if [ ! -f ~/.vim/autoload/plug.vim ]; then
 echo "Installing Vim Plug..."
 curl -fLo ~/.vim/autoload/plug.vim --create-dirs \
    https://raw.githubusercontent.com/junegunn/vim-plug/master/plug.vim
fi

# Install Homebrew
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

# Install RVM
gpg --keyserver hkp://pgp.mit.edu --recv-keys 409B6B1796C275462A1703113804BB82D39DC0E3 7D2BAF1CF37B13E2069D6956105BD0E739499BDB
\curl -sSL https://get.rvm.io | bash -s stable

# Create PostgreSQL User
brew services restart postgresql
/usr/local/opt/postgres/bin/createuser -s postgres

echo "macOS bootstrap complete!"
