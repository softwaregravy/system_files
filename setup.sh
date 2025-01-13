
#!/usr/bin/env bash

set -euo pipefail

echo "Starting system setup..."

# Helper functions
check_command() {
    command -v "$1" >/dev/null 2>&1 || { echo >&2 "Required command $1 not found. Aborting."; exit 1; }
}

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
            read -r REPLY || true
            if [ "$REPLY" = "y" ] || [ "$REPLY" = "Y" ]; then
                ln -sf "$source" "$target"
                echo "Updated symlink: $target -> $source"
            fi
        fi
    elif [ -e "$target" ]; then
        echo "Warning: $target exists but is not a symlink"
        echo -n "Replace with symlink? (y/n) "
        REPLY="n"
        read -r REPLY || true
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

# Create workspaces directory
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

# Check for Homebrew and install if not present
echo "Checking for Homebrew..."
if ! command -v brew &>/dev/null; then
    echo "Installing Homebrew..."
    /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
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


# Create symbolic links
echo "Setting up symbolic links..."
LINKS=(
    "$SYSTEM_FILES_DIR/zshrc:$HOME/.zshrc"
    "$SYSTEM_FILES_DIR/zshrc.cmdprompt:$HOME/.zshrc.cmdprompt"
    "$SYSTEM_FILES_DIR/vimrc:$HOME/.vimrc"
    "$SYSTEM_FILES_DIR/screenrc:$HOME/.screenrc"
    "$SYSTEM_FILES_DIR/irbrc:$HOME/.irbrc"
    "$SYSTEM_FILES_DIR/inputrc:$HOME/.inputrc"
    "$SYSTEM_FILES_DIR/gemrc:$HOME/.gemrc"
    "$SYSTEM_FILES_DIR/gitconfig:$HOME/.gitconfig"
    "$SYSTEM_FILES_DIR/ir_black.vim:$HOME/.vim/colors/ir_black.vim"
)

for link in "${LINKS[@]}"; do
    source="${link%%:*}"
    target="${link#*:}"
    create_symlink "$(realpath "$source")" "$target"
done

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

echo "Setup complete!"
