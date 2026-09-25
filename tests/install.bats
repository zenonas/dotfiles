#!/usr/bin/env bats
# Unit tests for install.sh functions. Runs in a throwaway HOME.

setup() {
  REPO_ROOT="$(cd "$BATS_TEST_DIRNAME/.." && pwd -P)"

  export HOME="$BATS_TEST_TMPDIR/home"
  mkdir -p "$HOME"

  # shellcheck source=../install.sh
  source "$REPO_ROOT/install.sh"

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

  # A directory of stub commands, for functions that shell out. Tests that
  # need one prepend it to PATH explicitly: PATH="$STUB_BIN:$PATH".
  STUB_BIN="$BATS_TEST_TMPDIR/bin"
  mkdir -p "$STUB_BIN"
}

os_release() {
  local file="$BATS_TEST_TMPDIR/os-release"
  printf '%s\n' "$@" > "$file"
  echo "$file"
}

# write_stub NAME BODY: create an executable $STUB_BIN/NAME running BODY.
write_stub() {
  local name="$1"
  cat > "$STUB_BIN/$name" <<STUBEOF
#!/usr/bin/env bash
$2
STUBEOF
  chmod +x "$STUB_BIN/$name"
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

@test "backup: refuses to move a directory that contains the checkout" {
  mkdir -p "$HOME/.dotfiles/dotfiles"
  DOTFILES_DIR="$(cd "$HOME/.dotfiles/dotfiles" && pwd -P)"
  run backup "$HOME/.dotfiles"
  [ "$status" -ne 0 ]
  [[ "$output" == *"refusing to move"* ]]
  [ -d "$HOME/.dotfiles/dotfiles" ]
}

@test "link_home: refuses to move ~/.dotfiles when the checkout lives inside it" {
  mkdir -p "$HOME/.dotfiles/dotfiles"
  DOTFILES_DIR="$(cd "$HOME/.dotfiles/dotfiles" && pwd -P)"
  run link_home
  [ "$status" -ne 0 ]
  [[ "$output" == *"refusing to move"* ]]
  [ -d "$HOME/.dotfiles/dotfiles" ]
}

@test "prepare_stow_targets: skips entirely when the checkout is ~/.config" {
  mkdir -p "$CONFIG_DIR/nvim"
  echo mine > "$CONFIG_DIR/nvim/init.lua"
  DOTFILES_DIR="$(cd "$CONFIG_DIR" && pwd -P)"
  run prepare_stow_targets
  [ "$status" -eq 0 ]
  [ -z "$BACKUP_DIR" ]
  [ "$(cat "$CONFIG_DIR/nvim/init.lua")" = "mine" ]
}

@test "backup: refuses to overwrite an existing backup with the same basename" {
  mkdir -p "$HOME/a/dupe" "$HOME/b/dupe"
  backup "$HOME/a/dupe"
  run backup "$HOME/b/dupe"
  [ "$status" -ne 0 ]
  [[ "$output" == *"refusing to overwrite"* ]]
}

@test "backup: two runs in the same second get different backup dirs" {
  mkdir -p "$HOME/one"
  backup "$HOME/one"
  first="$BACKUP_DIR"
  BACKUP_DIR=""
  mkdir -p "$HOME/two"
  backup "$HOME/two"
  [ "$first" != "$BACKUP_DIR" ]
}

@test "backup: logs the symlink target when moving a link" {
  ln -s /somewhere/else "$HOME/dangling-link"
  run backup "$HOME/dangling-link"
  [ "$status" -eq 0 ]
  [[ "$output" == *"(-> /somewhere/else)"* ]]
}

@test "sync_nvim: restores plugins from the lockfile, does not sync (which would rewrite it)" {
  write_stub nvim 'printf "%s\n" "$@" > "$NVIM_ARGS_LOG"'
  export NVIM_ARGS_LOG="$BATS_TEST_TMPDIR/nvim.args"
  PATH="$STUB_BIN:$PATH" run sync_nvim
  [ "$status" -eq 0 ]
  [[ "$(cat "$NVIM_ARGS_LOG")" == *"Lazy! restore"* ]]
  [[ "$(cat "$NVIM_ARGS_LOG")" != *"Lazy! sync"* ]]
}

@test "Brewfile: tlrc instead of the disabled tldr formula, no duplicate watch" {
  [ "$(grep -c "^brew 'watch'\$" "$REPO_ROOT/Brewfile")" -eq 1 ]
  [ "$(grep -c "^brew 'tldr'\$" "$REPO_ROOT/Brewfile")" -eq 0 ]
  grep -q "^brew 'tlrc'\$" "$REPO_ROOT/Brewfile"
}

@test "Brewfile.macos: colima restarts only on install/upgrade, not on every run" {
  grep -q "^brew 'colima', restart_service: true\$" "$REPO_ROOT/Brewfile.macos"
  [ "$(grep -c 'restart_service: :always' "$REPO_ROOT/Brewfile.macos")" -eq 0 ]
}

@test "Brewfile.macos: aerospace cask is fully qualified and trusted (third-party tap)" {
  # trusted: true only takes effect for a fully-qualified cask name
  # ("<tap>/<name>"); Homebrew::Trust checks Utils.full_name?, which requires
  # exactly two slashes, so an unqualified `cask "aerospace"` would silently
  # not be trusted.
  grep -q '^cask "nikitabobko/tap/aerospace", trusted: true$' "$REPO_ROOT/Brewfile.macos"
}

@test "install_packages: replaces the disabled tldr formula with tlrc when tldr is installed" {
  write_stub brew '
    printf "brew %s\n" "$*" >> "$CALLS_LOG"
    case "$*" in
      "list --formula tldr") exit 0 ;;
      "uninstall --formula tldr") exit 0 ;;
      *) exit 0 ;;
    esac
  '
  export CALLS_LOG="$BATS_TEST_TMPDIR/calls.log"
  : > "$CALLS_LOG"
  run bash -c "
    set -euo pipefail
    source '$REPO_ROOT/install.sh'
    DOTFILES_DIR='$FAKE_DOTFILES'
    CALLS_LOG='$CALLS_LOG'
    PATH='$STUB_BIN:'\"\$PATH\"
    install_packages macos
  "
  [ "$status" -eq 0 ]
  [[ "$output" == *"Replacing the disabled tldr formula with tlrc"* ]]
  grep -q "uninstall --formula tldr" "$CALLS_LOG"
}

@test "install_packages: does not touch tldr when it is not installed" {
  write_stub brew '
    printf "brew %s\n" "$*" >> "$CALLS_LOG"
    case "$*" in
      "list --formula tldr") exit 1 ;;
      *) exit 0 ;;
    esac
  '
  export CALLS_LOG="$BATS_TEST_TMPDIR/calls.log"
  : > "$CALLS_LOG"
  run bash -c "
    set -euo pipefail
    source '$REPO_ROOT/install.sh'
    DOTFILES_DIR='$FAKE_DOTFILES'
    CALLS_LOG='$CALLS_LOG'
    PATH='$STUB_BIN:'\"\$PATH\"
    install_packages macos
  "
  [ "$status" -eq 0 ]
  [[ "$output" != *"Replacing the disabled tldr formula with tlrc"* ]]
  ! grep -q "uninstall --formula tldr" "$CALLS_LOG"
}

@test "install_packages: a Brewfile.macos bundle failure is a warning, not fatal" {
  write_stub brew 'case "$*" in *Brewfile.macos*) exit 1 ;; esac; exit 0'
  run bash -c "
    set -euo pipefail
    source '$REPO_ROOT/install.sh'
    DOTFILES_DIR='$FAKE_DOTFILES'
    PATH='$STUB_BIN:'\"\$PATH\"
    install_packages macos
  "
  [ "$status" -eq 0 ]
  [[ "$output" == *"warning: some macOS apps failed to install"* ]]
}

@test "install_packages: a main Brewfile bundle failure is still fatal" {
  write_stub brew 'case "$*" in *Brewfile.macos*) exit 0 ;; *) exit 1 ;; esac'
  run bash -c "
    set -euo pipefail
    source '$REPO_ROOT/install.sh'
    DOTFILES_DIR='$FAKE_DOTFILES'
    PATH='$STUB_BIN:'\"\$PATH\"
    install_packages macos
  "
  [ "$status" -ne 0 ]
}

@test "install_runtimes: runs mise install from \$HOME, not the caller's cwd" {
  write_stub mise 'pwd -P > "$MISE_PWD_LOG"'
  export MISE_PWD_LOG="$BATS_TEST_TMPDIR/mise.pwd"
  local other_dir="$BATS_TEST_TMPDIR/elsewhere"
  mkdir -p "$other_dir"
  ( cd "$other_dir" && PATH="$STUB_BIN:$PATH" install_runtimes )
  [ "$(cat "$MISE_PWD_LOG")" = "$(cd "$HOME" && pwd -P)" ]
}

@test "brew_shellenv: requests bash syntax and succeeds only when brew lands on PATH" {
  local dir="$BATS_TEST_TMPDIR/opt-brew"
  mkdir -p "$dir"
  cat > "$dir/brew" <<STUBEOF
#!/usr/bin/env bash
printf '%s\n' "\$*" >> "$BATS_TEST_TMPDIR/brew.args"
printf 'export PATH="%s:\$PATH"\n' "$dir"
STUBEOF
  chmod +x "$dir/brew"
  DOTFILES_BREW_PATHS="$dir/brew" run brew_shellenv
  [ "$status" -eq 0 ]
  [ "$(cat "$BATS_TEST_TMPDIR/brew.args")" = "shellenv bash" ]
}

@test "brew_shellenv: fails when the shellenv output does not put brew on PATH" {
  local dir="$BATS_TEST_TMPDIR/opt-brew"
  mkdir -p "$dir"
  cat > "$dir/brew" <<'STUBEOF'
#!/usr/bin/env bash
printf 'export PATH="/nonexistent-dir:$PATH"\n'
STUBEOF
  chmod +x "$dir/brew"
  # A minimal PATH with no real brew on it, so the eval'd (bogus) PATH is
  # the only thing that could make `command -v brew` succeed.
  DOTFILES_BREW_PATHS="$dir/brew" PATH=/usr/bin:/bin run brew_shellenv
  [ "$status" -eq 1 ]
}

@test "install_linux_prereqs debian: installs nothing when all packages are present" {
  write_stub dpkg-query 'printf "install ok installed"'
  write_stub apt-get 'printf "apt-get %s\n" "$*" >> "$CALLS_LOG"'
  write_stub sudo 'printf "sudo %s\n" "$*" >> "$CALLS_LOG"; if [ "$1" = "-v" ]; then exit 0; fi; "$@"'
  export CALLS_LOG="$BATS_TEST_TMPDIR/calls.log"
  : > "$CALLS_LOG"
  PATH="$STUB_BIN:$PATH" install_linux_prereqs debian
  [ ! -s "$CALLS_LOG" ]
}

@test "install_linux_prereqs debian: installs only the missing packages" {
  write_stub dpkg-query 'if [ "$3" = "git" ]; then printf "install ok installed"; exit 0; fi; exit 1'
  write_stub apt-get 'printf "apt-get %s\n" "$*" >> "$CALLS_LOG"'
  write_stub sudo 'printf "sudo %s\n" "$*" >> "$CALLS_LOG"; if [ "$1" = "-v" ]; then exit 0; fi; "$@"'
  export CALLS_LOG="$BATS_TEST_TMPDIR/calls.log"
  : > "$CALLS_LOG"
  PATH="$STUB_BIN:$PATH" install_linux_prereqs debian
  grep -q "update -qq" "$CALLS_LOG"
  grep -qw build-essential "$CALLS_LOG"
  ! grep -qw git "$CALLS_LOG"
}

@test "install_linux_prereqs arch: installs nothing when all packages are present" {
  write_stub pacman ': # -T with everything satisfied prints nothing'
  write_stub sudo 'printf "sudo %s\n" "$*" >> "$CALLS_LOG"; "$@"'
  export CALLS_LOG="$BATS_TEST_TMPDIR/calls.log"
  : > "$CALLS_LOG"
  PATH="$STUB_BIN:$PATH" install_linux_prereqs arch
  [ ! -s "$CALLS_LOG" ]
}

@test "install_linux_prereqs arch: installs prerequisites when something is missing" {
  write_stub pacman 'if [ "$1" = "-T" ]; then shift; echo "$1"; exit 0; fi; printf "pacman %s\n" "$*" >> "$CALLS_LOG"'
  write_stub sudo 'printf "sudo %s\n" "$*" >> "$CALLS_LOG"; "$@"'
  export CALLS_LOG="$BATS_TEST_TMPDIR/calls.log"
  : > "$CALLS_LOG"
  PATH="$STUB_BIN:$PATH" install_linux_prereqs arch
  grep -q "Syu" "$CALLS_LOG"
  grep -qw base-devel "$CALLS_LOG"
}

@test "ensure_brew: primes sudo on macOS before an interactive Homebrew install" {
  write_stub curl 'echo ":"'
  write_stub sudo 'printf "sudo %s\n" "$*" >> "$CALLS_LOG"; if [ "$1" = "-v" ]; then exit 0; fi; "$@"'
  export CALLS_LOG="$BATS_TEST_TMPDIR/calls.log"
  : > "$CALLS_LOG"
  DOTFILES_BREW_PATHS="/nonexistent/brew"
  INTERACTIVE=true
  PATH="$STUB_BIN:$PATH" run ensure_brew macos
  grep -q "sudo -v" "$CALLS_LOG"
}

@test "ensure_brew: does not prime sudo when non-interactive" {
  write_stub curl 'echo ":"'
  write_stub sudo 'printf "sudo %s\n" "$*" >> "$CALLS_LOG"; if [ "$1" = "-v" ]; then exit 0; fi; "$@"'
  export CALLS_LOG="$BATS_TEST_TMPDIR/calls.log"
  : > "$CALLS_LOG"
  DOTFILES_BREW_PATHS="/nonexistent/brew"
  INTERACTIVE=false
  PATH="$STUB_BIN:$PATH" run ensure_brew macos
  ! grep -q "sudo -v" "$CALLS_LOG"
}

@test "refuse_root: dies when running as root, regardless of OS" {
  write_stub id 'echo 0'
  PATH="$STUB_BIN:$PATH" run refuse_root
  [ "$status" -ne 0 ]
  [[ "$output" == *"refuses to run as root"* ]]
}

@test "refuse_root: allows a regular user" {
  write_stub id 'echo 501'
  PATH="$STUB_BIN:$PATH" run refuse_root
  [ "$status" -eq 0 ]
}

@test "print_usage: excludes the bash-3.2 developer note" {
  run print_usage
  [ "$status" -eq 0 ]
  [[ "$output" == *"Usage: ./install.sh"* ]]
  [[ "$output" != *"bash 3.2"* ]]
}
