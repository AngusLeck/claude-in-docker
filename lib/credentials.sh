# lib/credentials.sh - Runtime credential detection
# Source this file, don't execute it directly

# Detect Claude credentials from file or macOS Keychain
# Sets CLAUDE_CREDENTIALS environment variable if found
detect_claude_credentials() {
    # Already set (e.g., from .env file)
    if [[ -n "$CLAUDE_CREDENTIALS" ]]; then
        return 0
    fi

    # Try credentials file first
    local creds_file="$HOME/.claude/.credentials.json"
    if [[ -f "$creds_file" ]]; then
        CLAUDE_CREDENTIALS=$(cat "$creds_file")
        export CLAUDE_CREDENTIALS
        return 0
    fi

    # Try macOS Keychain
    if [[ "$(uname)" == "Darwin" ]]; then
        local keychain_creds
        keychain_creds=$(security find-generic-password -s "Claude Code-credentials" -w 2>/dev/null || echo "")
        if [[ -n "$keychain_creds" ]]; then
            CLAUDE_CREDENTIALS="$keychain_creds"
            export CLAUDE_CREDENTIALS
            return 0
        fi
    fi

    # No credentials found - not an error
    # User can run `claude login` inside the container
    return 0
}
