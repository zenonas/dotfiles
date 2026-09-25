#!/usr/bin/env bash
# Install or re-apply these dotfiles. Safe to re-run.
#
# Usage: ./install.sh [--yes]
#
#   --yes   never prompt (also implied when stdin is not a terminal)
#
# Environment:
#   GIT_NAME, GIT_EMAIL     git identity, written to ~/.gitconfig
#   DOTFILES_BREW_UPDATE=1  run `brew update` before installing packages
#
# Anything replaced is moved to ~/.dotfiles_backup/<timestamp>/.
#
# Must stay compatible with macOS's /bin/bash 3.2.

DOTFILES_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
CONFIG_DIR="$HOME/.config"
BACKUP_ROOT="$HOME/.dotfiles_backup"
BACKUP_DIR=""
INTERACTIVE=true

log() { printf '==> %s\n' "$*"; }
die() { printf 'dotfiles: %s\n' "$*" >&2; exit 1; }

detect_os() {
  local kernel="${DOTFILES_UNAME:-$(uname -s)}"
  local release="${DOTFILES_OS_RELEASE:-/etc/os-release}"
  local id="" like=""
  if [[ "$kernel" == "Darwin" ]]; then
    echo macos
    return 0
  fi
  if [[ -r "$release" ]]; then
    # shellcheck disable=SC1090
    id="$(. "$release" && echo "${ID:-}")"
    # shellcheck disable=SC1090
    like="$(. "$release" && echo "${ID_LIKE:-}")"
  fi
  case " $id $like " in
    *" debian "*|*" ubuntu "*) echo debian ;;
    *" arch "*) echo arch ;;
    *) echo unsupported ;;
  esac
}

# Move a path into this run's backup directory.
backup() {
  local path="$1"
  if [[ -z "$BACKUP_DIR" ]]; then
    BACKUP_DIR="$BACKUP_ROOT/$(date +%Y%m%d-%H%M%S)"
    mkdir -p "$BACKUP_DIR"
  fi
  log "Moving $path to $BACKUP_DIR/"
  mv "$path" "$BACKUP_DIR/"
}

# Links outside ~/.config, one "<link>|<target>" per line.
home_links() {
  printf '%s\n' \
    "$HOME/.dotfiles|$DOTFILES_DIR" \
    "$HOME/.zshrc|$CONFIG_DIR/zshrc/zshrc" \
    "$HOME/.tool-versions|$HOME/.dotfiles/.tool-versions"
}

link_home() {
  local link target
  while IFS='|' read -r link target; do
    if [[ -L "$link" && "$(readlink "$link")" == "$target" ]]; then continue; fi
    # The checkout itself may live at ~/.dotfiles.
    if [[ ! -L "$link" && "$link" -ef "$target" ]]; then continue; fi
    if [[ -e "$link" || -L "$link" ]]; then backup "$link"; fi
    ln -s "$target" "$link"
  done < <(home_links)
}

main() {
  :
}

if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
  set -euo pipefail
  main "$@"
fi
