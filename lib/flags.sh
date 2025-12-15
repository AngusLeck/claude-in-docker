# lib/flags.sh
# Parse mode flags for claude-docker scripts.
#
# Usage:
#   source lib/flags.sh
#   parse_mode_flags "$@"
#   set -- "${REMAINING_ARGS[@]}"
#
# Sets: SHELL_MODE, DANGEROUS_MODE, REMAINING_ARGS

SHELL_MODE=false
DANGEROUS_MODE=false
REMAINING_ARGS=()

parse_mode_flags() {
    SHELL_MODE=false
    DANGEROUS_MODE=false
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
            *)
                # Remaining args go to claude
                REMAINING_ARGS=("$@")
                break
                ;;
        esac
    done
}
