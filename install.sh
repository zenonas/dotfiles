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
  local path="$1" phys dest
  if [[ ! -L "$path" ]]; then
    phys="$(cd "$path" 2>/dev/null && pwd -P)" || phys=""
    if [[ -n "$phys" ]] && { [[ "$DOTFILES_DIR" == "$phys" ]] || [[ "$DOTFILES_DIR" == "$phys"/* ]]; }; then
      die "refusing to move $path: it contains this checkout"
    fi
  fi
  if [[ -z "$BACKUP_DIR" ]]; then
    mkdir -p "$BACKUP_ROOT"
    BACKUP_DIR="$(mktemp -d "$BACKUP_ROOT/$(date +%Y%m%d-%H%M%S).XXXXXX")"
  fi
  dest="$BACKUP_DIR/$(basename "$path")"
  if [[ -e "$dest" || -L "$dest" ]]; then
    die "refusing to overwrite existing backup at $dest"
  fi
  if [[ -L "$path" ]]; then
    log "Moving $path (-> $(readlink "$path")) to $BACKUP_DIR/"
  else
    log "Moving $path to $BACKUP_DIR/"
  fi
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

# Top-level directories that stow links into ~/.config (see .stowrc).
stow_packages() {
  local dir name
  for dir in "$DOTFILES_DIR"/*/; do
    name="$(basename "$dir")"
    case "$name" in scripts|tests|tmp) continue ;; esac
    printf '%s\n' "$name"
  done
}

# Move aside anything in ~/.config that stow would conflict with, unless it
# already links into this checkout.
prepare_stow_targets() {
  # The checkout is cloned as ~/.config itself; there is nothing to stow.
  if [[ "$CONFIG_DIR" -ef "$DOTFILES_DIR" ]]; then return 0; fi
  local name target
  while read -r name; do
    target="$CONFIG_DIR/$name"
    if [[ ! -e "$target" && ! -L "$target" ]]; then continue; fi
    if [[ -L "$target" && "$(cd "$target" 2>/dev/null && pwd -P)" == "$DOTFILES_DIR/$name" ]]; then
      continue
    fi
    backup "$target"
  done < <(stow_packages)
}

stow_dotfiles() {
  log "Linking config into $CONFIG_DIR"
  (cd "$DOTFILES_DIR" && stow --restow .)
}

# ~/.config/git/config is stowed from this repo, so identity goes in
# ~/.gitconfig (git reads both) to keep it out of version control.
setup_git_identity() {
  local file="$HOME/.gitconfig" name="${GIT_NAME:-}" email="${GIT_EMAIL:-}"
  if [[ -z "$name" ]] && ! git config --file "$file" user.name >/dev/null 2>&1 && $INTERACTIVE; then
    read -r -p "Git full name (blank to skip): " name
  fi
  if [[ -z "$email" ]] && ! git config --file "$file" user.email >/dev/null 2>&1 && $INTERACTIVE; then
    read -r -p "Git email (blank to skip): " email
  fi
  if [[ -n "$name" ]]; then git config --file "$file" user.name "$name"; fi
  if [[ -n "$email" ]]; then git config --file "$file" user.email "$email"; fi
}

as_root() {
  if [[ "$(id -u)" -eq 0 ]]; then "$@"; else sudo "$@"; fi
}

# Linuxbrew prerequisites plus the libraries mise needs to build Ruby.
# Only touches the package manager when something is actually missing, so a
# second run doesn't re-trigger an update/install on every invocation.
install_linux_prereqs() {
  case "$1" in
    debian)
      local pkgs=(build-essential procps curl file git zsh \
        libssl-dev libyaml-dev zlib1g-dev libffi-dev libreadline-dev libgmp-dev)
      local missing=() pkg
      for pkg in "${pkgs[@]}"; do
        if ! dpkg-query -W -f='${Status}' "$pkg" 2>/dev/null | grep -q '^install ok installed$'; then
          missing+=("$pkg")
        fi
      done
      if [[ "${#missing[@]}" -gt 0 ]]; then
        log "Installing apt prerequisites"
        as_root apt-get update -qq
        as_root env DEBIAN_FRONTEND=noninteractive apt-get install -y -qq "${missing[@]}"
      fi
      ;;
    arch)
      local pkgs=(base-devel procps-ng curl file git zsh openssl libyaml zlib libffi readline gmp)
      if [[ -n "$(pacman -T "${pkgs[@]}" 2>/dev/null || true)" ]]; then
        log "Installing pacman prerequisites"
        as_root pacman -Syu --needed --noconfirm "${pkgs[@]}"
      fi
      ;;
  esac
}

brew_shellenv() {
  local brew candidates
  if [[ -n "${DOTFILES_BREW_PATHS:-}" ]]; then
    # shellcheck disable=SC2206
    candidates=($DOTFILES_BREW_PATHS)
  else
    candidates=(/opt/homebrew/bin/brew /usr/local/bin/brew /home/linuxbrew/.linuxbrew/bin/brew)
  fi
  for brew in "${candidates[@]}"; do
    if [[ -x "$brew" ]]; then
      eval "$("$brew" shellenv bash)"
      command -v brew >/dev/null 2>&1 && return 0
    fi
  done
  return 1
}

ensure_brew() {
  local os="$1"
  if ! brew_shellenv; then
    if [[ "$os" == macos ]] && $INTERACTIVE; then
      log "Priming sudo (Homebrew's installer may need it)"
      sudo -v
    fi
    log "Installing Homebrew"
    NONINTERACTIVE=1 /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
    brew_shellenv || die "Homebrew installed but brew was not found"
  fi
  export HOMEBREW_NO_AUTO_UPDATE=1
  if [[ "${DOTFILES_BREW_UPDATE:-}" == 1 ]]; then
    log "Updating Homebrew"
    brew update
  fi
}

install_packages() {
  log "Installing Brewfile packages"
  brew bundle --file="$DOTFILES_DIR/Brewfile"
  if [[ "$1" == macos ]]; then
    log "Installing macOS apps"
    # Best-effort: a cask conflicting with an app installed outside brew, or
    # one that needs interactive sudo, must not abort the whole install.
    brew bundle --file="$DOTFILES_DIR/Brewfile.macos" ||
      log "warning: some macOS apps failed to install; continuing"
  fi
}

install_runtimes() {
  if command -v mise >/dev/null 2>&1; then
    log "Installing mise runtimes"
    # Run from $HOME so a mise.toml in the caller's cwd isn't auto-trusted.
    (cd "$HOME" && MISE_YES=1 mise install)
  fi
}

sync_nvim() {
  if command -v nvim >/dev/null 2>&1; then
    log "Restoring neovim plugins"
    # "restore" installs exactly what lazy-lock.json pins; "sync" would
    # also upgrade plugins and rewrite that tracked lockfile.
    nvim --headless "+Lazy! restore" +qa </dev/null
  fi
}

# Homebrew refuses to run as root, on every platform.
refuse_root() {
  if [[ "$(id -u)" -eq 0 ]]; then
    die "run as a regular user with sudo access; Homebrew refuses to run as root"
  fi
}

# Print this script's header comment (lines 2.. up to the first non-comment
# line), stripped of the leading '#'. Used for --help.
print_usage() {
  local line rest
  {
    read -r line
    while IFS= read -r line; do
      case "$line" in
        '#'*) : ;;
        *) break ;;
      esac
      rest="${line#\#}"
      printf '%s\n' "${rest# }"
    done
  } < "${BASH_SOURCE[0]}"
}

main() {
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --yes|-y) INTERACTIVE=false; shift ;;
      -h|--help) print_usage; exit 0 ;;
      *) die "unknown argument: $1" ;;
    esac
  done
  if [[ ! -t 0 ]]; then INTERACTIVE=false; fi

  local os
  os="$(detect_os)"
  [[ "$os" != unsupported ]] || die "unsupported OS (expected macOS, Debian/Ubuntu or Arch)"
  refuse_root

  if [[ "$os" != macos ]]; then install_linux_prereqs "$os"; fi
  ensure_brew "$os"
  install_packages "$os"
  mkdir -p "$CONFIG_DIR" "$DOTFILES_DIR/zshrc/tmp"
  link_home
  prepare_stow_targets
  # The checkout may be ~/.config itself; prepare_stow_targets already
  # skips, and there is nothing for stow to link in that case either.
  if [[ ! "$CONFIG_DIR" -ef "$DOTFILES_DIR" ]]; then
    stow_dotfiles
  fi
  install_runtimes
  sync_nvim
  setup_git_identity
  log "Dotfiles installed"
}

if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
  set -euo pipefail
  main "$@"
fi
