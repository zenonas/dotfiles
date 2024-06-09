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
  install_deps
  install_fonts
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
  [[ -f ~/.ideavimrc ]] && mv ~/.ideavimrc $BACKUP_DOTFILES_DIR/
  [[ -d ~/.vim ]] && mv ~/.vim $BACKUP_DOTFILES_DIR/
  [[ -f ~/.tmux.conf ]] && mv ~/.tmux.conf $BACKUP_DOTFILES_DIR/
  [[ -f ~/.bashrc ]] && mv ~/.bashrc $BACKUP_DOTFILES_DIR/
  [[ -d $XDG_CONFIG_HOME/nvim ]] && mv $XDG_CONFIG_HOME/nvim ~/ $BACKUP_DOTFILES_DIR/
}

clean_up() {
  echo "Cleaning up old symlinks"
  [[ -L ~/.bash_profile ]] && rm ~/.bash_profile
  [[ -L ~/.bashrc ]] && rm ~/.bashrc
  [[ -L ~/.dotfiles ]] && rm ~/.dotfiles
  [[ -L ~/.zshrc ]] && rm ~/.zshrc
  [[ -L ~/.gitconfig ]] && rm ~/.gitconfig
  [[ -L ~/.gitignore ]] && rm ~/.gitignore
  [[ -L ~/.ideavimrc ]] && rm ~/.ideavimrc
  [[ -L ~/.vim ]] && rm ~/.vim
  [[ -L ~/.vimrc ]] && rm ~/.vimrc
  [[ -L ~/.tmux.conf ]] && rm ~/.tmux.conf
  [[ -L $XDG_CONFIG_HOME/nvim ]] && rm $XDG_CONFIG_HOME/nvim
}

link_dotfiles() {
  echo "Symlinking dotfiles"
  ln -s $DIR/zshrc ~/.zshrc
  ln -s $DIR ~/.dotfiles
  ln -s $DIR/git/gitconfig ~/.gitconfig
  ln -s $DIR/git/gitignore ~/.gitignore
  ln -s $DIR/tmux/tmux.conf ~/.tmux.conf
  ln -s $DIR/idea/ideavimrc ~/.ideavimrc
  ln -s $DIR/nvim $XDG_CONFIG_HOME/nvim
}

install_deps() {
  if ! which brew  > /dev/null; then sh <(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/master/install.sh); fi

  if ! which gum >/dev/null; then
    echo "Gum not found, installing"
    brew install gum &>/dev/null
  fi
  export HOMEBREW_NO_AUTO_UPDATE=1
}

install_apps() {
  gum spin --title "Installing base apps" -- brew bundle --no-lock -v

  [[ "$(uname)" == "Darwin" ]] &&  gum spin --title "Installing MacOS apps" -- brew bundle --no-lock --file=Brewfile.macos
}

install_fonts() {
  brew tap homebrew/cask-fonts
  brew cask install font-sauce-code-pro-nerd-font
  brew cask install font-mononoki-nerd-font
}

configure_stuff() {
  read -p 'Enter full name: ' fullname
  read -p 'Enter email address: ' email

  sed -i '' "s/Zen Kyprianou/$fullname/g" $DIR/git/gitconfig
  sed -i '' "s/zen@kyprianou.eu/$email/g" $DIR/git/gitconfig
}

run
