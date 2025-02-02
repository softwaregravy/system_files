# Profiling
# zmodload zsh/zprof

# Environment Variables
export EDITOR="vim"
export VISUAL="$EDITOR"
export PAGER=less
export GIT_PAGER=less
export LESS='-i -R'
export TERM='xterm-256color'
export LC_CTYPE=en_US.UTF-8
export LANG=en_US.UTF-8
export SYSTEM_FILES_DIR="$HOME/workspace/system_files"
export PYENV_ROOT="$HOME/.pyenv"

# Use pyenv for managing python dendencies
eval "$(pyenv init -)"
eval "$(pyenv virtualenv-init -)"

# Javascript support
#
# Fast Version Manager
eval "$(fnm env --log-level quiet)"

# Load service keys
if [ -d "$HOME/.keys" ]; then
  for f in $HOME/.keys/*; do
    if [ -f "$f" ]; then
      source "$f"
    fi
  done
fi

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

# Lazy load conda
conda() {
  unset -f conda
  # Cache conda initialization
  eval "$(conda 'shell.zsh' 'hook' 2>/dev/null)"
  conda "$@"
}


# Aliases
alias py=python3
# alias python=python3
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
alias vi='vim'
alias p='pnpm'


# Utility Functions
u() {
  local ud="."
  for i in {1..$1}; do ud="$ud/.."; done
  cd $ud
}

chpwd() { 
  ls 
  # lazy load rvm as needed
  if [[ -s ".ruby-version" && ! -v rvm ]]; then
    [[ -s "$HOME/.rvm/scripts/rvm" ]] && source "$HOME/.rvm/scripts/rvm"
  fi

  # Handle node version switching
  local dir="$PWD"
  local found=false
  
  # Search up through parent directories
  while [[ "$dir" != "/" ]]; do
    if [[ -f "$dir/.node-version" ]]; then
      found=true
      fnm use "$(cat "$dir/.node-version")"
      break
    fi
    dir="$(dirname "$dir")"
  done
  
  # If no .node-version found in path, unset node version
  if [[ "$found" == "false" ]]; then
    fnm use system
  fi
}

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
  $PYENV_ROOT/bin
  /opt/homebrew/bin
  $HOME/.poetry/bin
  $HOME/.local/bin
  /usr/local/sbin
  /usr/local/bin
  /Applications/Visual\ Studio\ Code.app/Contents/Resources/app/bin
  /Applications/Postgres.app/Contents/Versions/latest/bin
  $path
)


# for installing Rubies on OSX
if ! brew list openssl@3 &>/dev/null; then
  echo "openssl@3 not found. Please install it first:"
  echo "brew install openssl@3"
else
  export RUBY_CONFIGURE_OPTS="--with-openssl-dir=$(brew --prefix openssl@3)"
fi

# Load theme configuration
source $HOME/.zshrc.cmdprompt

# Git Configuration
git config --global alias.ignore '!gi() { curl -L -s https://www.gitignore.io/api/$@ ;}; gi'

# Screen title setting for terminal
preexec () {
    if [[ "$TERM" == "screen" ]]; then
        local CMD=${1[(wr)^(*=*|sudo|-*)]}
        echo -ne "\ek$CMD\e\\"
    fi
}

# Update Brewfile 
update_brewfile() {
    echo "Updating Brewfile..."
    brew bundle dump --file="$SYSTEM_FILES_DIR/Brewfile" --force
    # Sort the Brewfile by type (tap, brew, cask, vscode) and then alphabetically
    sed '/^$\|^#/d' "$SYSTEM_FILES_DIR/Brewfile" | sort -t '"' -k1,1 -k2,2 > "$SYSTEM_FILES_DIR/Brewfile.tmp"
    mv "$SYSTEM_FILES_DIR/Brewfile.tmp" "$SYSTEM_FILES_DIR/Brewfile"

    echo "Brewfile updated at $SYSTEM_FILES_DIR/Brewfile"
}

# ZSH Plugin and completion setup
if type brew &>/dev/null; then
  FPATH="$(brew --prefix)/share/zsh/site-functions:$FPATH"
  autoload -Uz compinit && compinit

      # Git completion
    zstyle ':completion:*:*:git-remote:*' group-order remote-groups aliases remote-tags remote-heads
    zstyle ':completion:*:*:git-checkout:*' sort false
    zstyle ':completion:*:*:git-switch:*' sort false

    # Basic completion settings
    zstyle ':completion:*' completer _complete _approximate _expand
    zstyle ':completion:*' menu select
    zstyle ':completion:*' max-errors 2

    ## Case-insensitive completion
    zstyle ':completion:*' matcher-list 'm:{[:lower:][:upper:]}={[:upper:][:lower:]}' 'm:{[:lower:][:upper:]}={[:upper:][:lower:]} l:|=* r:|=*'

    #zstyle ':completion:*:default' list-prompt '%S%M matches%s'
    #zstyle ':completion:*' file-sort modification reverse
    zstyle ':completion:*' list-colors "=(#b) #([0-9]#)*=36=31"
    #zstyle ':completion:*:manuals' separate-sections true


   ## Enhanced completion settings
   zstyle ':completion:*' special-dirs true
   zstyle ':completion:*' squeeze-slashes true
   zstyle ':completion:*:descriptions' format '%U%B%d%b%u'
   zstyle ':completion:*:warnings' format '%BSorry, no matches for: %d%b'
   zstyle ':completion:*:*:kill:*:processes' list-colors '=(#b) #([0-9]#)*=0=01;31'

   # fast-syntax-highlighting (must be last)
   source $(brew --prefix)/share/zsh-fast-syntax-highlighting/fast-syntax-highlighting.plugin.zsh
else
    echo "Homebrew not installed. To install ZSH plugins:"
    echo "1. Install homebrew from https://brew.sh/"
    echo "2. Then run: brew install zsh-autosuggestions zsh-syntax-highlighting"
fi

# Finish profiling
# zprof
