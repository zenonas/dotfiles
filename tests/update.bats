#!/usr/bin/env bats

setup() {
  SOURCE_ROOT="$(cd "$BATS_TEST_DIRNAME/.." && pwd -P)"
  export HOME="$BATS_TEST_TMPDIR/home"
  mkdir -p "$HOME"
  export GIT_CONFIG_NOSYSTEM=1
  export GIT_AUTHOR_NAME=test GIT_AUTHOR_EMAIL=test@example.com
  export GIT_COMMITTER_NAME=test GIT_COMMITTER_EMAIL=test@example.com

  ORIGIN="$BATS_TEST_TMPDIR/origin.git"
  SEED="$BATS_TEST_TMPDIR/seed"
  CLONE="$BATS_TEST_TMPDIR/clone"
  git init -q --bare -b main "$ORIGIN"
  git clone -q "$ORIGIN" "$SEED" 2>/dev/null
  cp "$SOURCE_ROOT/update.sh" "$SEED/"
  printf '#!/usr/bin/env bash\necho "install ran BREW_UPDATE=${DOTFILES_BREW_UPDATE:-} args=$*"\n' > "$SEED/install.sh"
  chmod +x "$SEED/install.sh" "$SEED/update.sh"
  git -C "$SEED" add . && git -C "$SEED" commit -qm init && git -C "$SEED" push -q origin HEAD:main
  git clone -q "$ORIGIN" "$CLONE"
}

push_new_commit() {
  echo new > "$SEED/NEWFILE"
  git -C "$SEED" add NEWFILE && git -C "$SEED" commit -qm new && git -C "$SEED" push -q origin HEAD:main
}

@test "pulls, then runs install.sh with a brew update and the same args" {
  push_new_commit
  run "$CLONE/update.sh" --yes
  [ "$status" -eq 0 ]
  [ -f "$CLONE/NEWFILE" ]
  [[ "$output" == *"install ran BREW_UPDATE=1 args=--yes"* ]]
}

@test "skips the pull when there are uncommitted changes" {
  push_new_commit
  echo dirty > "$CLONE/LOCAL"
  run "$CLONE/update.sh"
  [ "$status" -eq 0 ]
  [ ! -f "$CLONE/NEWFILE" ]
  [[ "$output" == *"uncommitted changes"* ]]
  [[ "$output" == *"install ran"* ]]
}

@test "--help prints usage, does not pull, and does not touch HEAD" {
  before="$(git -C "$CLONE" rev-parse HEAD)"
  push_new_commit
  run "$CLONE/update.sh" --help
  [ "$status" -eq 0 ]
  [[ "$output" == *"Usage: ./update.sh"* ]]
  [[ "$output" != *"install ran"* ]]
  after="$(git -C "$CLONE" rev-parse HEAD)"
  [ "$after" = "$before" ]
  [ ! -f "$CLONE/NEWFILE" ]
}

@test "--bogus exits 2 with an unknown-argument message" {
  run "$CLONE/update.sh" --bogus
  [ "$status" -eq 2 ]
  [[ "$output" == *"unknown argument: --bogus"* ]]
}

@test "a failed ff-only pull (divergent history) still applies the current checkout" {
  echo mine > "$CLONE/MINE"
  git -C "$CLONE" add MINE && git -C "$CLONE" commit -qm mine
  before="$(git -C "$CLONE" rev-parse HEAD)"
  push_new_commit
  run "$CLONE/update.sh"
  [ "$status" -eq 0 ]
  after="$(git -C "$CLONE" rev-parse HEAD)"
  [ "$after" = "$before" ]
  [ -f "$CLONE/MINE" ]
  [ ! -f "$CLONE/NEWFILE" ]
  [[ "$output" == *"pull failed"* ]]
  [[ "$output" != *"diverged"* ]]
  [[ "$output" == *"install ran"* ]]
}
