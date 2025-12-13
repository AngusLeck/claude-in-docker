#!/bin/bash

# Keep the container running
echo "Container is ready and running..."
echo "Use 'docker exec -it claude-dev-env bash' to enter the container"

# Keep container alive
exec tail -f /dev/null