#!/bin/bash

DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
BACKUP_DOTFILES_DIR=~/.dotfiles_backup

run() {
  if [[ ! -d $BACKUP_DOTFILES_DIR ]]; then
    backup_old_dotfiles
  fi
  mkdir -p $DIR/tmp
  clean_up
  link_dotfiles
  install_vim_plugins
}

backup_old_dotfiles() {
  mkdir -p $BACKUP_DOTFILES_DIR
  echo "Backing up your old dotfiles in $BACKUP_DOTFILES_DIR"
  [[ -f ~/.bash_profile ]] && mv ~/.bash_profile $BACKUP_DOTFILES_DIR/
  [[ -f ~/.zshrc ]] && mv ~/.zshrc $BACKUP_DOTFILES_DIR/
  [[ -f ~/.ctags ]] && mv ~/.ctags $BACKUP_DOTFILES_DIR/
  [[ -f ~/.gitconfig ]] && mv ~/.gitconfig $BACKUP_DOTFILES_DIR/
  [[ -f ~/.vimrc ]] && mv ~/.vimrc $BACKUP_DOTFILES_DIR/
  [[ -d ~/.vim ]] && mv ~/.vim $BACKUP_DOTFILES_DIR/
  [[ -f ~/.bashrc ]] && mv ~/.bashrc $BACKUP_DOTFILES_DIR/
}

clean_up() {
  echo "Cleaning up old symlinks"
  [[ -L ~/.bash_profile ]] && rm ~/.bash_profile
  [[ -L ~/.bashrc ]] && rm ~/.bashrc
  [[ -L ~/.zshrc ]] && rm ~/.zshrc
  [[ -L ~/.ctags ]] && rm ~/.ctags
  [[ -L ~/.gitconfig ]] && rm ~/.gitconfig
  [[ -L ~/.gitignore ]] && rm ~/.gitignore
  [[ -L ~/.vim ]] && rm ~/.vim
  [[ -L ~/.vimrc ]] && rm ~/.vimrc
}

link_dotfiles() {
  echo "Symlinking dotfiles"
  ln -s $DIR/zshrc ~/.zshrc
  ln -s $DIR ~/.dotfiles
  ln -s $DIR/git/gitconfig ~/.gitconfig
  ln -s $DIR/ctags ~/.ctags
  ln -s $DIR/git/gitignore ~/.gitignore
  ln -s $DIR/vim ~/.vim
  ln -s $DIR/vim/vimrc ~/.vimrc
}

install_vim_plugins() {
  vim +:PluginUpdate +:PluginClean +qall
  echo "Installed Vim plugins via vundle"
}

run
