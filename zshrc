# Completion System Setup
autoload -Uz compinit
if [ $(date +'%j') != $(stat -f '%Sm' -t '%j' ~/.zcompdump) ]; then
  compinit
else
  compinit -C
fi

# Environment Variables
export EDITOR="vim"
export VISUAL="$EDITOR"
export PAGER=less
export GIT_PAGER=less
export LESS='-i -R'
export TERM='xterm-256color'
export LC_CTYPE=en_US.UTF-8
export LANG=en_US.UTF-8

# History Configuration
HISTSIZE=20000
SAVEHIST=15000
HISTFILE=$HOME/.history
setopt EXTENDED_HISTORY HIST_EXPIRE_DUPS_FIRST HIST_VERIFY INC_APPEND_HISTORY

# Directory Options
setopt AUTO_CD AUTO_PUSHD PUSHD_IGNORE_DUPS AUTO_NAME_DIRS
DIRSTACKSIZE=20

# General Options
setopt ALWAYS_TO_END NO_BEEP RM_STAR_WAIT
autoload colors && colors

# Key Bindings
bindkey -v
KEYTIMEOUT=1
bindkey '^R' history-incremental-search-backward

# Completion System
zstyle ':completion:*' completer _complete _approximate _expand
zstyle ':completion:*' matcher-list 'm:{a-z}={A-Z}'
zstyle ':completion:*:default' list-prompt '%S%M matches%s'
zstyle ':completion:*:default' menu 'select=0'
zstyle ':completion:*' file-sort modification reverse
zstyle ':completion:*' list-colors "=(#b) #([0-9]#)*=36=31"
zstyle ':completion:*:manuals' separate-sections true
zstyle ':completion:*' max-errors 2

# Lazy load node version manager
export NVM_LAZY_LOAD=true
export NVM_DIR="$HOME/.nvm"
nvm() {
  unset -f nvm
  [ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"
  nvm "$@"
}

# Lazy load conda
conda() {
  unset -f conda
  # Cache conda initialization
  eval "$(conda 'shell.zsh' 'hook' 2>/dev/null)"
  conda "$@"
}

# Initialize rbenv
eval "$(rbenv init -)"

# Aliases
alias py=python3
alias python=python3
alias pip=pip3
alias r=rails
alias grep='nocorrect grep --color=auto'
alias rgrep='nocorrect grep -inR --color=auto --exclude-dir={./app/assets,./tmp,./log,./.git,./node_modules,./public,./coverage} --exclude="./.overmind.sock"'
alias ls='ls -G'
alias l='ls'
alias ll='ls -alh'
alias pg='ps auxwww | grep'
alias top='top -o cpu'
alias cpplint='find . -iname \*.h -o -iname \*.cpp -o -iname \*.c -o -iname \*.ino | xargs clang-format -i'
alias reset_db='rake db:drop:all db:create db:migrate db:seed db:test:prepare'
alias ae='deactivate &> /dev/null; source ./venv/bin/activate'
alias de='deactivate'

# Utility Functions
u() {
  local ud="."
  for i in {1..$1}; do ud="$ud/.."; done
  cd $ud
}

chpwd() { ls }

bk() {
  if [ -f "$1" ]; then
    cp "$1" "$1.bk"
  else
    echo "File $1 does not exist"
    return 1
  fi
}

swap() {
  if [ -f "$1" ] && [ -f "$2" ]; then
    local tmpfile=$(mktemp)
    mv "$1" "$tmpfile"
    mv "$2" "$1"
    mv "$tmpfile" "$2"
  else
    echo "Both files must exist"
    return 1
  fi
}

timestamp() {
  date -j -f "%a %b %d %T %Z %Y" "$(date)" "+%s"
}

# Path Configuration (consolidated)
typeset -U path
path=(
  /opt/homebrew/bin
  /usr/local/sbin
  /usr/local/bin
  $HOME/.poetry/bin
  $HOME/.local/bin
  /Applications/Visual\ Studio\ Code.app/Contents/Resources/app/bin
  /Applications/Postgres.app/Contents/Versions/latest/bin
  $path
)

# Load theme configuration
source $HOME/.zshrc.cmdprompt

# Git Configuration
git config --global alias.ignore '!gi() { curl -L -s https://www.gitignore.io/api/$@ ;}; gi'
