#!/bin/bash
# install.sh - Install claude-docker for use from anywhere
set -e

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
INSTALL_DIR="$HOME/.claude-in-docker"
DEFAULT_BIN_DIR="$HOME/.local/bin"

source "$REPO_DIR/lib/installer.sh"

echo "================================"
echo "  Claude-in-Docker Installer"
echo "================================"
echo

install_gum

echo "Step 1: Configure credentials"
echo "-----------------------------"
configure_credentials
echo

echo "Step 2: Choose install location"
echo "--------------------------------"
choose_install_location
echo

echo "Step 3: Building Docker image"
echo "-----------------------------"
echo "(This may take a few minutes...)"
build_docker_image
echo

echo "Step 4: Installing files"
echo "------------------------"
install_files
echo

echo "Step 5: Creating symlink"
echo "------------------------"
create_symlink
echo

echo "Step 6: Shell completions"
echo "-------------------------"
install_completions
echo

show_success
