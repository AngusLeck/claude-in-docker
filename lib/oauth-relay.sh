# lib/oauth-relay.sh
# Start the host-side MCP OAuth callback relay (see lib/oauth-relay.py).
#
# Requires: ROOT_DIR to be set before calling.

# Safe to call on every launch: does nothing when no MCP server has a pinned
# oauth.callbackPort, and a relay already holding the port is left to serve it.
start_oauth_relay() {
    if ! command -v python3 &>/dev/null; then
        return 0
    fi
    python3 "$ROOT_DIR/lib/oauth-relay.py" || true
}
