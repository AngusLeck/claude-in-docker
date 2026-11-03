# lib/sessions.sh
# Name, list and reattach to running claude-docker containers.
#
# Project containers are labelled cid.project=<dir basename> and
# cid.dir=<host dir> (see bin/claude-docker-project). Containers started before
# those labels existed are still listed, using their working dir and mounts.

GLOBAL_CONTAINER_NAME="claude-docker-global"

# Every claude-docker container (project and global) is the compose service
# "claude" in the compose project "docker" (the name of the compose directory).
SESSION_FILTERS=(--filter "label=com.docker.compose.service=claude" --filter "label=com.docker.compose.project=docker")

# Claude Code binds Ctrl+P to history, and docker's default detach sequence
# (ctrl-p,ctrl-q) holds back every Ctrl+P until the next key. Ctrl+Q is unbound
# in Claude Code and ignored as flow control once docker puts the tty in raw mode.
ATTACH_DETACH_KEYS="ctrl-q,ctrl-q"

# Docker-valid container name for a project session: claude-<dir>-<HHMM>,
# with -2, -3... appended if that name is already taken.
# Usage: project_container_name <dir basename>
project_container_name() {
    local slug base candidate suffix=2
    slug=$(echo "$1" | tr '[:upper:]' '[:lower:]' | sed -E 's/[^a-z0-9_.-]+/-/g; s/^[-_.]+//; s/[-_.]+$//')
    base="claude-${slug:-project}-$(date +%H%M)"
    candidate="$base"
    while docker ps -a --format '{{.Names}}' | grep -qx "$candidate"; do
        candidate="$base-$suffix"
        suffix=$((suffix + 1))
    done
    echo "$candidate"
}

# Print one tab-separated line per running session: name, project, host dir, age.
session_rows() {
    local id name project dir workdir mount_source age
    # Fields are split on the ASCII unit separator: a tab is IFS whitespace, so
    # read would merge the empty fields of unlabelled containers.
    local sep=$'\x1f'
    local format="{{.Name}}${sep}{{index .Config.Labels \"cid.project\"}}${sep}{{index .Config.Labels \"cid.dir\"}}${sep}{{.Config.WorkingDir}}${sep}{{\$wd := .Config.WorkingDir}}{{range .Mounts}}{{if eq .Destination \$wd}}{{.Source}}{{end}}{{end}}"
    for id in $(docker ps -q "${SESSION_FILTERS[@]}"); do
        IFS="$sep" read -r name project dir workdir mount_source < <(docker inspect --format "$format" "$id")
        name="${name#/}"
        age=$(docker ps --filter "id=$id" --format '{{.RunningFor}}')
        if [[ "$name" == "$GLOBAL_CONTAINER_NAME" ]]; then
            project="(global)"
            dir=$(docker inspect --format '{{range .Mounts}}{{if eq .Destination "/workspace"}}{{.Source}}{{end}}{{end}}' "$id")
        elif [[ -z "$project" ]]; then
            # Unlabelled container from an older claude-docker
            project="$(basename "$workdir")"
            dir="$mount_source"
        fi
        # Docker Desktop reports bind mount sources under /host_mnt
        dir="${dir#/host_mnt}"
        printf '%s\t%s\t%s\t%s\n' "$name" "$project" "${dir:--}" "$age"
    done
}

list_sessions() {
    local rows
    rows=$(session_rows)
    if [[ -z "$rows" ]]; then
        echo "No claude-docker containers running."
        return 0
    fi
    { printf 'NAME\tPROJECT\tDIR\tAGE\n'; echo "$rows"; } | column -t -s $'\t'
}

# Reattach this terminal to a running project session, by container name or
# project (dir basename). The session keeps running after you detach.
# Usage: attach_session <name|project>
attach_session() {
    local target="$1" matches match_count
    if [[ -z "$target" ]]; then
        echo "Usage: claude-docker --attach <name|project>" >&2
        echo "Running sessions:" >&2
        list_sessions >&2
        exit 1
    fi

    if [[ "$target" == "$GLOBAL_CONTAINER_NAME" || "$target" == "(global)" ]]; then
        echo "The global container has no session of its own to attach to; run: claude-docker -g" >&2
        exit 1
    fi

    matches=$(session_rows | awk -F'\t' -v target="$target" '$1 == target || $2 == target')
    match_count=$(echo -n "$matches" | grep -c '^' || true)
    if [[ "$match_count" -eq 0 ]]; then
        echo "Error: no running claude-docker session named or in project '$target'." >&2
        list_sessions >&2
        exit 1
    elif [[ "$match_count" -gt 1 ]]; then
        echo "Several sessions match '$target'; attach by name:" >&2
        { printf 'NAME\tPROJECT\tDIR\tAGE\n'; echo "$matches"; } | column -t -s $'\t' >&2
        exit 1
    fi

    local name="${matches%%$'\t'*}"
    echo "Attaching to $name. Detach with Ctrl-Q Ctrl-Q (the session keeps running)." >&2
    echo "Exiting Claude ends the session for every attached terminal. If the screen stays blank, press a key." >&2
    exec docker attach --detach-keys "$ATTACH_DETACH_KEYS" "$name"
}
