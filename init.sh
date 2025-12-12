#!/bin/bash

# Initialize Claude development environment

# Create directories if they don't exist
mkdir -p /workspace/repos
mkdir -p /root

# Set up bashrc if it doesn't exist
if [ ! -f /root/.bashrc ]; then
    cat > /root/.bashrc << 'EOF'
# Claude Development Environment

# Convenient aliases
alias ll="ls -la"
alias gs="git status"
alias gp="git pull"
alias gc="git commit -m"
alias gph="git push"

# Claude function - installs CLI on first use
claude() {
    if ! command -v claude-cli &> /dev/null; then
        echo "Installing Claude CLI..."
        npm install -g @anthropic-ai/claude
    fi
    claude-cli "$@"
}

# Repository setup function
setup_repo() {
    if [ -z "$1" ]; then
        echo "Usage: setup_repo <repo-name>"
        return 1
    fi
    mkdir -p /workspace/repos
    cd /workspace/repos
    if [ ! -d "$1" ]; then
        echo "Cloning $1..."
        gh repo clone "ailohq/$1" || git clone "https://github.com/ailohq/$1.git"
    fi
    cd "$1"
    echo "Ready to work on $1 in /workspace/repos/$1"
}

# Environment setup
export PATH=/run/current-system/sw/bin:$PATH
export HOME=/root

# Welcome message
echo "🔧 Claude Development Environment Ready"
echo "💡 Commands: claude, setup_repo <name>, gh, git"
echo "📁 Workspace: /workspace/repos/"
EOF
fi

# Execute the command passed to docker run, or start interactive shell
exec "$@"