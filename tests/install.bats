#!/usr/bin/env bats
# Unit tests for install.sh functions. Runs in a throwaway HOME.

setup() {
  REPO_ROOT="$(cd "$BATS_TEST_DIRNAME/.." && pwd -P)"
  # shellcheck source=../install.sh
  source "$REPO_ROOT/install.sh"

  export HOME="$BATS_TEST_TMPDIR/home"
  mkdir -p "$HOME"

  # A fake checkout so tests never touch the real repo.
  FAKE_DOTFILES="$BATS_TEST_TMPDIR/dotfiles"
  mkdir -p "$FAKE_DOTFILES"/{nvim,zshrc,scripts,tests,git}
  touch "$FAKE_DOTFILES/zshrc/zshrc" "$FAKE_DOTFILES/.tool-versions"
  FAKE_DOTFILES="$(cd "$FAKE_DOTFILES" && pwd -P)"

  DOTFILES_DIR="$FAKE_DOTFILES"
  CONFIG_DIR="$HOME/.config"
  BACKUP_ROOT="$HOME/.dotfiles_backup"
  BACKUP_DIR=""
  INTERACTIVE=false
}

os_release() {
  local file="$BATS_TEST_TMPDIR/os-release"
  printf '%s\n' "$@" > "$file"
  echo "$file"
}

@test "detect_os: macOS" {
  DOTFILES_UNAME=Darwin run detect_os
  [ "$output" = "macos" ]
}

@test "detect_os: Debian and Ubuntu are debian" {
  DOTFILES_UNAME=Linux DOTFILES_OS_RELEASE="$(os_release 'ID=debian')" run detect_os
  [ "$output" = "debian" ]
  DOTFILES_UNAME=Linux DOTFILES_OS_RELEASE="$(os_release 'ID=ubuntu' 'ID_LIKE=debian')" run detect_os
  [ "$output" = "debian" ]
}

@test "detect_os: Arch and derivatives are arch" {
  DOTFILES_UNAME=Linux DOTFILES_OS_RELEASE="$(os_release 'ID=arch')" run detect_os
  [ "$output" = "arch" ]
  DOTFILES_UNAME=Linux DOTFILES_OS_RELEASE="$(os_release 'ID=manjaro' 'ID_LIKE=arch')" run detect_os
  [ "$output" = "arch" ]
}

@test "detect_os: anything else is unsupported" {
  DOTFILES_UNAME=Linux DOTFILES_OS_RELEASE="$(os_release 'ID=fedora')" run detect_os
  [ "$output" = "unsupported" ]
}
