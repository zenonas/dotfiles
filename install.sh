#!/bin/bash

DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
BACKUP_DOTFILES_DIR=~/.dotfiles_backup

## Backup old dotfiles

mkdir -p $BACKUP_DOTFILES_DIR
[[ -f ~/.bash_profile ]] && mv ~/.bash_profile $BACKUP_DOTFILES_DIR/
[[ -f ~/.gitconfig ]] && mv ~/.gitconfig $BACKUP_DOTFILES_DIR/
[[ -f ~/.vimrc ]] && mv ~/.vimrc $BACKUP_DOTFILES_DIR/
[[ -f ~/.bashrc ]] && mv ~/.bashrc $BACKUP_DOTFILES_DIR/

## Link new dotfiles
ln -s $DIR/bash/bash_profile ~/.bash_profile
ln -s $DIR/bash/bashrc ~/.bashrc
ln -s $DIR/git/gitconfig ~/.gitconfig
ln -s $DIR/vim/vimrc ~/.vimrc
