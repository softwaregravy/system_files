# Startup cheatsheet: tmux / starship / mise+direnv quick reference, plus a
# new-project bootstrap grid for ruby/python/node.
#
# Sourced once from zshrc on a fresh top-level shell — see the `-z "$TMUX"`
# guard there, which skips this inside a pane of an already-running tmux
# session so splitting/creating panes all day doesn't reprint it.
#
# This is a reminder banner, not config — edit freely. Layout adapts to the
# terminal width ($COLUMNS) at the time it runs: column widths are computed
# from the actual content below, not hardcoded, and both grids fall back to
# a condensed single column if the terminal is too narrow for 3 side by side.
# Full reference document: CHEATSHEET.md next to this file.

_print_motd() {
  emulate -L zsh

  local cols=${COLUMNS:-80}
  local C_BOLD C_GREEN C_CYAN C_DIM C_RESET
  C_BOLD="$(tput bold 2>/dev/null)"
  C_GREEN="$(tput setaf 2 2>/dev/null)"
  C_CYAN="$(tput setaf 6 2>/dev/null)"
  C_DIM="$(tput dim 2>/dev/null)"
  C_RESET="$(tput sgr0 2>/dev/null)"
  local C_HEAD="${C_BOLD}${C_GREEN}"
  local C_KEY="${C_CYAN}"
  local C_SUB="${C_DIM}"
  local _e=""

  # -- raw content, per column: type(H head/S sub/R row/X raw-line/B blank) --
  typeset -a Ttype Tkey Tdesc Stype Skey Sdesc Mtype Mkey Mdesc
  typeset -a RBtype RBkey RBdesc PYtype PYkey PYdesc NDtype NDkey NDdesc
  _add() { # $1=col(T/S/M/RB/PY/ND) $2=type $3=key $4=desc
    case $1 in
      T)  Ttype+=("$2");  Tkey+=("$3");  Tdesc+=("$4") ;;
      S)  Stype+=("$2");  Skey+=("$3");  Sdesc+=("$4") ;;
      M)  Mtype+=("$2");  Mkey+=("$3");  Mdesc+=("$4") ;;
      RB) RBtype+=("$2"); RBkey+=("$3"); RBdesc+=("$4") ;;
      PY) PYtype+=("$2"); PYkey+=("$3"); PYdesc+=("$4") ;;
      ND) NDtype+=("$2"); NDkey+=("$3"); NDdesc+=("$4") ;;
    esac
  }

  _add T H "TMUX  ·  prefix C-a" ""
  _add T R "new -s NAME" "new session"
  _add T R "a -t NAME" "attach (a = last)"
  _add T R "ls" "list sessions"
  _add T R "C-a d" "detach"
  _add T S "windows" ""
  _add T R "C-a c" "new window"
  _add T R "C-a n / p" "next / prev window"
  _add T R "C-a 0-9" "jump to window #"
  _add T R "C-a w" "list / pick windows"
  _add T S "panes" ""
  _add T R "C-a %" "split │ vertical"
  _add T R 'C-a "' "split ─ horizontal"
  _add T R "C-a o" "cycle panes"
  _add T R "C-a z" "zoom pane (toggle)"
  _add T S "copy / paste" ""
  _add T R "C-a [" "copy mode (y = copy)"
  _add T R "C-a P" "paste buffer"
  _add T R "⌥ + drag" "native select, bypass tmux"

  _add S H "STARSHIP  ·  prompt" ""
  _add S X "┌─ dir · branch · lang ──(batt)┐" ""
  _add S X "└─ (HH:MM) ──────────────── ❯" ""
  _add S B "" ""
  _add S R "❯" "green ok · red = last exit≠0"
  _add S R "dir" "cwd (last 4 segments)"
  _add S R "branch" "git branch, if in a repo"
  _add S R "ruby/py/node" "shown only inside that project"
  _add S R "(NN%)" "battery, red under 20%"
  _add S S "commands" ""
  _add S R "starship explain" "why each segment is showing"
  _add S R "starship config" "edit starship.toml"
  _add S R "starship timings" "find what's making it slow"
  _add S B "" ""
  _add S R "reload" "instant — just press Enter"

  _add M H "MISE + DIRENV  ·  runtimes" ""
  _add M R "mise ls" "installed + active versions"
  _add M R "mise current" "active versions, this dir"
  _add M R "mise use X@Y" "pin version, this project"
  _add M R "mise use --global X@Y" "set the global default"
  _add M R "mise install" "install pinned versions"
  _add M R "mise doctor" "diagnose a broken setup"
  _add M S "direnv" ""
  _add M R "direnv allow" "trust this dir's .envrc"
  _add M R "direnv reload" "re-run .envrc now"
  _add M S "new Ruby project, once" ""
  _add M X 'echo "PATH_add bin" >> .envrc' ""
  _add M X "direnv allow ." ""
  _add M R "→" "rails/rake/rspec, no bundle exec"

  # -- new-project bootstrap: the .rvmrc replacement is `mise use`, which
  #    pins a version into ./mise.toml (one shared file for every tool in
  #    the project — ruby/node/python can all live in it together). Old
  #    habit still works too: hand-write .ruby-version / .node-version /
  #    .python-version and mise reads those directly, no mise.toml needed.
  _add RB H "RUBY  ·  new project" ""
  _add RB R "mise use ruby@latest" "pin the version → ./mise.toml"
  _add RB R "bundle init" "creates a Gemfile"
  _add RB R "bundle install" "installs gems (+ bin/ stubs)"
  _add RB X 'echo "PATH_add bin" >> .envrc' ""
  _add RB X "direnv allow ." ""
  _add RB R "→" "bin/rails, bin/rspec — no bundle exec"

  _add PY H "PYTHON  ·  new project" ""
  _add PY R "mise use python@latest" "pin the version → ./mise.toml"
  _add PY R "python -m venv venv" "project-local virtualenv"
  _add PY R "ae" "activate it (de to leave)"
  _add PY R "pip install <pkg>" "add a single package"
  _add PY R "pip install -r requirements.txt" "install from a lockfile"
  _add PY R "pip freeze > requirements.txt" "write one"

  _add ND H "NODE  ·  new project" ""
  _add ND R "mise use node@lts" "pin the version → ./mise.toml"
  _add ND R "pnpm init" "creates package.json"
  _add ND R "pnpm install" "installs everything in it"
  _add ND R "pnpm add <pkg>" "add a dependency"
  _add ND R "pnpm add -D <pkg>" "add a dev-only dependency"
  _add ND R "npm install" "aliased to warn — use pnpm"

  # -- pass 1: compute key-field width + total row width per column, from
  #    actual content (never hardcoded, so nothing gets silently truncated)
  _render_column() { # $1=T/S/M/RB/PY/ND -> sets <col>_W and (re)fills the
                      # same-named array with final colored, padded strings
    local col=$1
    typeset -a types keys descs out
    case $col in
      T)  types=("${Ttype[@]}");  keys=("${Tkey[@]}");  descs=("${Tdesc[@]}") ;;
      S)  types=("${Stype[@]}");  keys=("${Skey[@]}");  descs=("${Sdesc[@]}") ;;
      M)  types=("${Mtype[@]}");  keys=("${Mkey[@]}");  descs=("${Mdesc[@]}") ;;
      RB) types=("${RBtype[@]}"); keys=("${RBkey[@]}"); descs=("${RBdesc[@]}") ;;
      PY) types=("${PYtype[@]}"); keys=("${PYkey[@]}"); descs=("${PYdesc[@]}") ;;
      ND) types=("${NDtype[@]}"); keys=("${NDkey[@]}"); descs=("${NDdesc[@]}") ;;
    esac
    local n=${#types[@]} i kw=0 kfw=0 w=0 l pad kp
    for (( i=1; i<=n; i++ )); do
      [[ ${types[i]} == R && ${#keys[i]} -gt $kw ]] && kw=${#keys[i]}
    done
    kfw=$(( kw + 2 ))   # key field width incl. a minimum 2-space gap before desc
    for (( i=1; i<=n; i++ )); do
      case ${types[i]} in
        H|S) l=${#keys[i]} ;;
        R)   l=$(( 2 + kfw + ${#descs[i]} )) ;;
        X)   l=$(( 2 + ${#keys[i]} )) ;;
        B)   l=0 ;;
      esac
      (( l > w )) && w=$l
    done
    for (( i=1; i<=n; i++ )); do
      case ${types[i]} in
        H) pad=$(( w - ${#keys[i]} )); (( pad<0 )) && pad=0
           out+=("${C_HEAD}${keys[i]}${C_RESET}${(r:$pad:)_e}") ;;
        S) pad=$(( w - 2 - ${#keys[i]} )); (( pad<0 )) && pad=0
           out+=("  ${C_SUB}${keys[i]}${C_RESET}${(r:$pad:)_e}") ;;
        X) pad=$(( w - 2 - ${#keys[i]} )); (( pad<0 )) && pad=0
           out+=("  ${C_DIM}${keys[i]}${C_RESET}${(r:$pad:)_e}") ;;
        B) out+=("${(r:$w:)_e}") ;;
        R) kp=$(( kfw - ${#keys[i]} )); (( kp<0 )) && kp=0
           pad=$(( w - 2 - kfw - ${#descs[i]} )); (( pad<0 )) && pad=0
           out+=("  ${C_KEY}${keys[i]}${(r:$kp:)_e}${C_RESET}${descs[i]}${(r:$pad:)_e}") ;;
      esac
    done
    case $col in
      T)  T=("${out[@]}");  T_W=$w ;;
      S)  S=("${out[@]}");  S_W=$w ;;
      M)  M=("${out[@]}");  M_W=$w ;;
      RB) RB=("${out[@]}"); RB_W=$w ;;
      PY) PY=("${out[@]}"); PY_W=$w ;;
      ND) ND=("${out[@]}"); ND_W=$w ;;
    esac
  }

  typeset -a T S M RB PY ND
  local T_W S_W M_W RB_W PY_W ND_W
  _render_column T
  _render_column S
  _render_column M
  _render_column RB
  _render_column PY
  _render_column ND

  local gap=3
  local blockw1=$(( T_W + S_W + M_W + gap*2 ))
  local blockw2=$(( RB_W + PY_W + ND_W + gap*2 ))
  local blockw=$blockw1
  (( blockw2 > blockw )) && blockw=$blockw2
  local wide=0
  (( cols >= blockw + 2 )) && wide=1

  _print_grid() { # $1 $2 $3 = column ids, $4 = this grid's block width
    typeset -a ga gb gc
    local a_w b_w c_w
    case $1 in T) ga=("${T[@]}"); a_w=$T_W ;; RB) ga=("${RB[@]}"); a_w=$RB_W ;; esac
    case $2 in S) gb=("${S[@]}"); b_w=$S_W ;; PY) gb=("${PY[@]}"); b_w=$PY_W ;; esac
    case $3 in M) gc=("${M[@]}"); c_w=$M_W ;; ND) gc=("${ND[@]}"); c_w=$ND_W ;; esac
    local n=$#ga
    (( $#gb > n )) && n=$#gb
    (( $#gc > n )) && n=$#gc
    local blank_a="${(r:$a_w:)_e}" blank_b="${(r:$b_w:)_e}" blank_c="${(r:$c_w:)_e}"
    local lead=$(( (cols - $4) / 2 )); (( lead < 0 )) && lead=0
    local leadpad="${(r:$lead:)_e}" gapstr="${(r:$gap:)_e}"
    local i
    for (( i=1; i<=n; i++ )); do
      print -r -- "${leadpad}${ga[i]:-$blank_a}${gapstr}${gb[i]:-$blank_b}${gapstr}${gc[i]:-$blank_c}"
    done
  }

  print -r --
  print -r -- "  ${C_HEAD}coding environment${C_RESET}  ${C_DIM}— tmux (was screen) · starship (was zshrc.cmdprompt) · mise+direnv (was rvm/pyenv/fnm)${C_RESET}"
  print -r -- "  ${C_DIM}quick start:${C_RESET} cd <project>  →  ${C_KEY}tmux new -s <name>${C_RESET}  (or ${C_KEY}tmux a${C_RESET} to resume the last one)"
  print -r --

  if (( wide )); then
    _print_grid T S M $blockw1
  else
    # ---- narrow: condensed single column ----
    print -r -- "  ${C_HEAD}TMUX${C_RESET}  ${C_DIM}(prefix C-a)${C_RESET}"
    print -r -- "    new -s NAME · a -t NAME (attach) · ls · ${C_KEY}C-a d${C_RESET} detach"
    print -r -- "    windows: ${C_KEY}C-a c${C_RESET} new · n/p next-prev · 0-9 jump · w list"
    print -r -- "    panes:   ${C_KEY}C-a %${C_RESET} vsplit · ${C_KEY}C-a \"${C_RESET} hsplit · o cycle · z zoom"
    print -r -- "    copy:    ${C_KEY}C-a [${C_RESET} copy mode (y = copy) · ${C_KEY}C-a P${C_RESET} paste"
    print -r --
    print -r -- "  ${C_HEAD}STARSHIP${C_RESET}  ${C_DIM}(prompt)${C_RESET}"
    print -r -- "    ┌dir·branch·lang──(batt)┐ / └(time)── ❯  ${C_DIM}(❯ red = last cmd failed)${C_RESET}"
    print -r -- "    ${C_KEY}starship explain${C_RESET} · ${C_KEY}starship config${C_RESET} · ${C_KEY}starship timings${C_RESET}"
    print -r --
    print -r -- "  ${C_HEAD}MISE + DIRENV${C_RESET}  ${C_DIM}(runtimes)${C_RESET}"
    print -r -- "    ${C_KEY}mise ls${C_RESET} · current · use X@Y · use --global X@Y · install · doctor"
    print -r -- "    ${C_KEY}direnv allow${C_RESET} (trust .envrc) · ${C_KEY}direnv reload${C_RESET}"
    print -r -- "    new Ruby project: ${C_DIM}echo \"PATH_add bin\" >> .envrc && direnv allow .${C_RESET}"
  fi

  print -r --
  print -r -- "  ${C_HEAD}starting a new project${C_RESET}  ${C_DIM}— pin a runtime once: mise use <tool>@<version> writes ./mise.toml, the mise-native .rvmrc${C_RESET}"
  print -r -- "  ${C_DIM}old habit instead? hand-write .ruby-version / .node-version / .python-version — mise reads those directly too${C_RESET}"
  print -r --

  if (( wide )); then
    _print_grid RB PY ND $blockw2
  else
    print -r -- "  ${C_HEAD}RUBY${C_RESET}    ${C_KEY}mise use ruby@latest${C_RESET} · bundle init · bundle install"
    print -r -- "          then: echo \"PATH_add bin\" >> .envrc && direnv allow .  ${C_DIM}(no more bundle exec)${C_RESET}"
    print -r -- "  ${C_HEAD}PYTHON${C_RESET}  ${C_KEY}mise use python@latest${C_RESET} · python -m venv venv · ae (activate) · pip install <pkg>"
    print -r -- "  ${C_HEAD}NODE${C_RESET}    ${C_KEY}mise use node@lts${C_RESET} · pnpm init · pnpm install · pnpm add <pkg>  ${C_DIM}(never npm)${C_RESET}"
  fi

  print -r --
  print -r -- "  ${C_DIM}full reference → ${SYSTEM_FILES_DIR}/CHEATSHEET.md   ·   this banner → ${SYSTEM_FILES_DIR}/motd.sh${C_RESET}"
  print -r --
}

_print_motd
unfunction _print_motd _add _render_column _print_grid 2>/dev/null
