#!/bin/bash
# Container entrypoint - runs setup then hands off to command
set -e

# Run credential setup
/setup-container/setup-credentials.sh

# Execute the command passed to the container
# This replaces the current process, making the command PID 1
exec "$@"
