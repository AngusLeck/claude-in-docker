#!/bin/bash

# Enter the Claude development environment
# Usage: ./enter.sh

if ! docker ps | grep -q claude-dev-env; then
    echo "🚨 Claude development container is not running!"
    echo "💡 Start it with: docker-compose up -d"
    echo "🏗️  Or build & start with: nix run .#build-docker"
    exit 1
fi

echo "🚪 Entering Claude development environment..."
echo "💡 Available commands:"
echo "  setup_repo <repo-name> - Clone and enter a repository"
echo "  claude                 - Start Claude CLI (auto-installs)"
echo "  gh, git, node, python  - Development tools"
echo "  exit                   - Leave container"
echo ""
docker exec -it claude-dev-env bash