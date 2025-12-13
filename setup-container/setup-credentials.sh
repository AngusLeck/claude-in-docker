#!/bin/bash
set -e

echo "Setting up container credentials..."

# Copy root-level claude config if it exists
if [ -f /root/.claude-host.json ]; then
    echo "✓ Copying Claude configuration from host"
    cp /root/.claude-host.json /root/.claude.json
fi

# Populate credentials from environment variable
if [ -n "$CLAUDE_CREDENTIALS" ]; then
    echo "✓ Setting up Claude credentials"
    mkdir -p /root/.claude
    echo "$CLAUDE_CREDENTIALS" > /root/.claude/.credentials.json
fi

# Configure Git to use GitHub token for HTTPS
if [ -n "$GITHUB_TOKEN" ]; then
    echo "✓ Configuring GitHub authentication"
    git config --global credential.helper store
    echo "https://token:$GITHUB_TOKEN@github.com" > /root/.git-credentials
fi

# Configure Git user from environment variables
if [ -n "$GIT_USER_NAME" ]; then
    echo "✓ Setting Git user name: $GIT_USER_NAME"
    git config --global user.name "$GIT_USER_NAME"
fi

if [ -n "$GIT_USER_EMAIL" ]; then
    echo "✓ Setting Git user email: $GIT_USER_EMAIL"
    git config --global user.email "$GIT_USER_EMAIL"
fi

echo "Credential setup complete!"