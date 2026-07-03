# lib/flags.sh
# Parse mode flags for claude-docker scripts.
#
# Usage:
#   source lib/flags.sh
#   parse_mode_flags "$@"
#   set -- "${REMAINING_ARGS[@]}"
#
# Sets: SHELL_MODE, DANGEROUS_MODE, DOCKER_SOCK_MODE, PUBLISH_PORTS, REMAINING_ARGS

SHELL_MODE=false
DANGEROUS_MODE=false
DOCKER_SOCK_MODE=false
PUBLISH_PORTS=()
REMAINING_ARGS=()

parse_mode_flags() {
    SHELL_MODE=false
    DANGEROUS_MODE=false
    DOCKER_SOCK_MODE=false
    PUBLISH_PORTS=()
    REMAINING_ARGS=()

    while [[ $# -gt 0 ]]; do
        case "$1" in
            -s|--shell)
                SHELL_MODE=true
                shift
                ;;
            -d|--dangerous)
                DANGEROUS_MODE=true
                shift
                ;;
            --docker)
                DOCKER_SOCK_MODE=true
                shift
                ;;
            -p|--publish)
                if [[ -z "${2:-}" ]]; then
                    echo "Error: $1 requires a value, e.g. -p 3000 or -p 3001:3000" >&2
                    exit 1
                fi
                if [[ ! "$2" =~ ^[0-9]+(-[0-9]+)?(:[0-9]+(-[0-9]+)?)?$ ]]; then
                    echo "Error: invalid port spec '$2' (expected PORT[-PORT][:PORT[-PORT]], e.g. 3000, 3001:3000, 3000-3010)" >&2
                    exit 1
                fi
                PUBLISH_PORTS+=("$2")
                shift 2
                ;;
            *)
                # Remaining args go to claude
                REMAINING_ARGS=("$@")
                break
                ;;
        esac
    done
}

# Normalize a validated port spec to an explicit loopback-only publish value,
# so agent dev servers are never reachable from the LAN.
# "3000" -> "127.0.0.1:3000:3000"; "3001:3000" -> "127.0.0.1:3001:3000"
publish_value() {
    local spec="$1"
    if [[ "$spec" == *:* ]]; then
        echo "127.0.0.1:$spec"
    else
        echo "127.0.0.1:$spec:$spec"
    fi
}
