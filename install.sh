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

main() {
  :
}

if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
  set -euo pipefail
  main "$@"
fi
