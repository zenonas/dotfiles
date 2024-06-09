#!/bin/bash

DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
BACKUP_DOTFILES_DIR=~/.dotfiles_backup

run() {
  if [[ ! -d $BACKUP_DOTFILES_DIR ]]; then
    backup_old_dotfiles
  fi
  mkdir -p $DIR/tmp
  clean_up
  install_deps
  install_apps
  link_dotfiles
  setup_nvim
  setup_copilot
  configure_stuff
}

backup_old_dotfiles() {
  mkdir -p $BACKUP_DOTFILES_DIR
  echo "Backing up your old dotfiles in $BACKUP_DOTFILES_DIR"
  [[ -f ~/.profile ]] && mv ~/.profile $BACKUP_DOTFILES_DIR/
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
  if ! which brew  > /dev/null; then /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"; fi

  if ! which gum >/dev/null; then
    echo "Gum not found, installing"
    brew install gum &>/dev/null
  fi
  export HOMEBREW_NO_AUTO_UPDATE=1
}

setup_nvim() {
  echo "Updating git hook"
  ./nvim/install-plugin-update-hook.sh

  echo "Updating vim plugins"
  nvim +"lua require('lazy').sync({wait=true})" +qa

  echo "Updating language tools"
  nvim --headless "+MasonUpdate" +qa
}

install_apps() {
  gum spin --title "Installing base apps" -- brew bundle --no-lock -v

  [[ "$(uname)" == "Darwin" ]] &&  gum spin --title "Installing MacOS apps" -- brew bundle --no-lock --file=Brewfile.macos
}

setup_copilot() {
  gum confirm "Do you want to setup Github Copilot?" &&
    gh auth login --web -h github.com &&
    gh extension install github/gh-copilot --force
}

configure_stuff() {
  gum confirm "Configure your name and email in gitconfig?" && setup_git
}

setup_git() {
  gum log "Setting up gitconfig"

  fullname=$(gum input --placeholder="Enter your fullname")
  email=$(gum input --placeholder="Enter your email address")

  git config --global user.name "$fullname"
  git config --global user.email "$email"
}

run
