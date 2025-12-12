#!/bin/bash

# Claude Authentication Initialization Script
# Run this on first setup or to refresh Claude authentication

echo "🔧 Claude Authentication Setup"
echo "================================"

# Check if credentials directory exists
if [ ! -d "./credentials/.claude" ]; then
    echo "📁 Creating credentials/.claude directory..."
    mkdir -p ./credentials/.claude
fi

# Copy existing Claude config if available
if [ -d "$HOME/.claude" ]; then
    echo "📋 Found existing Claude config in home directory"
    read -p "Copy your existing Claude configuration? (y/n): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        cp -r $HOME/.claude/* ./credentials/.claude/ 2>/dev/null || true
        echo "✅ Claude configuration copied to credentials directory"
    fi
else
    echo "⚠️  No existing Claude config found in $HOME/.claude"
    echo "You'll need to authenticate Claude inside the container on first run"
fi

echo ""
echo "📝 Next Steps:"
echo "1. Start the container: docker-compose up -d"
echo "2. Enter the container: ./enter.sh"
echo "3. Run: claude login (if not already authenticated)"
echo "4. Your auth will now persist across container restarts!"
echo ""
echo "🔐 Security Note: credentials/.claude is gitignored for safety"