#!/bin/bash
set -e

echo "Setting up container credentials..."

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

# Configure NPM token for private registry access
if [ -n "$NPM_TOKEN" ]; then
    echo "✓ Configuring NPM authentication"
    npm config set //registry.npmjs.org/:_authToken "$NPM_TOKEN"
fi

echo "Credential setup complete!"