#!/bin/bash

# Claude Development Environment Startup

# Create necessary directories
mkdir -p /workspace/repos /root/.claude

# Initialize Claude config on first run (copy from host credentials if needed)
if [ ! -f "/root/.claude/.initialized" ]; then
    # If we have initial config from host, copy it once
    if [ -d "/tmp/.claude_config" ]; then
        cp -rn /tmp/.claude_config/* /root/.claude/ 2>/dev/null || true
    fi
    # Copy your SuperClaude config if it exists
    if [ -d "/workspace/credentials/.claude" ] && [ ! -f "/root/.claude/CLAUDE.md" ]; then
        cp -rn /workspace/credentials/.claude/* /root/.claude/ 2>/dev/null || true
    fi
    touch /root/.claude/.initialized
    echo "✅ Claude configuration initialized in persistent volume"
fi

# Set up .bashrc for the session
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
    if ! which /usr/local/bin/claude &> /dev/null && ! which /usr/bin/claude &> /dev/null; then
        echo "Installing Claude CLI..."
        npm install -g @anthropic-ai/claude-code
    fi
    command claude "$@"
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

# Welcome message on shell start
echo "🔧 Claude Development Environment Ready"
echo "💡 Commands: claude, setup_repo <name>, gh, git"
echo "📁 Workspace: /workspace/repos/"
echo "🛠️  Tools available: node, python, docker, kubectl, etc."
EOF

# Setup complete, keep container running
cd /workspace

# Keep container alive for docker exec to work
while true; do
    sleep 30
done