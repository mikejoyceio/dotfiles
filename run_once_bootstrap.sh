#!/usr/bin/env bash

echo "Start macOS bootstrap"

# Install Xcode CLI
if test ! $(which xcode-select); then
 echo "Install Xcode CLI..."
 xcode-select --install
fi

# Install Vim Plug
if [ ! -f ~/.vim/autoload/plug.vim ]; then
 echo "Install Vim Plug..."
 curl -fLo ~/.vim/autoload/plug.vim --create-dirs \
    https://raw.githubusercontent.com/junegunn/vim-plug/master/plug.vim
fi

# Install Homebrew
if test ! $(which brew); then
 echo "Install Homebrew..."
 ruby -e "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/master/install)"
fi

# Install Homebrew packages
brew update
brew bundle --global
brew cleanup

# Create PostgreSQL User
brew services restart postgresql
/usr/local/opt/postgres/bin/createuser -s postgres

# Install RVM
gpg --keyserver hkp://pgp.mit.edu --recv-keys 409B6B1796C275462A1703113804BB82D39DC0E3 7D2BAF1CF37B13E2069D6956105BD0E739499BDB
\curl -sSL https://get.rvm.io | bash -s stable
