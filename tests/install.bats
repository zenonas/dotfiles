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

@test "link_home: creates ~/.dotfiles, ~/.zshrc and ~/.tool-versions" {
  link_home
  [ "$(readlink "$HOME/.dotfiles")" = "$FAKE_DOTFILES" ]
  [ "$(readlink "$HOME/.zshrc")" = "$HOME/.config/zshrc/zshrc" ]
  [ "$(readlink "$HOME/.tool-versions")" = "$HOME/.dotfiles/.tool-versions" ]
  [ ! -e "$BACKUP_ROOT" ]
}

@test "link_home: second run changes nothing" {
  link_home
  BACKUP_DIR=""
  link_home
  [ ! -e "$BACKUP_ROOT" ]
}

@test "link_home: moves an existing real ~/.zshrc to the backup" {
  echo "old zshrc" > "$HOME/.zshrc"
  link_home
  [ -L "$HOME/.zshrc" ]
  [ "$(cat "$BACKUP_DIR/.zshrc")" = "old zshrc" ]
}

@test "link_home: replaces a link that points at another checkout" {
  ln -s /somewhere/else "$HOME/.dotfiles"
  link_home
  [ "$(readlink "$HOME/.dotfiles")" = "$FAKE_DOTFILES" ]
  [ "$(readlink "$BACKUP_DIR/.dotfiles")" = "/somewhere/else" ]
}

@test "link_home: leaves a checkout that lives at ~/.dotfiles alone" {
  mv "$FAKE_DOTFILES" "$HOME/.dotfiles"
  DOTFILES_DIR="$(cd "$HOME/.dotfiles" && pwd -P)"
  link_home
  [ -d "$HOME/.dotfiles" ] && [ ! -L "$HOME/.dotfiles" ]
  [ -f "$HOME/.dotfiles/zshrc/zshrc" ]
}

@test "stow_packages: lists config dirs but not scripts or tests" {
  run stow_packages
  [[ "$output" == *"nvim"* ]]
  [[ "$output" == *"zshrc"* ]]
  [[ "$output" != *"scripts"* ]]
  [[ "$output" != *"tests"* ]]
}

@test "prepare_stow_targets: backs up a real ~/.config dir" {
  mkdir -p "$CONFIG_DIR/nvim"
  echo "mine" > "$CONFIG_DIR/nvim/init.lua"
  prepare_stow_targets
  [ ! -e "$CONFIG_DIR/nvim" ]
  [ "$(cat "$BACKUP_DIR/nvim/init.lua")" = "mine" ]
}

@test "prepare_stow_targets: keeps links into this checkout" {
  mkdir -p "$CONFIG_DIR"
  ln -s "$FAKE_DOTFILES/nvim" "$CONFIG_DIR/nvim"
  prepare_stow_targets
  [ -L "$CONFIG_DIR/nvim" ]
  [ -z "$BACKUP_DIR" ]
}

@test "prepare_stow_targets: moves links into another checkout" {
  mkdir -p "$CONFIG_DIR" "$BATS_TEST_TMPDIR/other/nvim"
  ln -s "$BATS_TEST_TMPDIR/other/nvim" "$CONFIG_DIR/nvim"
  prepare_stow_targets
  [ ! -e "$CONFIG_DIR/nvim" ]
  [ -L "$BACKUP_DIR/nvim" ]
}

@test "setup_git_identity: writes GIT_NAME/GIT_EMAIL to ~/.gitconfig only" {
  mkdir -p "$CONFIG_DIR/git"
  : > "$CONFIG_DIR/git/config"
  GIT_NAME="Ada Lovelace" GIT_EMAIL="ada@example.com" setup_git_identity
  [ "$(git config --file "$HOME/.gitconfig" user.name)" = "Ada Lovelace" ]
  [ "$(git config --file "$HOME/.gitconfig" user.email)" = "ada@example.com" ]
  [ ! -s "$CONFIG_DIR/git/config" ]
}

@test "setup_git_identity: non-interactive without env writes nothing" {
  unset GIT_NAME GIT_EMAIL
  INTERACTIVE=false
  setup_git_identity < /dev/null
  [ ! -e "$HOME/.gitconfig" ]
}
