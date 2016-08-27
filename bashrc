# Detect dotfile path
SOURCE="${BASH_SOURCE[0]}"
while [ -h "$SOURCE" ]; do
  DIR="$( cd -P "$( dirname "$SOURCE" )" && pwd )"
  SOURCE="$(readlink "$SOURCE")"
  [[ $SOURCE != /* ]] && SOURCE="$DIR/$SOURCE"
done
DIR="$( cd -P "$( dirname "$SOURCE" )" && pwd )"

function source_if_present(){
  local file="$1"
  [[ -f $file ]] && source "$file"
}

# Source scripts and helper functions
source_if_present $(brew --prefix)/etc/bash_completion
source_if_present $DIR/scripts/alias_completion.sh
source_if_present $DIR/scripts/git-niceness.sh
source_if_present $DIR/scripts/git-prompt.sh
source_if_present /usr/local/etc/bash_completion.d/git-completion.bash

# Source Configs
source_if_present $DIR/bash/prompt
source_if_present $DIR/common/aliases
source_if_present $DIR/common/load

alias_completion
