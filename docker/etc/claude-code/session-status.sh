#!/bin/bash
# Claude Code hook (wired up in managed-settings.json): record this session's
# state where the host can read it, as ~/.claude/session-status/<CID_NAME>.json.
# claude-docker --ls / --pick / --prune read these files (see lib/sessions.sh).
#
# Usage: session-status.sh <idle|working|waiting|ended>   (hook JSON on stdin)
#
# CID_NAME/CID_DIR are only set for project-mode containers, so this is a no-op
# elsewhere. A status hook must never get in the way of a session: every
# failure is swallowed and the script always exits 0.

state="$1"
input=$(cat 2>/dev/null)
[[ -n "${CID_NAME:-}" && -n "$state" ]] || exit 0

status_dir="$HOME/.claude/session-status"
status_file="$status_dir/$CID_NAME.json"
mkdir -p "$status_dir" 2>/dev/null || exit 0

# Repeats of the same state (e.g. the idle_prompt notification after Stop) keep
# the original timestamp, so "waiting 12m" counts from when Claude stopped.
if [[ "$(jq -r '.state // empty' "$status_file" 2>/dev/null)" == "$state" ]]; then
    exit 0
fi

jq -cn --arg state "$state" --arg name "$CID_NAME" --arg dir "${CID_DIR:-}" \
    --argjson ts "$(date +%s)" --argjson hook "${input:-null}" \
    '{state: $state, ts: $ts, cwd: ($hook.cwd // ""), session_id: ($hook.session_id // ""), name: $name, dir: $dir}' \
    > "$status_file.tmp" 2>/dev/null \
    && mv -f "$status_file.tmp" "$status_file" 2>/dev/null
rm -f "$status_file.tmp" 2>/dev/null
exit 0
