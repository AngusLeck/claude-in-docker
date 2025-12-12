#!/bin/bash

# Claude-in-Docker Setup Script (Nix Version)

set -e

echo "🐳 Setting up Claude-in-Docker environment with Nix..."

# Check if Nix is available
if ! command -v nix &> /dev/null; then
    echo "❌ Nix is required but not installed."
    echo "📝 Install Nix: https://nixos.org/download.html"
    echo "🍎 For macOS: curl --proto '=https' --tlsv1.2 -sSf -L https://install.determinate.systems/nix | sh -s -- install"
    exit 1
fi

# Check if experimental features are enabled
if ! nix --version | grep -q "flakes"; then
    echo "⚠️  Enabling Nix flakes and experimental features..."
    mkdir -p ~/.config/nix
    echo "experimental-features = nix-command flakes" >> ~/.config/nix/nix.conf
fi

# Create credentials directory
mkdir -p credentials

# Check if .env exists
if [ ! -f .env ]; then
    echo "📝 Creating .env file from template..."
    cp .env.example .env
    echo "⚠️  Please edit .env file with your actual credentials!"
fi

# Setup git config if it doesn't exist
if [ ! -f credentials/.gitconfig ]; then
    echo "📝 Setting up git configuration..."
    read -p "Enter your Git username: " git_username
    read -p "Enter your Git email: " git_email
    
    cat > credentials/.gitconfig << EOF
[user]
    name = $git_username
    email = $git_email
[init]
    defaultBranch = main
[pull]
    rebase = false
[core]
    autocrlf = input
EOF
fi

# Create Claude config directory
mkdir -p credentials/.claude

# Build the Docker image with Nix
echo "🏗️  Building Claude development environment with Nix..."
if ! nix run .#build-docker; then
    echo "❌ Failed to build Docker image"
    echo "💡 Try: nix build .#docker && docker load < result"
    exit 1
fi

echo "🚀 Starting Claude development environment..."
docker-compose up -d

echo ""
echo "✅ Claude-in-Docker is ready!"
echo ""
echo "📋 Next steps:"
echo "  ./enter.sh                    # Enter the development environment"
echo "  ./stop.sh                     # Stop the environment"
echo "  nix develop                   # Test environment locally"
echo ""
echo "🔧 Inside the container:"
echo "  setup_repo customer-service  # Clone to /workspace/repos/customer-service"  
echo "  claude                        # Start Claude CLI"
echo "  gh auth login                 # Authenticate with GitHub"
echo ""
echo "💾 The workspace is persistent and will survive container restarts."