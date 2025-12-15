#!/bin/bash
# install.sh - Install claude-docker for use from anywhere
set -e

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
INSTALL_DIR="$HOME/.claude-in-docker"
DEFAULT_BIN_DIR="$HOME/.local/bin"

echo "================================"
echo "  Claude-in-Docker Installer"
echo "================================"
echo

# Check for gum and offer to install if missing
check_gum() {
    if command -v gum &>/dev/null; then
        return 0
    fi

    echo "gum is not installed. It provides a nicer installation experience."
    echo
    echo "Install options:"
    echo "  macOS:  brew install gum"
    echo "  Linux:  See https://github.com/charmbracelet/gum#installation"
    echo
    read -p "Continue without gum? [Y/n] " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Nn]$ ]]; then
        echo "Please install gum and run this script again."
        exit 1
    fi
    return 1
}

HAS_GUM=false
if check_gum; then
    HAS_GUM=true
fi

# Helper functions for prompts
prompt_choice() {
    local prompt="$1"
    shift
    local options=("$@")

    if $HAS_GUM; then
        gum choose "${options[@]}"
    else
        echo "$prompt"
        local i=1
        for opt in "${options[@]}"; do
            echo "  $i) $opt"
            ((i++))
        done
        read -p "Choice [1-${#options[@]}]: " choice
        echo "${options[$((choice-1))]}"
    fi
}

prompt_input() {
    local prompt="$1"
    local default="$2"

    if $HAS_GUM; then
        gum input --placeholder "$prompt" --value "$default"
    else
        read -p "$prompt [$default]: " value
        echo "${value:-$default}"
    fi
}

prompt_secret() {
    local prompt="$1"

    if $HAS_GUM; then
        gum input --password --placeholder "$prompt"
    else
        read -sp "$prompt: " value
        echo
        echo "$value"
    fi
}

prompt_confirm() {
    local prompt="$1"

    if $HAS_GUM; then
        gum confirm "$prompt"
    else
        read -p "$prompt [y/N] " -n 1 -r
        echo
        [[ $REPLY =~ ^[Yy]$ ]]
    fi
}

spin() {
    local title="$1"
    shift

    if $HAS_GUM; then
        gum spin --spinner dot --title "$title" -- "$@"
    else
        echo "$title"
        "$@"
    fi
}

# Step 1: Build Docker image
echo "Step 1: Building Docker image"
echo "-----------------------------"

cd "$REPO_DIR"
spin "Building claude-dev-ubuntu image..." docker-compose build
echo "Done building image."
echo

# Step 2: Copy files to install directory
echo "Step 2: Installing files"
echo "------------------------"

mkdir -p "$INSTALL_DIR"

# Copy all necessary files
cp "$REPO_DIR/docker-compose.yml" "$INSTALL_DIR/"
cp "$REPO_DIR/docker-compose.project.yml" "$INSTALL_DIR/"
cp "$REPO_DIR/claude-docker" "$INSTALL_DIR/"
cp "$REPO_DIR/claude-docker-global" "$INSTALL_DIR/"
cp "$REPO_DIR/claude-docker-project" "$INSTALL_DIR/"
cp -r "$REPO_DIR/config" "$INSTALL_DIR/"
cp -r "$REPO_DIR/setup-container" "$INSTALL_DIR/"

# Create workspace directory for global mode
mkdir -p "$INSTALL_DIR/workspace"

# Make scripts executable
chmod +x "$INSTALL_DIR/claude-docker"
chmod +x "$INSTALL_DIR/claude-docker-global"
chmod +x "$INSTALL_DIR/claude-docker-project"

echo "Files installed to $INSTALL_DIR"
echo

# Step 3: Setup credentials
echo "Step 3: Configure credentials"
echo "-----------------------------"

# Check if .env already exists
if [[ -f "$INSTALL_DIR/.env" ]]; then
    if ! prompt_confirm "Credentials already exist. Overwrite?"; then
        echo "Keeping existing credentials."
    else
        rm "$INSTALL_DIR/.env"
    fi
fi

if [[ ! -f "$INSTALL_DIR/.env" ]]; then
    method=$(prompt_choice "How would you like to configure credentials?" \
        "Enter credentials interactively" \
        "Edit config file in editor")

    if [[ "$method" == "Enter credentials interactively" ]]; then
        # Try to auto-detect existing values
        DEFAULT_GIT_NAME=$(git config --global user.name 2>/dev/null || echo "")
        DEFAULT_GIT_EMAIL=$(git config --global user.email 2>/dev/null || echo "")
        DEFAULT_GH_TOKEN=""
        if command -v gh &>/dev/null && gh auth status &>/dev/null 2>&1; then
            DEFAULT_GH_TOKEN=$(gh auth token 2>/dev/null || echo "")
        fi

        echo
        echo "Git Configuration:"
        GIT_USER_NAME=$(prompt_input "Git user name" "$DEFAULT_GIT_NAME")
        GIT_USER_EMAIL=$(prompt_input "Git user email" "$DEFAULT_GIT_EMAIL")

        echo
        echo "GitHub Token:"
        if [[ -n "$DEFAULT_GH_TOKEN" ]]; then
            if prompt_confirm "Found GitHub token from gh CLI. Use it?"; then
                GITHUB_TOKEN="$DEFAULT_GH_TOKEN"
            else
                GITHUB_TOKEN=$(prompt_secret "GitHub personal access token")
            fi
        else
            GITHUB_TOKEN=$(prompt_secret "GitHub personal access token")
        fi

        echo
        echo "Claude Credentials:"
        echo "(Paste the JSON from ~/.claude/.credentials.json or leave empty to use ~/.claude.json)"
        CLAUDE_CREDENTIALS=$(prompt_secret "Claude credentials JSON (optional)")

        # Write .env file
        cat > "$INSTALL_DIR/.env" << EOF
# Claude-in-Docker credentials
# Generated by install.sh on $(date)

GIT_USER_NAME=$GIT_USER_NAME
GIT_USER_EMAIL=$GIT_USER_EMAIL
GITHUB_TOKEN=$GITHUB_TOKEN
CLAUDE_CREDENTIALS=$CLAUDE_CREDENTIALS
EOF

        echo "Credentials saved to $INSTALL_DIR/.env"

    else
        # Copy template and open in editor
        cp "$REPO_DIR/.env.example" "$INSTALL_DIR/.env"

        EDITOR_CHOICE=$(prompt_choice "Which editor?" \
            "${EDITOR:-vim}" \
            "vim" \
            "nano")

        echo "Opening $INSTALL_DIR/.env in $EDITOR_CHOICE..."
        echo "Save and close when done."
        sleep 1
        "$EDITOR_CHOICE" "$INSTALL_DIR/.env"
    fi
fi

echo

# Step 4: Add symlink to PATH
echo "Step 4: Add to PATH"
echo "-------------------"

# Determine install location
if [[ -d "$DEFAULT_BIN_DIR" ]] && [[ ":$PATH:" == *":$DEFAULT_BIN_DIR:"* ]]; then
    BIN_DIR="$DEFAULT_BIN_DIR"
else
    echo "Default location $DEFAULT_BIN_DIR is not in PATH."
    BIN_DIR=$(prompt_input "Symlink location" "$DEFAULT_BIN_DIR")
    mkdir -p "$BIN_DIR"
fi

# Create symlink (remove old one if exists)
rm -f "$BIN_DIR/claude-docker"
ln -s "$INSTALL_DIR/claude-docker" "$BIN_DIR/claude-docker"

echo "Symlink created: $BIN_DIR/claude-docker -> $INSTALL_DIR/claude-docker"
echo

# Check if BIN_DIR is in PATH
if [[ ":$PATH:" != *":$BIN_DIR:"* ]]; then
    echo "Warning: $BIN_DIR is not in your PATH."
    echo "Add this to your shell config (~/.bashrc or ~/.zshrc):"
    echo
    echo "  export PATH=\"$BIN_DIR:\$PATH\""
    echo
fi

# Done
echo "================================"
echo "  Installation complete!"
echo "================================"
echo
echo "Usage:"
echo "  claude-docker         Run Claude in current directory (project mode)"
echo "  claude-docker -g      Run Claude in global workspace mode"
echo
echo "Installation directory: $INSTALL_DIR"
echo "Symlink: $BIN_DIR/claude-docker"
echo
echo "The repo at $REPO_DIR can now be safely deleted if desired."
echo
