#!/bin/bash
set -e

echo "Setting up container credentials..."

# Configure Git to use GitHub token for HTTPS
if [ -n "$GITHUB_TOKEN" ]; then
    echo "✓ Configuring GitHub authentication"
    git config --global credential.helper store
    echo "https://token:$GITHUB_TOKEN@github.com" > /root/.git-credentials

    # Rewrite ssh github URLs to https so the token authenticates them.
    # There are no SSH keys in the container; this lets nix fetch private
    # flake inputs (e.g. git+ssh://git@github.com/ailohq/ailo-nix-lib) and
    # git clone ssh-style URLs using the token instead.
    git config --global url."https://github.com/".insteadOf "ssh://git@github.com/"
    git config --global --add url."https://github.com/".insteadOf "git@github.com:"
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

# Make host-absolute paths resolve inside the container.
# Claude records absolute host paths in ~/.claude.json (e.g. plugin installPath
# like /Users/jane/.claude/plugins/...). Since ~/.claude is bind-mounted at
# /root/.claude, we symlink the host home to /root so those paths still work.
if [ -n "$HOST_HOME" ] && [ "$HOST_HOME" != "/root" ]; then
    if [ ! -e "$HOST_HOME" ]; then
        echo "✓ Linking host home $HOST_HOME -> /root"
        mkdir -p "$(dirname "$HOST_HOME")"
        ln -sfn /root "$HOST_HOME"
    fi
fi

echo "Credential setup complete!"