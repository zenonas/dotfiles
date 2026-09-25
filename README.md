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

- Packages come from Homebrew on every OS (`Brewfile`; `Brewfile.macos` adds casks on macOS). On Linux, apt or pacman installs only Homebrew's prerequisites.
- Config is stowed into `~/.config`. `~/.zshrc`, `~/.dotfiles` and `~/.tool-versions` are symlinks.
- Anything replaced is moved to `~/.dotfiles_backup/<timestamp>/`.
- Set `GIT_NAME` and `GIT_EMAIL` to write your git identity to `~/.gitconfig` without prompting.
- On Linux, run as a regular user with sudo (Homebrew refuses root).

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
