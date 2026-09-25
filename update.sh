#!/usr/bin/env bash
# Pull the latest dotfiles, then re-apply them. Safe to re-run.
#
# Usage: ./update.sh [--yes]
#
#   --yes   passed straight through to install.sh (never prompt)
#
# The pull is skipped (with a warning) when the checkout has uncommitted
# changes. If `git pull --ff-only` fails for any other reason (for example
# the local branch has diverged from upstream), the current checkout is
# applied as-is; everything else still runs.
#
# Must stay compatible with macOS's /bin/bash 3.2.
set -euo pipefail

DOTFILES_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"

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
  local arg
  for arg in "$@"; do
    case "$arg" in
      --yes|-y) : ;;
      -h|--help) print_usage; exit 0 ;;
      *) printf 'dotfiles: unknown argument: %s\n' "$arg" >&2; exit 2 ;;
    esac
  done

  if [[ -n "$(git -C "$DOTFILES_DIR" status --porcelain)" ]]; then
    echo "dotfiles: not pulling, $DOTFILES_DIR has uncommitted changes" >&2
  elif ! git -C "$DOTFILES_DIR" pull --ff-only --quiet; then
    echo "dotfiles: pull failed (see git's message above); applying the current checkout" >&2
  fi

  DOTFILES_BREW_UPDATE=1 exec "$DOTFILES_DIR/install.sh" "$@"
}

main "$@"
