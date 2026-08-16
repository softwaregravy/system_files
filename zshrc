# Profiling - Uncomment this section when profiling
# zmodload zsh/zprof

#typeset -F SECONDS
#typeset -A _timing_starts

#_start_timing() {
  #echo "[timing] Starting $1..."
  #_timing_starts[$1]=$SECONDS
#}

#_end_timing() {
  #local end_time=$SECONDS
  #local start_time=${_timing_starts[$1]}
  #local init_time=${_timing_starts["ZSH Initialize"]}
  #local section_elapsed=$(( end_time - start_time ))
  #local total_elapsed=$(( end_time - init_time ))
  #printf "[timing] %-20s %.1fs (total: %.1fs)\n" "$1:" $section_elapsed $total_elapsed
#}

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

# Prevent NextJS from tracking
# https://nextjs.org/telemetry
# Fuck off Vercel!
NEXT_TELEMETRY_DISABLED=1

# Path Configuration (consolidated)
typeset -U path
path=(
  /opt/homebrew/bin
  $HOME/.poetry/bin
  $HOME/.local/bin
  /usr/local/sbin
  /usr/local/bin
  /Applications/Visual\ Studio\ Code.app/Contents/Resources/app/bin
  /Applications/Postgres.app/Contents/Versions/latest/bin
  $path
)

# mise — single version manager for ruby, python, node (replaces pyenv, fnm, RVM)
eval "$(mise activate zsh)"

# direnv — auto-activate/deactivate project envs on cd
eval "$(direnv hook zsh)"

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
# use only pnpm
alias npm='echo "⚠️  Use pnpm instead!" && pnpm'


# Utility Functions
u() {
  local ud="."
  for i in {1..$1}; do ud="$ud/.."; done
  cd $ud
}

chpwd() {
  ls
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

# for installing Rubies on OSX
if ! brew list openssl@3 &>/dev/null; then
  echo "openssl@3 not found. Please install it first:"
  echo "brew install openssl@3"
else
  export RUBY_CONFIGURE_OPTS="--with-openssl-dir=$(brew --prefix openssl@3)"
fi

# Starship prompt (replaces zshrc.cmdprompt)
eval "$(starship init zsh)"

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
    # Main Brewfile: everything EXCEPT Mac App Store apps. --no-mas keeps them
    # out so routine `brew bundle` against this file stays non-interactive.
    brew bundle dump --file="$SYSTEM_FILES_DIR/Brewfile" --force --no-mas
    # Sort the Brewfile by type (tap, brew, cask, vscode) and then alphabetically
    sed '/^$\|^#/d' "$SYSTEM_FILES_DIR/Brewfile" | sort -t '"' -k1,1 -k2,2 > "$SYSTEM_FILES_DIR/Brewfile.tmp"
    mv "$SYSTEM_FILES_DIR/Brewfile.tmp" "$SYSTEM_FILES_DIR/Brewfile"

    # Brewfile.mas: Mac App Store apps only. Separate because mas installs need
    # App Store authorization and can't run unattended (see CLAUDE.md). setup.sh
    # installs these at bootstrap; periodic `brew bundle` ignores them.
    brew bundle dump --file="$SYSTEM_FILES_DIR/Brewfile.mas.tmp" --force \
        --mas --no-formula --no-cask --no-tap --no-vscode
    {
        echo "# Mac App Store apps — installed interactively by setup.sh."
        echo "# Do not move these into the main Brewfile: mas installs require App"
        echo "# Store authorization and cannot run unattended. Regenerated here."
        echo ""
        sort "$SYSTEM_FILES_DIR/Brewfile.mas.tmp"
    } > "$SYSTEM_FILES_DIR/Brewfile.mas"
    rm -f "$SYSTEM_FILES_DIR/Brewfile.mas.tmp"

    echo "Brewfile updated at $SYSTEM_FILES_DIR/Brewfile (+ Brewfile.mas)"
}

check_brewfile_update() {
  local brewfile="$SYSTEM_FILES_DIR/Brewfile"
  local week_in_seconds=$((60*60*24*7))

  # Check if file exists and is older than a week
  if [[ -f "$brewfile" && $(($(date +%s) - $(stat -f %m "$brewfile"))) -gt $week_in_seconds ]]; then
    echo "Brewfile hasn't been updated in over a week. Update it now with update_brewfile"
  fi
}

check_brewfile_update

# ZSH Plugin and completion setup
if type brew &>/dev/null; then
  FPATH="$(brew --prefix)/share/zsh/site-functions:$FPATH"

    # Compile new completion dump
    autoload -Uz compinit
    compinit -C

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
   source $(brew --prefix)/share/zsh-fast-syntax-highlighting/fast-syntax-highlighting.plugin.zsh &!
else
    echo "Homebrew not installed. To install ZSH plugins:"
    echo "1. Install homebrew from https://brew.sh/"
    echo "2. Then run: brew install zsh-autosuggestions zsh-syntax-highlighting"
fi

# pnpm
export PNPM_HOME="/Users/john/Library/pnpm"
case ":$PATH:" in
  *":$PNPM_HOME:"*) ;;
  *) export PATH="$PNPM_HOME:$PATH" ;;
esac
# pnpm end

# Startup cheatsheet (tmux / starship / mise+direnv) — shown once on a fresh
# terminal. Skipped inside an existing tmux pane ($TMUX set) so splitting or
# creating panes all day doesn't reprint it. Edit: $SYSTEM_FILES_DIR/motd.sh
if [[ -o interactive && -z "$TMUX" ]]; then
  source "$SYSTEM_FILES_DIR/motd.sh"
fi

# Finish profiling
# zprof


