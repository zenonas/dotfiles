### Set Colour Vars ###
bold="$(tput bold)"
reset="\001$(tput sgr0)\002"

blue="\001$bold$(tput setaf 4)\002"
cyan="\001$bold$(tput setaf 6)\002"
green="\001$bold$(tput setaf 2)\002"
purple="\001$bold$(tput setaf 5)\002"
red="\001$bold$(tput setaf 1)\002"
white="\001$bold$(tput setaf 7)\002"
yellow="\001$bold$(tput setaf 3)\002"

### Git Log Niceness ###

_I_=' '
HASH="%C(green)%h%C(reset)"
AGE="%C(yellow)%ar%C(reset)"
AUTHOR="%C(bold blue)%an%C(reset)"
REFS="%C(bold red)%d%C(reset)"
COMMENT="%s"

FORMAT="$HASH$_I_$AGE$_I_$AUTHOR$_I_$REFS $COMMENT"

git_pretty_log() {
  git log --graph --decorate --pretty="tformat:${FORMAT}" $* |
  less -FXRS
}

git_pretty_log_details(){
  git log --graph --numstat --decorate --pretty="tformat:${FORMAT}" $* |
  less -FXRS
}

git_update(){
  local updir=$1
  echo "git pull (in $updir)"
  if pushd $updir >/dev/null ; then
    git pull
    popd >/dev/null
  fi
}

### Git prompt niceness ###

function colour_for_minutes {
  local minutes="$1"
  local colour=$green
  if [[ $minutes -gt 30 ]]; then colour=$red
    elif [[ $minutes -gt 15 ]]; then colour=$yellow
  fi
  echo -e "$colour"
}

function git_working_changed {
  git diff --quiet 2> /dev/null
  if [[ $? == 0 ]]; then return 1; else return 0; fi
}

function git_staging_changed {
  git diff --cached --quiet 2> /dev/null
  if [[ $? == 0 ]]; then return 1; else return 0; fi
}

function git_changed {
  $(git_working_changed) || $(git_staging_changed)
}

function git_branch {
  echo "$(__git_ps1 "%s")"
}

function git_seconds_since_commit {
  now=`date +%s`
  local last_commit=`git log --pretty=format:'%at' -1`
  local seconds=$((now-last_commit))
  echo $seconds
}

function git_mins_since_commit {
  echo "$(seconds_to_minutes $(git_seconds_since_commit))"
}

function seconds_to_minutes {
  local secs="$1"
  echo "$((${secs}/60))"
}

function git_branch_colour {
  local colour=$blue
  if $(git_changed) ; then
    local minutes_since_commit="$(git_mins_since_commit)"
    colour=$(colour_for_minutes $minutes_since_commit)
  fi
  echo -e $colour
}

git_prompt() {
  if [ -n "$(__gitdir)" ]; then
    echo -e "$(git_branch_colour)($(git_branch))"
  fi
}
