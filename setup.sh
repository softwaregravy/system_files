
#!/usr/bin/env bash

set -euo pipefail

echo "Starting system setup..."

create_symlink() {
  local source=$1
  local target=$2

  # Ensure target directory exists
  mkdir -p "$(dirname "$target")"

  if [ -L "$target" ]; then
    echo "Symlink already exists: $target"
    # Verify it points to the correct location
    current_source=$(readlink "$target")
    if [ "$current_source" != "$source" ]; then
      echo "Warning: $target points to $current_source instead of $source"
      echo -n "Update symlink? (y/n) "
      REPLY="n"
      read -r REPLY </dev/tty || true
      if [ "$REPLY" = "y" ] || [ "$REPLY" = "Y" ]; then
        ln -sf "$source" "$target"
        echo "Updated symlink: $target -> $source"
      fi
    fi
  elif [ -e "$target" ]; then
    echo "Warning: $target exists but is not a symlink"
    echo -n "Replace with symlink? (y/n) "
    REPLY="n"
    read -r REPLY </dev/tty || true
    if [ "$REPLY" = "y" ] || [ "$REPLY" = "Y" ]; then
      mv "$target" "${target}.backup"
      ln -s "$source" "$target"
      echo "Created symlink and backed up original: $target -> $source"
    fi
  else
    ln -s "$source" "$target"
    echo "Created symlink: $target -> $source"
  fi
}

# Check for XCode and Command Line Tools
echo "Checking for XCode Command Line Tools..."
if ! xcode-select -p &>/dev/null; then
  echo "XCode Command Line Tools not found. Please install them first."
  echo "Run: xcode-select --install"
  exit 1
fi

# Create directories
echo "Setting up workspace directory..."
WORKSPACE_DIR="$HOME/workspace"
mkdir -p "$WORKSPACE_DIR"

# Clone or update system files
SYSTEM_FILES_DIR="$WORKSPACE_DIR/system_files"
if [ ! -d "$SYSTEM_FILES_DIR" ]; then
  echo "Cloning system files repository..."
  git clone https://github.com/softwaregravy/system_files.git "$SYSTEM_FILES_DIR"
else
  echo "Updating system files repository..."
  (cd "$SYSTEM_FILES_DIR" && git pull)
fi

# Create and secure .keys directory
KEYS_TEMPLATE_DIR="$SYSTEM_FILES_DIR/keys"
# make sure we have one locally so nothing else fails
mkdir -p "$KEYS_TEMPLATE_DIR"

echo "Setting up .keys directory..."
KEYS_DIR="$HOME/.keys"
mkdir -p "$KEYS_DIR"
chmod 700 "$KEYS_DIR"

# Copy over files
for template in "$KEYS_TEMPLATE_DIR"/*; do
  if [ -f "$template" ]; then
    filename=$(basename "$template")
    target="$KEYS_DIR/$filename"
    if [ ! -f "$target" ]; then
      cp "$template" "$target"
      chmod 600 "$target"
      echo "Created key template at $target"
    fi
  fi
done

# Check for Homebrew and install if not present
echo "Checking for Homebrew..."
if ! command -v brew &>/dev/null; then
  echo "Installing Homebrew..."
  echo "Homebrew installation requires sudo access. You may be prompted for your password."
  sudo -v
  # Keep-alive: update existing sudo time stamp until the script has finished
  while true; do sudo -n true; sleep 60; kill -0 "$$" || exit; done 2>/dev/null &
  
  /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
  # Add Homebrew to the PATH for the current script
  eval "$(/opt/homebrew/bin/brew shellenv)"
else
  echo "Homebrew already installed"
fi

# Install programs from Brewfile
echo "Installing programs from Brewfile..."
if [ -f "$SYSTEM_FILES_DIR/Brewfile" ]; then
  brew bundle --file="$SYSTEM_FILES_DIR/Brewfile"
else
  echo "Warning: Brewfile not found in $SYSTEM_FILES_DIR"
fi


echo "Setting up pyenv global Python version..."
if command -v pyenv &>/dev/null; then
  if [ -z "$(pyenv versions --bare)" ]; then
    echo "No Python versions installed. Installing latest Python 3..."
    pyenv install 3 -s 
    pyenv rehash
  fi

  highest_version=$(pyenv versions --bare | grep -v "/" | grep -e "^3\." | sort -V | tail -1)
  if [ -n "$highest_version" ]; then
    echo "Setting global Python version to $highest_version..."
    pyenv global "$highest_version" || echo "Failed to set global Python version"
  else
    echo "No suitable Python versions found. Install one with: pyenv install <version>"
  fi
fi

# Install or update RVM
echo "Setting up RVM..."
if ! command -v rvm &>/dev/null; then
  
  echo "...Importing GPG keys for RVM"
  command curl -sSL https://rvm.io/mpapis.asc | gpg --import -
  command curl -sSL https://rvm.io/pkuczynski.asc | gpg --import -
  
  # Install RVM
  # the following works around error:
  # /Users/john/.rvm/scripts/functions/support: line 182: _system_name: unbound variable
  # I guess we just hope

  set +u
  echo "... Installing RVM"
  curl -sSL https://get.rvm.io | bash -s stable 
  
  source "$HOME/.rvm/scripts/rvm"
  
  echo "...Removing default Ruby alias from RVM"
  rvm alias delete default
  set -u
else
  echo "...RVM already installed" 
  # if you need to update
  # rvm get stable 
fi

# Create symbolic links
echo "Setting up symbolic links..."
LINKS=(
"$SYSTEM_FILES_DIR/setup.sh:$HOME/setup.sh"
"$SYSTEM_FILES_DIR/zshrc:$HOME/.zshrc"
"$SYSTEM_FILES_DIR/zshrc.cmdprompt:$HOME/.zshrc.cmdprompt"
"$SYSTEM_FILES_DIR/vimrc:$HOME/.vimrc"
"$SYSTEM_FILES_DIR/screenrc:$HOME/.screenrc"
"$SYSTEM_FILES_DIR/irbrc:$HOME/.irbrc"
"$SYSTEM_FILES_DIR/inputrc:$HOME/.inputrc"
"$SYSTEM_FILES_DIR/gemrc:$HOME/.gemrc"
"$SYSTEM_FILES_DIR/gitconfig:$HOME/.gitconfig"
"$SYSTEM_FILES_DIR/rvmrc:$HOME/.rvmrc"
"$SYSTEM_FILES_DIR/npmrc:$HOME/.npmrc"
"$SYSTEM_FILES_DIR/ir_black.vim:$HOME/.vim/colors/ir_black.vim"
"$SYSTEM_FILES_DIR/ngrok.yml:$HOME/Library/Application Support/ngrok/ngrok.yml"
"$SYSTEM_FILES_DIR/vim/after/syntax/sh.vim:$HOME/.vim/after/syntax/sh.vim"
)

for link in "${LINKS[@]}"; do
  source="${link%%:*}"
  target="${link#*:}"
  create_symlink "$(realpath "$source")" "$target"
done

# Setup Vim packages
echo "Setting up Vim packages..."
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
# Add more packages here 
)

setup_vim_package() {
  local repo_url=$1
  local package_name=$(basename "$repo_url" .git)
  local package_dir="$HOME/.vim/pack/vendor/start/$package_name"

  if [ ! -d "$package_dir" ]; then
    echo "Installing Vim package: $package_name..."
    mkdir -p "$package_dir"
    git clone "$repo_url" "$package_dir"
  else
    echo "Updating Vim package: $package_name..."
    (cd "$package_dir" && git pull)
  fi
}

# Ensure Vim package directories exist
mkdir -p "$HOME/.vim/pack/vendor/start"

# Install or update each package
for package in "${VIM_PACKAGES[@]}"; do
  setup_vim_package "$package"
done

echo "Generating helptags for all Vim packages..."
vim -u NONE -c "silent! helptags ALL" -c q >/dev/null 2>&1

# Setup GitHub SSH keys if they don't exist
SSH_DIR="$HOME/.ssh"
if [ ! -f "$SSH_DIR/id_ed25519" ]; then
  echo "Setting up GitHub SSH keys..."
  mkdir -p "$SSH_DIR"
  chmod 700 "$SSH_DIR"
  ssh-keygen -t ed25519 -C "$(git config --get user.email)" -f "$SSH_DIR/id_ed25519" -N ""
  # Start ssh-agent and add key
  eval "$(ssh-agent -s)"
  ssh-add "$SSH_DIR/id_ed25519"

  echo "New SSH key generated. Please add this public key to your GitHub account:"
  cat "$SSH_DIR/id_ed25519.pub"
  echo "Visit https://github.com/settings/ssh/new to add the key"
else
  echo "GitHub SSH keys already exist"
fi

# Install yek if not present
echo "Checking for yek..."
if ! command -v yek &>/dev/null; then
  echo "Installing yek..."
  curl -fsSL https://bodo.run/yek.sh | bash
else
  echo "yek already installed"
fi

# Create symbolic links for global Git hooks
echo "Setting up global Git hooks..."
GLOBAL_GIT_HOOKS_DIR="$HOME/.git-hooks"
mkdir -p "$GLOBAL_GIT_HOOKS_DIR"

# Add prepare-commit-msg hook
create_symlink "$SYSTEM_FILES_DIR/git_hooks/prepare-commit-msg" "$GLOBAL_GIT_HOOKS_DIR/prepare-commit-msg"
chmod +x "$GLOBAL_GIT_HOOKS_DIR/prepare-commit-msg"

# Configure Git to use global hooks
git config --global core.hooksPath "$GLOBAL_GIT_HOOKS_DIR"

# Create program specific completions
echo "Setting up bespoke commandline completions"
if command -v ngrok &>/dev/null; then
  echo "Setting up ngrok completions..."
  ngrok completion > /opt/homebrew/share/zsh/site-functions/_ngrok
  chmod 644 /opt/homebrew/share/zsh/site-functions/_ngrok
fi

# Precompile all copmletions
echo "Pre-compiling zsh completions..."

# Generate and compile completion dump using zsh
zsh << 'EOF'
COMPDUMP="${ZDOTDIR:-$HOME}/.zcompdump"
FPATH="$(brew --prefix)/share/zsh/site-functions:$FPATH"
autoload -Uz compinit
compinit
zcompile -M "$COMPDUMP"
chmod 644 "$COMPDUMP"*
EOF


echo "Setup complete!"
