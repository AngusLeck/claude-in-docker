# lib/container.sh
# Container helper functions.
#
# Requires: CONTAINER_NAME to be set before calling these functions.
# Requires: SHELL_MODE, DANGEROUS_MODE from lib/flags.sh for run_in_container.

container_exists() {
    docker ps -a --format '{{.Names}}' | grep -q "^${CONTAINER_NAME}$"
}

container_running() {
    docker ps --format '{{.Names}}' | grep -q "^${CONTAINER_NAME}$"
}

ensure_container_running() {
    if ! container_running; then
        docker start "$CONTAINER_NAME" >/dev/null
        sleep 1
    fi
}

# Run the appropriate command in the container based on mode flags.
# Usage: run_in_container [args to pass to claude]
run_in_container() {
    if $SHELL_MODE; then
        exec docker exec -it "$CONTAINER_NAME" bash
    elif $DANGEROUS_MODE; then
        exec docker exec -it "$CONTAINER_NAME" claude --dangerously-skip-permissions "$@"
    else
        exec docker exec -it "$CONTAINER_NAME" claude "$@"
    fi
}
