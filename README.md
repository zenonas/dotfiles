dotfiles
========

My shell, editor and terminal config plus the developer tool stack, for macOS, Debian/Ubuntu and Arch.

Install
-------

```bash
git clone git@github.com:zenonas/dotfiles.git ~/code/dotfiles
~/code/dotfiles/install.sh          # prompts for git identity if unset
~/code/dotfiles/install.sh --yes    # never prompts (unattended)
```

- Packages come from Homebrew on every OS (`Brewfile`; `Brewfile.macos` adds casks on macOS, best-effort — a cask conflict or one needing interactive sudo won't abort the install). On Linux, apt or pacman installs only Homebrew's prerequisites, and only the ones actually missing.
- Config is stowed into `~/.config`. `~/.zshrc`, `~/.dotfiles` and `~/.tool-versions` are symlinks.
- Anything replaced is moved to `~/.dotfiles_backup/<timestamp>/`.
- Set `GIT_NAME` and `GIT_EMAIL` to write your git identity to `~/.gitconfig` without prompting.
- Run as a regular user with sudo access, on every platform (Homebrew refuses to run as root).
- On macOS, `--yes` needs cached or passwordless sudo on the first install (Homebrew's installer may need it).

Re-running `install.sh` is safe.

Update
------

```bash
~/code/dotfiles/update.sh   # or: make update
```

Pulls (skipped if you have uncommitted changes), refreshes Homebrew, then re-applies everything.

Tests
-----

```bash
make test   # needs bats-core and shellcheck
```
