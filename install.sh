#!/bin/bash

DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
BACKUP_DOTFILES_DIR=~/.dotfiles_backup

run() {
 [[ "$(uname)" != "Darwin" ]] && echo -n "NOTE: These dotfiles and setup is intended for Mac OS users. Feel free to copy and use any of the stuff here but I can't be bothered to write an install script :D" && exit 1
  if [[ ! -d $BACKUP_DOTFILES_DIR ]]; then
    backup_old_dotfiles
  fi
  mkdir -p $DIR/tmp
  clean_up
  install_brew
  install_apps
  install_vim_plugins
  link_dotfiles
  configure_stuff
}

backup_old_dotfiles() {
  mkdir -p $BACKUP_DOTFILES_DIR
  echo "Backing up your old dotfiles in $BACKUP_DOTFILES_DIR"
  [[ -f ~/.bash_profile ]] && mv ~/.bash_profile $BACKUP_DOTFILES_DIR/
  [[ -f ~/.zshrc ]] && mv ~/.zshrc $BACKUP_DOTFILES_DIR/
  [[ -f ~/.gitconfig ]] && mv ~/.gitconfig $BACKUP_DOTFILES_DIR/
  [[ -f ~/.vimrc ]] && mv ~/.vimrc $BACKUP_DOTFILES_DIR/
  [[ -d ~/.vim ]] && mv ~/.vim $BACKUP_DOTFILES_DIR/
  [[ -f ~/.bashrc ]] && mv ~/.bashrc $BACKUP_DOTFILES_DIR/
  [[ -f ~/Library/Preferences/com.googlecode.iterm2.plist ]] && mv ~/Library/Preferences/com.googlecode.iterm2.plist $BACKUP_DOTFILES_DIR/
}

clean_up() {
  echo "Cleaning up old symlinks"
  [[ -L ~/.bash_profile ]] && rm ~/.bash_profile
  [[ -L ~/.bashrc ]] && rm ~/.bashrc
  [[ -L ~/.dotfiles ]] && rm ~/.dotfiles
  [[ -L ~/.zshrc ]] && rm ~/.zshrc
  [[ -L ~/.gitconfig ]] && rm ~/.gitconfig
  [[ -L ~/.gitignore ]] && rm ~/.gitignore
  [[ -L ~/.vim ]] && rm ~/.vim
  [[ -L ~/.vimrc ]] && rm ~/.vimrc
  [[ -L ~/Library/Preferences/com.googlecode.iterm2.plist ]] && rm ~/Library/Preferences/com.googlecode.iterm2.plist
}

link_dotfiles() {
  echo "Symlinking dotfiles"
  ln -s $DIR/zshrc ~/.zshrc
  ln -s $DIR ~/.dotfiles
  ln -s $DIR/git/gitconfig ~/.gitconfig
  ln -s $DIR/git/gitignore ~/.gitignore
  ln -s $DIR/vim ~/.vim
  ln -s $DIR/vim/vimrc ~/.vimrc
  ln -s $DIR/iterm/com.googlecode.iterm2.plist  ~/Library/Preferences/com.googlecode.iterm2.plist
}

install_vim_plugins() {
  vim +:PluginUpdate +:PluginClean +qall
  echo "Installed Vim plugins via vundle"
}

install_brew() {
  [[ ! -f /usr/local/bin/brew ]] && sh <(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/master/install.sh)
  brew update
  brew cleanup
  brew upgrade
  brew cask upgrade
  export HOMEBREW_NO_AUTO_UPDATE=1
}

install_apps() {
  brew install coreutils watch wget htop vim zsh ag rbenv jenv pyenv nodenv jq
  brew cask install cyberduck iterm2 visual-studio-code intellij-idea docker postman virtualbox virtualbox-extension-pack google-chrome firefox fontbase
}

configure_stuff() {
  read -p 'Enter full name: ' fullname
  read -p 'Enter email address: ' email

  sed -i '' "s/Zen Kyprianou/$fullname/g" $DIR/git/gitconfig
  sed -i '' "s/zen@kyprianou.eu/$email/g" $DIR/git/gitconfig
}

run
