#!/bin/bash

# Stop the Claude development container (preserves workspace data)

echo "⏹️  Stopping Claude development environment..."
docker-compose down

echo "✅ Environment stopped. Workspace data is preserved."
echo "Run ./enter.sh to start again."