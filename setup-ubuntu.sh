#!/usr/bin/env bash
#
# setup-ubuntu.sh — Ubuntu counterpart to setup.sh (which is macOS/Homebrew only).
#
# Bootstraps a headless Ubuntu server (tested on 24.04 "noble", x86_64) with the
# same terminal workflow as the Mac: zsh + starship + vim + tmux + mise + direnv.
# Packages come from apt (see aptfile-ubuntu) instead of Homebrew.
#
# Config files: anything already portable is symlinked straight from this repo;
# anything that needed changes has a "-ubuntu" sibling (zshrc-ubuntu, vimrc-ubuntu,
# tmux.conf-ubuntu, gitconfig-ubuntu, claude/settings-ubuntu.json). The macOS
# originals are never touched.
#
# Run it from a detached tmux/screen session, NOT from an agent's shell tool:
# it takes ~10 minutes and a mid-dpkg kill leaves apt half-configured.
#
#   tmux new -s setup
#   ./setup-ubuntu.sh
#
# It changes your login shell to zsh, adds you to the docker group, and replaces
# files in $HOME. Everything replaced is moved to ~/.dotfiles-backup/<timestamp>/.

set -euo pipefail

# -----------------------------------------------------------------------------
# | Options                                                                    |
# -----------------------------------------------------------------------------

ASSUME_YES=0
SKIP_APT=0
DO_CHSH=1

usage() {
  cat <<'USAGE'
Usage: setup-ubuntu.sh [OPTIONS]

  -h, --help      Show this help and exit.
  -y, --yes       Never prompt. Back up and replace anything in the way.
                  Required for `curl | bash` and any run without a terminal.
      --skip-apt  Skip package installation. Turns a "just fix my symlinks"
                  re-run into a few seconds instead of a few minutes.
      --no-chsh   Do everything except change the login shell to zsh.

Env:
  SYSTEM_FILES_DIR  Override the repo location. Defaults to the directory this
                    script lives in, else ~/workspaces/system_files.

Run this from a detached tmux/screen session, not from an agent's shell tool.
It changes your login shell, adds you to the docker group, and replaces files
in $HOME (everything replaced is moved to ~/.dotfiles-backup/<timestamp>/).
USAGE
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    -h|--help)   usage; exit 0 ;;
    -y|--yes)    ASSUME_YES=1 ;;
    --skip-apt)  SKIP_APT=1 ;;
    --no-chsh)   DO_CHSH=0 ;;
    *) echo "Unknown option: $1" >&2; usage >&2; exit 2 ;;
  esac
  shift
done

# -----------------------------------------------------------------------------
# | Logging, warnings, teardown                                                |
# -----------------------------------------------------------------------------

WARNINGS=()
BACKED_UP=()
SUDO_KEEPALIVE_PID=""
START_TS=$(date +%s)

# Detect a terminal BEFORE stdout gets redirected into tee.
HAS_TTY=0
if [[ -t 1 ]] && [[ -r /dev/tty ]]; then HAS_TTY=1; fi

if (( HAS_TTY )); then
  C_RED=$'\033[31m'; C_YEL=$'\033[33m'; C_GRN=$'\033[32m'; C_OFF=$'\033[0m'
else
  C_RED=""; C_YEL=""; C_GRN=""; C_OFF=""
fi

say()  { printf '%s\n' "$*"; }
step() { printf '\n%s==> %s%s\n' "$C_GRN" "$*" "$C_OFF"; }
warn() { WARNINGS+=("$*"); printf '%s[WARN]%s %s\n' "$C_YEL" "$C_OFF" "$*" >&2; }
die()  { printf '%s[FATAL]%s %s\n' "$C_RED" "$C_OFF" "$*" >&2; exit 1; }

# Run a phase without letting it abort the script.
#
# Be precise about what this does: invoking a function in a condition context
# suspends `set -e` for its whole body. So a failure PART WAY THROUGH a phase is
# neither caught here nor fatal — the phase just keeps going, and only its final
# command's status decides whether the warning below fires. That is why every
# risky command inside a phase carries its own `|| warn ...` and every phase ends
# in `return 0`; this wrapper is only the backstop.
#
# `die` still works from inside a phase: `exit` is not subject to the exemption,
# so a genuinely fatal problem stops the run and the EXIT trap still prints the
# summary.
soft() {
  local label=$1; shift
  if ! "$@"; then
    warn "$label failed — continuing. Re-run setup-ubuntu.sh to retry."
  fi
  return 0
}

cleanup() {
  local rc=$?
  if [[ -n "$SUDO_KEEPALIVE_PID" ]] && kill -0 "$SUDO_KEEPALIVE_PID" 2>/dev/null; then
    kill "$SUDO_KEEPALIVE_PID" 2>/dev/null || :
    wait "$SUDO_KEEPALIVE_PID" 2>/dev/null || :
  fi
  print_summary "$rc"
  # Give the tee in the output pipeline a moment to flush.
  sleep 0.3
  return $rc
}

# -----------------------------------------------------------------------------
# | P0 — Preflight                                                             |
# -----------------------------------------------------------------------------

[[ "$(uname -s)" == "Linux" ]] || die "This script is for Linux. On macOS run ./setup.sh instead."

if [[ ${EUID:-$(id -u)} -eq 0 ]]; then
  die "Do not run this as root (or with sudo). It creates files in \$HOME and
       would leave them root-owned. Run it as your normal user; it will prompt
       for sudo once, when it needs it."
fi

if [[ -r /etc/os-release ]]; then
  # shellcheck disable=SC1091
  . /etc/os-release
  [[ "${ID:-}" == "ubuntu" || "${ID_LIKE:-}" == *debian* ]] \
    || warn "Not Ubuntu/Debian (ID=${ID:-?}) — apt package names may not match."
fi

# Resolve the repo. Prefer the directory this script lives in, so running it
# from a checkout Just Works regardless of where that checkout is.
DEFAULT_REPO="$HOME/workspaces/system_files"
if [[ -n "${SYSTEM_FILES_DIR:-}" ]]; then
  REPO_DIR="$SYSTEM_FILES_DIR"
elif [[ -n "${BASH_SOURCE[0]:-}" ]] && [[ -f "$(dirname "${BASH_SOURCE[0]}")/setup-ubuntu.sh" ]]; then
  REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
else
  REPO_DIR="$DEFAULT_REPO"
fi

CLONED_REPO=0
if [[ ! -d "$REPO_DIR" ]]; then
  step "Cloning system files repository to $REPO_DIR"
  mkdir -p "$(dirname "$REPO_DIR")"
  git clone https://github.com/softwaregravy/system_files.git "$REPO_DIR" \
    || die "could not clone the repo to $REPO_DIR"
  CLONED_REPO=1
fi
[[ -f "$REPO_DIR/setup-ubuntu.sh" ]] || die "$REPO_DIR does not look like the system_files repo"

# Deliberately NOT pulling when running from an existing checkout: bash reads a
# script by byte offset as it executes, and rewriting it mid-run is asking for
# trouble. Pull it yourself before running.
if (( CLONED_REPO == 0 )); then
  say "Using repo at $REPO_DIR (run 'git pull' yourself if you want it updated first)"
fi

RUN_ID="$(date +%Y%m%dT%H%M%S)"
BACKUP_DIR="$HOME/.dotfiles-backup/$RUN_ID"
LOG_FILE="$BACKUP_DIR/setup.log"
mkdir -p "$BACKUP_DIR"

# Everything from here on is teed to the log. A 10 minute run scrolls its
# warnings off screen otherwise.
exec > >(tee -a "$LOG_FILE") 2>&1

say "system_files Ubuntu setup"
say "  repo:    $REPO_DIR"
say "  backups: $BACKUP_DIR"
say "  log:     $LOG_FILE"
say "  user:    $USER ($(id -u))  host: $(hostname)"

# ~/.local/bin holds starship, bat, fd, newrc and (already) claude. It must
# exist and be on PATH *in this process* — ~/.profile only adds it at login,
# which already happened.
mkdir -p "$HOME/.local/bin"
export PATH="$HOME/.local/bin:$PATH"

# mise compiling a runtime from source wants several GB.
avail_kb=$(df -Pk "$HOME" | awk 'NR==2 {print $4}')
if [[ -n "${avail_kb:-}" ]] && (( avail_kb < 8000000 )); then
  warn "only $((avail_kb / 1024)) MB free in $HOME — apt (~900MB) plus mise runtimes may not fit"
fi

if (( HAS_TTY == 0 )) && (( ASSUME_YES == 0 )); then
  warn "No terminal detected and --yes not given: anything already in the way will be SKIPPED, not replaced."
fi

# -----------------------------------------------------------------------------
# | Helpers                                                                    |
# -----------------------------------------------------------------------------

confirm() {
  local prompt=$1 reply="n"
  (( ASSUME_YES )) && return 0
  (( HAS_TTY )) || return 1
  printf '%s (y/n) ' "$prompt" > /dev/tty
  read -r reply < /dev/tty || reply="n"
  [[ "$reply" == [yY] ]]
}

# Move a path into this run's backup directory, preserving its location under
# $HOME. Unlike the Mac script's "<target>.backup" this can't clobber a previous
# backup, can't leave an executable on $PATH, and can't drop a stray file into a
# systemd unit directory.
backup_path() {
  local target=$1 rel dest
  rel="${target#"$HOME"/}"; rel="${rel#/}"
  dest="$BACKUP_DIR/$rel"
  mkdir -p "$(dirname "$dest")"
  mv "$target" "$dest"
  say "  backed up $target -> $dest"
  BACKED_UP+=("$target")
}

# Files we know are in the way and that the user has already decided to adopt
# from the repo. Replacing these silently (after backing them up) beats asking.
AUTO_REPLACE=(
  "$HOME/.claude/settings.json"
  "$HOME/.local/bin/newrc"
  "$HOME/.config/systemd/user/claude-rc@.service"
)

is_auto_replace() {
  local t=$1 x
  for x in "${AUTO_REPLACE[@]}"; do [[ "$x" == "$t" ]] && return 0; done
  return 1
}

create_symlink() {
  local source=$1 target=$2 current

  if [[ ! -e "$source" ]]; then
    warn "missing source — not linking: $source -> $target"
    return 0
  fi
  source="$(realpath "$source")"
  mkdir -p "$(dirname "$target")"

  if [[ -L "$target" ]]; then
    current="$(readlink "$target")"
    if [[ "$current" == "$source" ]]; then
      say "  ok        $target"
      return 0
    fi
    say "  $target currently points to $current"
    if confirm "  Repoint it to $source?"; then
      ln -sfn "$source" "$target"
      say "  relinked  $target -> $source"
    else
      warn "left existing symlink alone: $target -> $current"
    fi
    return 0
  fi

  if [[ -e "$target" ]]; then
    if is_auto_replace "$target" || confirm "  $target exists and is not a symlink. Back it up and replace?"; then
      backup_path "$target"
      ln -sfn "$source" "$target"
      say "  replaced  $target -> $source"
    else
      warn "SKIPPED (exists, not a symlink): $target"
    fi
    return 0
  fi

  ln -sfn "$source" "$target"
  say "  linked    $target -> $source"
}

# Symlink one *name* inside ~/.local/bin. Never globs — ~/.local/bin also holds
# the `claude` symlink, which must not be disturbed.
link_bin() {
  # Split across two statements on purpose: bash expands every word of a `local`
  # command before performing any of its assignments, so referencing $name in
  # the same statement that declares it reads the (unset) outer scope and trips
  # `set -u`.
  local source=$1 name=$2
  local target="$HOME/.local/bin/$name"
  [[ -e "$source" ]] || { warn "not found, skipping shim: $source"; return 0; }
  if [[ -L "$target" ]] && [[ "$(readlink "$target")" == "$source" ]]; then
    say "  ok        $target"
    return 0
  fi
  [[ -e "$target" && ! -L "$target" ]] && backup_path "$target"
  ln -sfn "$source" "$target"
  say "  shim      $target -> $source"
}

require_sudo() {
  sudo -n true 2>/dev/null && return 0
  say "Re-authenticating for sudo..."
  sudo -v
}

# -----------------------------------------------------------------------------
# | P1 — sudo                                                                  |
# -----------------------------------------------------------------------------

phase_sudo() {
  step "sudo"
  say "This script needs sudo for apt, the docker group, and chsh."
  say "You should be prompted once, now."
  sudo -v || die "sudo is required"

  # Keep the timestamp warm for the length of the run. `sudo -n true` is the
  # loop *condition*, so `set -e` can't kill the loop silently, and the loop
  # ends on its own the moment credentials can't be refreshed. The PID is
  # reaped in the EXIT trap rather than by polling the parent's PID (which
  # can outlive the script and, on PID reuse, never terminate).
  sudo -n true 2>/dev/null \
    || warn "sudo does not appear to cache credentials here; expect repeated prompts"
  ( while sudo -n true 2>/dev/null; do sleep 45; done ) &
  SUDO_KEEPALIVE_PID=$!
  disown "$SUDO_KEEPALIVE_PID" 2>/dev/null || :
}

# -----------------------------------------------------------------------------
# | P2 — apt                                                                   |
# -----------------------------------------------------------------------------

APTFILE="$REPO_DIR/aptfile-ubuntu"

add_apt_repos() {
  require_sudo
  sudo install -dm 755 /etc/apt/keyrings

  # mise — not in the Ubuntu archive at all. Official signed repo.
  # `| sudo tee` (never `>>`) so re-running truncates instead of appending.
  if [[ ! -f /etc/apt/keyrings/mise-archive-keyring.gpg ]]; then
    say "  adding the mise apt repo"
    curl -fsSL https://mise.jdx.dev/gpg-key.pub \
      | gpg --dearmor \
      | sudo tee /etc/apt/keyrings/mise-archive-keyring.gpg >/dev/null \
      || warn "could not add the mise signing key"
  fi
  echo "deb [signed-by=/etc/apt/keyrings/mise-archive-keyring.gpg arch=amd64] https://mise.jdx.dev/deb stable main" \
    | sudo tee /etc/apt/sources.list.d/mise.list >/dev/null

  # ngrok — also absent from the archive. The "bookworm" suite name is correct
  # on Ubuntu too: it's a single-suite repo of static binaries.
  if [[ ! -f /etc/apt/keyrings/ngrok.gpg ]]; then
    say "  adding the ngrok apt repo"
    curl -fsSL https://ngrok-agent.s3.amazonaws.com/ngrok.asc \
      | gpg --dearmor \
      | sudo tee /etc/apt/keyrings/ngrok.gpg >/dev/null \
      || warn "could not add the ngrok signing key"
  fi
  echo "deb [signed-by=/etc/apt/keyrings/ngrok.gpg] https://ngrok-agent.s3.amazonaws.com bookworm main" \
    | sudo tee /etc/apt/sources.list.d/ngrok.list >/dev/null
}

phase_apt() {
  step "apt packages"
  require_sudo

  # curl/gnupg are needed to add the signed repos below.
  sudo env DEBIAN_FRONTEND=noninteractive NEEDRESTART_MODE=l NEEDRESTART_SUSPEND=1 \
    apt-get install -y -o DPkg::Lock::Timeout=600 curl ca-certificates gnupg \
    || warn "could not install curl/ca-certificates/gnupg"

  add_apt_repos || warn "third-party apt repos could not be added"

  say "  apt-get update"
  # A single unreachable repo makes this non-zero while leaving the rest of the
  # cache perfectly usable, so don't treat it as fatal — the availability filter
  # below is what actually decides whether we can proceed.
  sudo apt-get update -o DPkg::Lock::Timeout=600 || warn "apt-get update reported errors"

  [[ -f "$APTFILE" ]] || { warn "no $APTFILE — skipping package installation"; return 0; }

  local pkgs=() avail=() missing=() p
  mapfile -t pkgs < <(sed -e 's/#.*//' -e 's/[[:space:]]//g' "$APTFILE" | grep -v '^$' || true)
  (( ${#pkgs[@]} )) || { warn "$APTFILE contained no package names"; return 0; }

  # These two come from the third-party repos added by add_apt_repos, not from
  # Ubuntu's archive, so they are deliberately NOT listed in aptfile-ubuntu
  # (that file documents itself as covering only what plain Ubuntu ships).
  # They still have to be installed, though — adding a repo and then never
  # pulling from it is how mise silently went missing.
  pkgs+=(mise ngrok)

  # NOTE: do NOT write this as `apt-cache policy "$p" | grep -q ...`. grep -q
  # exits on first match, apt-cache takes SIGPIPE, and `pipefail` surfaces 141 —
  # every single time. That would silently mark every package unavailable.
  for p in "${pkgs[@]}"; do
    if apt-cache show "$p" >/dev/null 2>&1; then avail+=("$p"); else missing+=("$p"); fi
  done

  if (( ${#missing[@]} )); then
    warn "not available in apt, skipping: ${missing[*]}"
  fi
  (( ${#avail[@]} )) || { warn "no installable packages found"; return 0; }

  say "  installing ${#avail[@]} packages (this is the slow part)"
  # NEEDRESTART_MODE=l / NEEDRESTART_SUSPEND=1 matter a lot here: Ubuntu's apt
  # hook defaults to automatically restarting affected services, and that list
  # can include user@$UID.service — which would kill any running tmux server,
  # including `claude remote-control` sessions and possibly this script.
  sudo env DEBIAN_FRONTEND=noninteractive NEEDRESTART_MODE=l NEEDRESTART_SUSPEND=1 \
    apt-get install -y \
      -o DPkg::Lock::Timeout=600 \
      -o Dpkg::Options::=--force-confold \
      "${avail[@]}" \
    || warn "apt-get install reported errors — check the log above"

  # Only these three make the rest of the script meaningful.
  local hard
  for hard in zsh git curl; do
    command -v "$hard" >/dev/null 2>&1 || die "$hard is still missing after apt — cannot continue"
  done
}

# -----------------------------------------------------------------------------
# | P3 — ~/.local/bin shims                                                    |
# -----------------------------------------------------------------------------

phase_shims() {
  step "command shims"
  # Debian renames both of these because of filename clashes with unrelated
  # packages (bacula-console-qt ships /usr/bin/bat, fdclone ships /usr/bin/fd).
  [[ -x /usr/bin/batcat ]] && link_bin /usr/bin/batcat bat
  [[ -x /usr/bin/fdfind ]] && link_bin /usr/bin/fdfind fd
  return 0
}

# -----------------------------------------------------------------------------
# | P4 — starship, fast-syntax-highlighting                                    |
# -----------------------------------------------------------------------------

phase_starship() {
  step "starship"
  if command -v starship >/dev/null 2>&1; then
    say "  already installed: $(command -v starship)"
    return 0
  fi
  # Not packaged for Ubuntu. Installed into ~/.local/bin so it needs no sudo.
  curl -fsSL https://starship.rs/install.sh \
    | sh -s -- --yes --bin-dir "$HOME/.local/bin" \
    || warn "starship install failed (network?); the prompt will fall back to plain zsh"
  return 0
}

phase_fsh() {
  step "zsh fast-syntax-highlighting"
  local dir="$HOME/.zsh/fast-syntax-highlighting"
  if [[ -d "$dir/.git" ]]; then
    git -C "$dir" pull --ff-only || warn "could not update fast-syntax-highlighting"
  else
    mkdir -p "$HOME/.zsh"
    git clone --depth 1 https://github.com/zdharma-continuum/fast-syntax-highlighting.git "$dir" \
      || { warn "fast-syntax-highlighting clone failed; zshrc falls back to apt's zsh-syntax-highlighting"; return 0; }
  fi
  # umask here is 0002, so a fresh clone is group-writable and compaudit will
  # complain about it on every login.
  chmod -R go-w "$HOME/.zsh" || :
  return 0
}

# -----------------------------------------------------------------------------
# | P5/P6 — language runtimes                                                  |
# -----------------------------------------------------------------------------

phase_mise() {
  step "language runtimes (mise)"
  if ! command -v mise >/dev/null 2>&1; then
    warn "mise not installed — skipping runtimes. Install it later, then re-run."
    return 0
  fi

  # Honour .ruby-version / .node-version / .python-version. Modern mise ignores
  # these by default, so without this `cd` into a project would not switch.
  mise settings idiomatic_version_file_enable_tools=ruby,node,python \
    || warn "could not set mise idiomatic_version_file_enable_tools"

  # Deliberately three separate invocations: mise installs precompiled builds
  # where it can, but if one falls back to compiling from source and fails, the
  # others should still land. node first — corepack depends on it.
  mise use --global node@lts   || warn "mise: node@lts failed (retry: mise use -g node@lts)"
  mise use --global python@latest || warn "mise: python@latest failed (retry: mise use -g python@latest)"
  mise use --global ruby@latest   || warn "mise: ruby@latest failed (retry: mise use -g ruby@latest)"
  hash -r || :
  return 0
}

phase_pnpm() {
  step "pnpm"
  if command -v pnpm >/dev/null 2>&1; then
    say "  already installed: $(command -v pnpm)"
    return 0
  fi
  command -v mise >/dev/null 2>&1 || { warn "no mise — skipping pnpm"; return 0; }

  # mise only puts node on PATH via `mise activate`, which is interactive-only,
  # so reach it explicitly. --install-directory matters: corepack's default
  # target lives inside the mise node version directory and is orphaned on the
  # next node upgrade.
  if mise exec node@lts -- corepack enable --install-directory "$HOME/.local/bin" 2>/dev/null; then
    say "  enabled via corepack"
  elif mise use --global pnpm@latest; then
    say "  installed via mise"
  else
    warn "could not install pnpm (try: mise use -g pnpm@latest)"
  fi
  return 0
}

# -----------------------------------------------------------------------------
# | P7 — key templates                                                         |
# -----------------------------------------------------------------------------

phase_keys() {
  step "API key templates"
  local keys_dir="$HOME/.keys" template filename target
  mkdir -p "$keys_dir"
  chmod 700 "$keys_dir"
  [[ -d "$REPO_DIR/keys" ]] || { warn "no keys/ directory in the repo"; return 0; }
  for template in "$REPO_DIR"/keys/*; do
    [[ -f "$template" ]] || continue
    filename="$(basename "$template")"
    target="$keys_dir/$filename"
    # Never overwrite: these hold real secrets once filled in.
    if [[ ! -f "$target" ]]; then
      cp "$template" "$target" || { warn "could not create $target"; continue; }
      chmod 600 "$target" || warn "could not chmod 600 $target"
      say "  created template $target"
    else
      say "  ok        $target"
    fi
  done
  return 0
}

# -----------------------------------------------------------------------------
# | P8 — symlinks                                                              |
# -----------------------------------------------------------------------------

phase_links() {
  step "symlinks"
  # Left of the colon is relative to the repo. Files with a "-ubuntu" suffix
  # needed real changes; everything else is portable as-is and is shared with
  # the Mac setup.
  local links=(
    # ported
    "zshrc-ubuntu:$HOME/.zshrc"
    "vimrc-ubuntu:$HOME/.vimrc"
    "tmux.conf-ubuntu:$HOME/.tmux.conf"
    "gitconfig-ubuntu:$HOME/.gitconfig"
    "claude/settings-ubuntu.json:$HOME/.claude/settings.json"
    # shared, unchanged
    "setup-ubuntu.sh:$HOME/setup-ubuntu.sh"
    "screenrc:$HOME/.screenrc"
    "inputrc:$HOME/.inputrc"
    "irbrc:$HOME/.irbrc"
    "gemrc:$HOME/.gemrc"
    "npmrc:$HOME/.npmrc"
    "starship.toml:$HOME/.config/starship.toml"
    "CLAUDE.user.md:$HOME/.claude/CLAUDE.md"
    "claude/statusline-command.sh:$HOME/.claude/statusline-command.sh"
    "ir_black.vim:$HOME/.vim/colors/ir_black.vim"
    "vim/after/syntax/sh.vim:$HOME/.vim/after/syntax/sh.vim"
    # Linux-only. ngrok's config lives here, not in ~/Library/Application Support.
    "ngrok.yml:$HOME/.config/ngrok/ngrok.yml"
    "bin/newrc:$HOME/.local/bin/newrc"
    "systemd/claude-rc@.service:$HOME/.config/systemd/user/claude-rc@.service"
  )
  local link source target
  for link in "${links[@]}"; do
    source="$REPO_DIR/${link%%:*}"
    target="${link#*:}"
    create_symlink "$source" "$target"
  done
  return 0
}

# -----------------------------------------------------------------------------
# | P9 — vim plugins                                                           |
# -----------------------------------------------------------------------------

VIM_PACKAGES=(
"https://github.com/preservim/nerdtree.git"
"https://github.com/preservim/nerdcommenter.git"
"https://github.com/vim-ruby/vim-ruby.git"
"https://github.com/tpope/vim-rails.git"
"https://github.com/tpope/vim-markdown.git"
"https://github.com/pangloss/vim-javascript.git"
"https://github.com/leafgarland/typescript-vim.git"
"https://github.com/MaxMEllon/vim-jsx-pretty.git"
"https://github.com/vim-scripts/AutoComplPop.git"
"https://github.com/chrisbra/vim-zsh.git"
# Linux-only: Vim 9.1 in Ubuntu has no native OSC 52 and never will (LTS does
# not rebase vim), so copying to the Mac clipboard over SSH needs this plugin.
"https://github.com/ojroques/vim-oscyank.git"
# Add more packages here
)

phase_vim() {
  step "vim plugins"
  mkdir -p "$HOME/.vim/pack/vendor/start"
  local repo_url package_name package_dir d
  for repo_url in "${VIM_PACKAGES[@]}"; do
    package_name="$(basename "$repo_url" .git)"
    package_dir="$HOME/.vim/pack/vendor/start/$package_name"
    if [[ -d "$package_dir/.git" ]]; then
      say "  updating $package_name"
      git -C "$package_dir" pull --ff-only >/dev/null 2>&1 || warn "could not update vim plugin $package_name"
    else
      say "  installing $package_name"
      git clone --depth 1 "$repo_url" "$package_dir" >/dev/null 2>&1 \
        || warn "could not clone vim plugin $package_name"
    fi
  done

  say "  generating helptags"
  # `vim -u NONE -c 'helptags ALL'` (what the Mac script does) is a no-op: -u NONE
  # skips plugin loading, so pack/*/start/* never makes it onto runtimepath and
  # nothing gets tagged. Tag each doc directory explicitly instead. </dev/null so
  # vim can never start reading the rest of this script as keystrokes.
  for d in "$HOME"/.vim/pack/vendor/start/*/doc; do
    [[ -d "$d" ]] || continue
    vim -es -u NONE -c "helptags $d" -c 'qa!' </dev/null >/dev/null 2>&1 \
      || warn "helptags failed for $d"
  done
  return 0
}

# -----------------------------------------------------------------------------
# | P10 — ssh key                                                              |
# -----------------------------------------------------------------------------

SSH_KEY_CREATED=0

phase_ssh() {
  step "ssh key"
  local ssh_dir="$HOME/.ssh" email
  mkdir -p "$ssh_dir"
  chmod 700 "$ssh_dir"
  # authorized_keys / known_hosts already exist here — never touch them.
  if [[ -f "$ssh_dir/id_ed25519" ]]; then
    say "  ok        $ssh_dir/id_ed25519 already exists"
    return 0
  fi
  # `git config --get` exits 1 when unset, which would abort under `set -e`.
  email="$(git config --get user.email || echo "$USER@$(hostname)")"
  ssh-keygen -t ed25519 -C "$email" -f "$ssh_dir/id_ed25519" -N "" \
    || { warn "ssh-keygen failed"; return 0; }
  SSH_KEY_CREATED=1
  # Deliberately not starting an ssh-agent here: on a server it just leaks an
  # orphaned agent process that nothing will ever use.
  return 0
}

# -----------------------------------------------------------------------------
# | P11 — docker group                                                         |
# -----------------------------------------------------------------------------

phase_docker() {
  step "docker group"
  if ! getent group docker >/dev/null 2>&1; then
    say "  no docker group (docker.io not installed?) — skipping"
    return 0
  fi
  if id -nG "$USER" | tr ' ' '\n' | grep -Fx docker >/dev/null 2>&1; then
    say "  ok        $USER is already in the docker group"
    return 0
  fi
  say "  groups before: $(id -nG "$USER")"
  require_sudo
  # -aG, never -G. Plain -G *replaces* the supplementary group list and would
  # drop this account from sudo and adm — unrecoverable on a headless box.
  sudo usermod -aG docker "$USER" || { warn "usermod failed"; return 0; }
  say "  groups after:  $(id -nG "$USER")"
  say "  (takes effect after a full re-login, not in this session)"
  return 0
}

# -----------------------------------------------------------------------------
# | P12 — systemd user units                                                   |
# -----------------------------------------------------------------------------

phase_systemd() {
  step "systemd user units"
  if [[ -z "${XDG_RUNTIME_DIR:-}" ]] || ! systemctl --user show-environment >/dev/null 2>&1; then
    warn "no systemd user bus in this environment — skipping daemon-reload"
    return 0
  fi
  systemctl --user daemon-reload || warn "systemctl --user daemon-reload failed"
  say "  daemon-reload done"
  # NOT restarting claude-rc@* on purpose: that would kill any live
  # `claude remote-control` session, and this script may well be running inside
  # one of them.
  local units
  units="$(systemctl --user list-units --no-legend 'claude-rc@*' 2>/dev/null | awk '{print $1}' || true)"
  if [[ -n "$units" ]]; then
    say "  running claude-rc units (restart them yourself when convenient):"
    printf '    %s\n' $units
  fi

  # Keep user units alive across logout.
  if [[ "$(loginctl show-user "$USER" --property=Linger --value 2>/dev/null || echo no)" == "yes" ]]; then
    say "  ok        lingering already enabled"
  else
    require_sudo
    sudo loginctl enable-linger "$USER" || warn "could not enable lingering"
  fi
  return 0
}

# -----------------------------------------------------------------------------
# | P13 — login shell                                                          |
# -----------------------------------------------------------------------------

CHSH_DONE=0

zshrc_smoke_test() {
  local zshrc="$REPO_DIR/zshrc-ubuntu" out
  [[ -f "$zshrc" ]] || { warn "no zshrc-ubuntu in the repo"; return 1; }

  if ! zsh -n "$zshrc"; then
    warn "zshrc-ubuntu has a syntax error"
    return 1
  fi
  say "  syntax ok"

  # Run a real interactive login shell. SSH_TTY is cleared and NO_TMUX is set so
  # the tmux auto-attach in zshrc cannot fire and hang this script.
  if ! out="$(env -u SSH_TTY NO_TMUX=1 timeout 30 zsh -lic 'exit' </dev/null 2>&1)"; then
    warn "an interactive zsh login shell failed to start:"
    printf '%s\n' "$out" >&2
    return 1
  fi
  say "  interactive login shell starts cleanly"
  if [[ -n "$out" ]]; then
    warn "zsh login printed output (not fatal, but you'll see this on every login):"
    printf '%s\n' "$out" >&2
  fi
  return 0
}

phase_chsh() {
  step "login shell"
  local zsh_bin current
  zsh_bin="$(command -v zsh || true)"
  [[ -n "$zsh_bin" ]] || { warn "zsh is not installed — not changing the login shell"; return 0; }

  current="$(getent passwd "$USER" | cut -d: -f7)"
  if [[ "$current" == "$zsh_bin" ]]; then
    say "  ok        login shell is already $zsh_bin"
    CHSH_DONE=1
    return 0
  fi

  if (( DO_CHSH == 0 )); then
    say "  --no-chsh given; leaving login shell as $current"
    return 0
  fi

  # This is the lockout guard. Do not change the login shell to something that
  # cannot start.
  if ! zshrc_smoke_test; then
    warn "NOT changing the login shell: zshrc-ubuntu did not pass its smoke test."
    warn "Fix it, then re-run setup-ubuntu.sh (or: chsh -s $zsh_bin)."
    return 0
  fi

  grep -qxF "$zsh_bin" /etc/shells || {
    require_sudo
    sudo add-shell "$zsh_bin" || warn "could not register $zsh_bin in /etc/shells"
  }

  require_sudo
  # Via sudo so it uses the cached credential instead of asking for the
  # account password a second time.
  if sudo chsh -s "$zsh_bin" "$USER"; then
    say "  login shell changed to $zsh_bin"
    CHSH_DONE=1
  else
    warn "chsh failed — login shell is still $current"
  fi
  return 0
}

# -----------------------------------------------------------------------------
# | P14 — completions                                                          |
# -----------------------------------------------------------------------------

phase_completions() {
  step "shell completions"
  mkdir -p "$HOME/.zsh/completions"

  if command -v ngrok >/dev/null 2>&1; then
    ngrok completion > "$HOME/.zsh/completions/_ngrok" 2>/dev/null \
      && say "  wrote ~/.zsh/completions/_ngrok" \
      || warn "could not generate ngrok completions"
  fi

  command -v zsh >/dev/null 2>&1 || { warn "no zsh — skipping completion dump"; return 0; }

  say "  pre-compiling the zsh completion dump"
  # -f so this doesn't depend on ~/.zshrc. -i so compinit doesn't stop on an
  # interactive compaudit prompt (umask here is 0002, so directories are
  # group-writable and compaudit will always have something to say).
  zsh -f <<'EOF' || warn "could not pre-compile the zsh completion dump"
setopt null_glob
COMPDUMP="${ZDOTDIR:-$HOME}/.zcompdump"
fpath=("$HOME/.zsh/completions" $fpath)
autoload -Uz compinit
compinit -i -d "$COMPDUMP"
zcompile -M "$COMPDUMP"
chmod 644 "$COMPDUMP"*
EOF
  return 0
}

# -----------------------------------------------------------------------------
# | P15 — summary                                                              |
# -----------------------------------------------------------------------------

print_summary() {
  local rc=${1:-0} elapsed=$(( $(date +%s) - START_TS ))

  printf '\n%s================================================================%s\n' "$C_GRN" "$C_OFF"
  if (( rc == 0 )); then
    say "Setup finished in $((elapsed / 60))m $((elapsed % 60))s."
  else
    printf '%sSetup stopped early (exit %s) after %sm %ss.%s\n' "$C_RED" "$rc" "$((elapsed / 60))" "$((elapsed % 60))" "$C_OFF"
  fi
  say "Log: $LOG_FILE"

  if (( ${#WARNINGS[@]} )); then
    printf '\n%sWarnings (%s):%s\n' "$C_YEL" "${#WARNINGS[@]}" "$C_OFF"
    printf '  - %s\n' "${WARNINGS[@]}"
  else
    say ""
    say "No warnings."
  fi

  if (( ${#BACKED_UP[@]} )); then
    printf '\nFiles replaced (originals moved to %s):\n' "$BACKUP_DIR"
    printf '  - %s\n' "${BACKED_UP[@]}"
  fi

  cat <<EOF

Next steps
----------
1. Try the new shell WITHOUT logging out:

       exec zsh -l

   Then open a SECOND ssh session and confirm it logs in cleanly BEFORE you
   close this one. If zsh is broken you can still get in with:

       ssh $(hostname) -t /bin/bash        # then: chsh -s /bin/bash

2. Fill in the API keys you actually use. Every file in ~/.keys/ is sourced at
   each shell start, so an unedited placeholder gets exported as if it were a
   real value — keep the export commented out until you paste a real one in.

       ~/.keys/openai     OPENAI_API_KEY     (OPENAI_ORG_ID is optional)
       ~/.keys/ngrok      NGROK_AUTHTOKEN

       \$EDITOR ~/.keys/openai && source ~/.zshrc

   Leave ~/.keys/anthropic commented out unless you specifically want API
   billing: setting ANTHROPIC_API_KEY overrides Claude Code's subscription auth.

3. Authenticate the tools that need it:

       gh auth login                                  # interactive
       ngrok config add-authtoken "\$NGROK_AUTHTOKEN"  # after step 2

   In the gh prompts pick SSH as the Git protocol, and upload
   ~/.ssh/id_ed25519.pub when it offers to — that registers this box with
   GitHub in one pass. Authenticate with a web browser, NOT a pasted token:
   only the browser flow requests the admin:public_key scope the upload needs,
   and a token without it skips the upload silently. This box is headless, so
   the browser launch fails and gh prints a one-time code instead — open
   https://github.com/login/device on your Mac and enter it there.
   Verify with:  ssh -T git@github.com

   Do NOT run 'git lfs install' — ~/.gitconfig is a symlink into the repo and
   it would dirty your working tree. The lfs filter is already configured.

4. Restart Claude Code so it picks up the new ~/.claude/settings.json.

5. Docker group membership needs a full re-login. Until then expect
   "permission denied" on /var/run/docker.sock.

6. Service restarts were suppressed during apt so nothing would kill a running
   tmux or claude-rc session. When convenient:
       sudo needrestart          # or just reboot

7. tmux/vim clipboard goes over OSC 52 to your Mac. Enable it in iTerm2:
   Settings -> General -> Selection -> "Applications in terminal may access
   clipboard".
EOF

  if (( SSH_KEY_CREATED )); then
    cat <<EOF

8. A new SSH key was generated. Upload it via 'gh auth login' in step 3, or
   paste the line below at https://github.com/settings/ssh/new

EOF
    cat "$HOME/.ssh/id_ed25519.pub" 2>/dev/null || :
  fi
  printf '%s================================================================%s\n' "$C_GRN" "$C_OFF"
}

# -----------------------------------------------------------------------------
# | Run                                                                        |
# -----------------------------------------------------------------------------

trap cleanup EXIT
trap 'exit 130' INT
trap 'exit 143' TERM

phase_sudo

if (( SKIP_APT )); then
  step "apt packages"
  say "  --skip-apt given; skipping"
else
  phase_apt
fi

soft "shims"        phase_shims
soft "starship"     phase_starship
soft "fast-syntax-highlighting" phase_fsh
soft "mise runtimes" phase_mise
soft "pnpm"         phase_pnpm
soft "key templates" phase_keys
soft "symlinks"     phase_links
soft "vim plugins"  phase_vim
soft "ssh key"      phase_ssh
soft "docker group" phase_docker
soft "systemd"      phase_systemd
soft "login shell"  phase_chsh
soft "completions"  phase_completions

exit 0
