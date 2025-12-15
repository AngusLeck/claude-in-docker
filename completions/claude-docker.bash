# Bash completion for claude-docker
# Source this file or place in /etc/bash_completion.d/

_claude_docker() {
    local cur="${COMP_WORDS[COMP_CWORD]}"
    local prev="${COMP_WORDS[COMP_CWORD-1]}"

    # All available options
    local opts="-g --global -s --shell -d --dangerous -w --workspace --update --uninstall --help -h"

    # If previous word was -g/--global, offer mode options
    case "$prev" in
        -g|--global)
            COMPREPLY=($(compgen -W "-s --shell -d --dangerous" -- "$cur"))
            return 0
            ;;
    esac

    # Default: suggest all options
    COMPREPLY=($(compgen -W "$opts" -- "$cur"))
}

complete -F _claude_docker claude-docker
