# lib/gum.sh
# Gum wrappers that run inside Docker with fallback to plain prompts.
#
# If GUM_CONTAINER is set and running, uses docker exec (fast).
# Otherwise if image exists, uses docker run.
# Otherwise falls back to plain shell prompts.

GUM_IMAGE="${GUM_IMAGE:-claude-dev-ubuntu:latest}"

_gum_available() {
    # Check for running helper container first (fastest)
    if [[ -n "$GUM_CONTAINER" ]] && docker ps --format '{{.Names}}' | grep -q "^${GUM_CONTAINER}$"; then
        return 0
    fi
    # Check if image exists
    docker image inspect "$GUM_IMAGE" &>/dev/null
}

_gum() {
    if [[ -n "$GUM_CONTAINER" ]] && docker ps --format '{{.Names}}' | grep -q "^${GUM_CONTAINER}$"; then
        docker exec -it "$GUM_CONTAINER" gum "$@"
    elif docker image inspect "$GUM_IMAGE" &>/dev/null; then
        docker run --rm -it "$GUM_IMAGE" gum "$@"
    else
        return 1
    fi
}

gum_confirm() {
    local prompt="$1"
    if _gum_available; then
        _gum confirm "$prompt"
    else
        read -p "$prompt [y/N] " -n 1 -r
        echo
        [[ $REPLY =~ ^[Yy]$ ]]
    fi
}

gum_choose() {
    if _gum_available; then
        _gum choose "$@"
    else
        # Fallback to numbered menu
        local options=("$@")
        local i=1
        for opt in "${options[@]}"; do
            echo "  $i) $opt" >&2
            ((i++))
        done
        read -p "Choice [1-${#options[@]}]: " choice
        echo "${options[$((choice-1))]}"
    fi
}

gum_input() {
    if _gum_available; then
        _gum input "$@"
    else
        # Parse args for fallback
        local placeholder="" value="" password=false
        while [[ $# -gt 0 ]]; do
            case "$1" in
                --placeholder) placeholder="$2"; shift 2 ;;
                --value) value="$2"; shift 2 ;;
                --password) password=true; shift ;;
                *) shift ;;
            esac
        done

        if $password; then
            read -sp "$placeholder: " input
            echo >&2
        else
            read -p "$placeholder [$value]: " input
        fi
        echo "${input:-$value}"
    fi
}
