# lib/sessions.sh
# Name, list, pick, reattach to and prune claude-docker containers.
#
# Project containers are labelled cid.project=<dir basename> and
# cid.dir=<host dir>, plus cid.client_pid/cid.tty for the terminal that launched
# them (see bin/claude-docker-project). Containers started before those labels
# existed are still listed, using their working dir and mounts.
#
# Runs on the host under macOS /bin/bash (3.2): no associative arrays or mapfile.

GLOBAL_CONTAINER_NAME="claude-docker-global"

# Every claude-docker container (project and global) is the compose service
# "claude" in the compose project "docker" (the name of the compose directory).
SESSION_FILTERS=(--filter "label=com.docker.compose.service=claude" --filter "label=com.docker.compose.project=docker")

# Claude Code binds Ctrl+P to history, and docker's default detach sequence
# (ctrl-p,ctrl-q) holds back every Ctrl+P until the next key. Ctrl+Q is unbound
# in Claude Code and ignored as flow control once docker puts the tty in raw mode.
ATTACH_DETACH_KEYS="ctrl-q,ctrl-q"

# Written by the in-container hook docker/etc/claude-code/session-status.sh,
# one <container name>.json per project session. ~/.claude is shared with
# every container, so the host reads them directly.
SESSION_STATUS_DIR="$HOME/.claude/session-status"

# --pick offers ended sessions (for --resume) from this far back.
ENDED_SESSION_MAX_AGE_SECONDS=$((7 * 24 * 3600))

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

# Read one field from a status file. The hook writes flat single-line JSON, so
# this needs no jq on the host. Usage: status_field <file> <key>
status_field() {
    sed -nE "s/.*\"$2\":(\"([^\"]*)\"|([0-9]+)).*/\\2\\3/p" "$1" 2>/dev/null
}

# Compact duration: 45s, 12m, 3h, 2d. Usage: format_duration <seconds>
format_duration() {
    local seconds="$1"
    if (( seconds < 60 )); then echo "${seconds}s"
    elif (( seconds < 3600 )); then echo "$((seconds / 60))m"
    elif (( seconds < 86400 )); then echo "$((seconds / 3600))h"
    else echo "$((seconds / 86400))d"
    fi
}

# Is this PID alive and still a docker client (not a reused PID)?
pid_is_docker_client() {
    [[ "$1" =~ ^[0-9]+$ ]] && ps -o command= -p "$1" 2>/dev/null | grep -q docker
}

# Live `docker compose ... run` clients of claude-docker-project, one
# "pid<TAB>tty<TAB>project dir" line each. The dir comes from the process
# environment (PROJECT_DIR), readable with ps -E for our own processes. Used to
# vouch for unlabelled (legacy) containers, which record no client.
compose_run_clients() {
    local pid tty command dir
    ps -axo pid=,tty=,command= | grep -E '(^|/)docker compose .*compose\.project\.yml.* run' |
        while read -r pid tty command; do
            dir=$(ps -E -o command= -p "$pid" 2>/dev/null | tr ' ' '\n' | sed -n 's/^PROJECT_DIR=//p' | head -1)
            if [[ -n "$dir" ]]; then printf '%s\t/dev/%s\t%s\n' "$pid" "$tty" "$dir"; fi
        done || true
}

# Live `claude-docker --attach` clients, one "pid<TAB>tty<TAB>container" line each.
attach_clients() {
    local pid tty command
    ps -axo pid=,tty=,command= | grep -E "(^|/)docker attach --detach-keys $ATTACH_DETACH_KEYS " |
        while read -r pid tty command; do
            printf '%s\t/dev/%s\t%s\n' "$pid" "$tty" "${command##* }"
        done || true
}

# One tab-separated line per running container, before working out its state:
# name, project, host dir, age, kind (global|labelled|legacy), client pid, client tty.
container_rows() {
    local id name project dir workdir mount_source client_pid client_tty age kind
    # Fields are split on the ASCII unit separator: a tab is IFS whitespace, so
    # read would merge the empty fields of unlabelled containers.
    local sep=$'\x1f'
    local format="{{.Name}}${sep}{{index .Config.Labels \"cid.project\"}}${sep}{{index .Config.Labels \"cid.dir\"}}${sep}{{.Config.WorkingDir}}${sep}{{\$wd := .Config.WorkingDir}}{{range .Mounts}}{{if eq .Destination \$wd}}{{.Source}}{{end}}{{end}}${sep}{{index .Config.Labels \"cid.client_pid\"}}${sep}{{index .Config.Labels \"cid.tty\"}}"
    for id in $(docker ps -q "${SESSION_FILTERS[@]}"); do
        IFS="$sep" read -r name project dir workdir mount_source client_pid client_tty < <(docker inspect --format "$format" "$id")
        name="${name#/}"
        age=$(docker ps --filter "id=$id" --format '{{.RunningFor}}')
        kind=labelled
        if [[ "$name" == "$GLOBAL_CONTAINER_NAME" ]]; then
            kind=global
            project="(global)"
            dir=$(docker inspect --format '{{range .Mounts}}{{if eq .Destination "/workspace"}}{{.Source}}{{end}}{{end}}' "$id")
        elif [[ -z "$project" ]]; then
            # Unlabelled container from an older claude-docker
            project="$(basename "$workdir")"
            dir="$mount_source"
        fi
        if [[ -z "$client_pid" && "$kind" == labelled ]]; then kind=legacy; fi
        # Docker Desktop reports bind mount sources under /host_mnt
        dir="${dir#/host_mnt}"
        printf '%s\t%s\t%s\t%s\t%s\t%s\t%s\n' "$name" "$project" "${dir:--}" "$age" "$kind" "${client_pid:--}" "${client_tty:--}"
    done
}

# Print one tab-separated line per running session:
#   1 name, 2 project, 3 host dir, 4 age, 5 state, 6 client tty,
#   7 activity (working|waiting|idle|ended|-), 8 activity epoch, 9 claude session id
# State is attached (its launching terminal or a --attach client is alive),
# detached (neither), legacy (unlabelled and no client could be matched to it),
# or global. A legacy container counts as attached when there are at least as
# many live, unclaimed compose clients for its dir as legacy containers there.
session_rows() {
    local containers compose_clients attachers claimed_pids
    local name project dir age kind client_pid client_tty state tty status_file activity activity_ts session_id
    local free_clients legacy_count attacher
    containers=$(container_rows)
    [[ -z "$containers" ]] && return 0
    compose_clients=$(compose_run_clients)
    attachers=$(attach_clients)
    claimed_pids=$(echo "$containers" | awk -F'\t' '$5 == "labelled" { printf "%s ", $6 }')

    echo "$containers" | while IFS=$'\t' read -r name project dir age kind client_pid client_tty; do
        tty="-"
        attacher=$(echo "$attachers" | awk -F'\t' -v name="$name" '$3 == name { print $2; exit }')
        case "$kind" in
            global)
                state=global
                ;;
            labelled)
                if pid_is_docker_client "$client_pid"; then
                    state=attached tty="$client_tty"
                elif [[ -n "$attacher" ]]; then
                    state=attached tty="$attacher"
                else
                    state=detached
                fi
                ;;
            legacy)
                free_clients=$(echo "$compose_clients" | awk -F'\t' -v dir="$dir" -v claimed="$claimed_pids" '
                    BEGIN { n = split(claimed, pids, " "); for (i = 1; i <= n; i++) taken[pids[i]] = 1 }
                    $3 == dir && !($1 in taken)')
                legacy_count=$(echo "$containers" | awk -F'\t' -v dir="$dir" '$5 == "legacy" && $3 == dir { n++ } END { print n + 0 }')
                if [[ -n "$attacher" ]]; then
                    state=attached tty="$attacher"
                elif [[ -n "$free_clients" && $(echo "$free_clients" | wc -l) -ge $legacy_count ]]; then
                    state=attached
                    # A tty is only known when exactly one client could be this container's
                    if [[ $(echo "$free_clients" | wc -l) -eq 1 ]]; then tty=$(echo "$free_clients" | cut -f2); fi
                else
                    state=legacy
                fi
                ;;
        esac

        activity="-" activity_ts="-" session_id="-"
        status_file="$SESSION_STATUS_DIR/$name.json"
        if [[ -f "$status_file" ]]; then
            activity=$(status_field "$status_file" state)
            activity_ts=$(status_field "$status_file" ts)
            session_id=$(status_field "$status_file" session_id)
        fi
        printf '%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\n' "$name" "$project" "$dir" "$age" "$state" "${tty:--}" \
            "${activity:--}" "${activity_ts:--}" "${session_id:--}"
    done
}

# "waiting 12m" from an activity and its epoch; "-" without a status file.
# Usage: activity_label <activity> <epoch>
activity_label() {
    if [[ "$1" == "-" || ! "$2" =~ ^[0-9]+$ ]]; then
        echo "-"
    else
        echo "$1 $(format_duration $(( $(date +%s) - $2 )))"
    fi
}

# Sessions waiting for the user first (longest-waiting on top), then working,
# idle, and the rest. Reads and writes session_rows lines.
sort_session_rows() {
    awk -F'\t' '{
        rank = ($7 == "waiting") ? 0 : ($7 == "working") ? 1 : ($7 == "idle") ? 2 : 3
        ts = ($8 ~ /^[0-9]+$/) ? $8 : 0
        print rank "\t" ts "\t" $0
    }' | sort -t $'\t' -k1,1n -k2,2n | cut -f3-
}

list_sessions() {
    local rows name project dir age state tty activity activity_ts session_id
    rows=$(session_rows | sort_session_rows)
    if [[ -z "$rows" ]]; then
        echo "No claude-docker containers running."
        return 0
    fi
    {
        printf 'NAME\tPROJECT\tSTATE\tACTIVITY\tAGE\n'
        echo "$rows" | while IFS=$'\t' read -r name project dir age state tty activity activity_ts session_id; do
            printf '%s\t%s\t%s\t%s\t%s\n' "$name" "$project" "$state" "$(activity_label "$activity" "$activity_ts")" "$age"
        done
    } | column -t -s $'\t'
}

# Sessions whose container is gone, from status files written in the last
# ENDED_SESSION_MAX_AGE_SECONDS, in session_rows format with state "ended".
# A file still saying working/idle/waiting means the container was stopped
# without Claude's SessionEnd hook running; it is just as resumable.
ended_session_rows() {
    local running="$1" status_file name dir ts session_id now
    now=$(date +%s)
    for status_file in "$SESSION_STATUS_DIR"/*.json; do
        [[ -f "$status_file" ]] || continue
        name=$(basename "$status_file" .json)
        echo "$running" | cut -f1 | grep -qx "$name" && continue
        ts=$(status_field "$status_file" ts)
        [[ "$ts" =~ ^[0-9]+$ ]] && (( now - ts <= ENDED_SESSION_MAX_AGE_SECONDS )) || continue
        dir=$(status_field "$status_file" dir)
        session_id=$(status_field "$status_file" session_id)
        printf '%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\n' "$name" "$(basename "${dir:-unknown}")" "${dir:--}" "-" ended "-" \
            ended "$ts" "${session_id:--}"
    done | sort -t $'\t' -k8,8nr
}

# Bring the iTerm2 tab whose session runs on this tty to the front.
# Usage: focus_iterm_tab <tty>; fails if iTerm2 isn't running or has no such tab.
focus_iterm_tab() {
    local result
    result=$(osascript - "$1" 2>/dev/null <<'APPLESCRIPT'
on run argv
    set targetTty to item 1 of argv
    if application id "com.googlecode.iterm2" is not running then return "missing"
    -- Find the window first, then act on it by id: selecting a window renumbers
    -- the iTerm windows, so index-based references to tabs go stale mid-loop.
    tell application id "com.googlecode.iterm2"
        set wid to missing value
        repeat with w in windows
            repeat with t in tabs of w
                repeat with s in sessions of t
                    if tty of s is targetTty then set wid to id of w
                end repeat
            end repeat
        end repeat
        if wid is missing value then return "missing"
        activate
        tell window id wid
            select
            repeat with t in tabs
                repeat with s in sessions of t
                    if tty of s is targetTty then
                        tell t to select
                        tell s to select
                        return "found"
                    end if
                end repeat
            end repeat
        end tell
    end tell
    return "missing"
end run
APPLESCRIPT
)
    [[ "$result" == "found" ]]
}

# Pick a session with fzf (or a numbered menu without it) and go to it:
# attached -> focus its iTerm tab, detached/legacy -> attach here,
# ended -> resume it in its project dir.
pick_session() {
    local running ended rows display choice line index=0
    local name project dir age state tty activity activity_ts session_id
    local lines=() labels=()
    running=$(session_rows | sort_session_rows)
    ended=$(ended_session_rows "$running")
    rows=$(printf '%s\n%s\n' "$running" "$ended" | grep -v '^$')
    if [[ -z "$rows" ]]; then
        echo "No running or recently ended claude-docker sessions."
        return 0
    fi

    # Visible columns, aligned; the full row rides along after a tab for fzf.
    display=$({
        printf 'STATE\tACTIVITY\tNAME\tPROJECT\tAGE\n'
        echo "$rows" | while IFS=$'\t' read -r name project dir age state tty activity activity_ts session_id; do
            printf '%s\t%s\t%s\t%s\t%s\n' "$state" "$(activity_label "$activity" "$activity_ts")" "$name" "$project" "$age"
        done
    } | column -t -s $'\t')

    if command -v fzf &>/dev/null; then
        choice=$(paste <(echo "$display") <(printf 'header\n%s\n' "$rows") |
            fzf --delimiter=$'\t' --with-nth=1 --header-lines=1 --no-sort --reverse \
                --prompt="session> " --height=~50%) || return 0
        line=$(echo "$choice" | cut -f2-)
    else
        while IFS= read -r line; do lines+=("$line"); done <<< "$rows"
        while IFS= read -r line; do labels+=("$line"); done <<< "$(echo "$display" | tail -n +2)"
        echo "   $(echo "$display" | head -1)"
        PS3="Session number (Enter to list again, Ctrl-C to cancel): "
        select choice in "${labels[@]}"; do
            [[ -n "$choice" ]] && { index=$((REPLY - 1)); break; }
        done
        [[ -n "$choice" ]] || return 0
        line="${lines[$index]}"
    fi

    IFS=$'\t' read -r name project dir age state tty activity activity_ts session_id <<< "$line"
    case "$state" in
        attached)
            if [[ "$tty" != "-" ]] && focus_iterm_tab "$tty"; then
                echo "Switched to $name ($tty)."
            elif [[ "$tty" != "-" ]]; then
                echo "$name is attached in the terminal on $tty, but no iTerm tab has that tty."
                echo "To join it here as well: claude-docker --attach $name"
            else
                echo "$name is attached in another terminal, which could not be identified."
                echo "To join it here as well: claude-docker --attach $name"
            fi
            ;;
        detached|legacy)
            attach_session "$name"
            ;;
        global)
            echo "The global container has no session of its own; run: claude-docker -g"
            ;;
        ended)
            if [[ "$session_id" == "-" ]]; then
                echo "$name recorded no Claude session id, so it can't be resumed."
                echo "Start a new one with: cd '$dir' && claude-docker"
            elif [[ -d "$dir" ]]; then
                echo "Resuming $name in $dir: claude-docker -d --resume $session_id" >&2
                cd "$dir" && exec "$ROOT_DIR/bin/claude-docker" -d --resume "$session_id"
            else
                echo "$dir no longer exists here. To resume $name, run from its project dir:"
                echo "  claude-docker -d --resume $session_id"
            fi
            ;;
    esac
}

# Stop every detached session, plus legacy ones no client can vouch for.
# Their containers were started with --rm, so stopping removes them.
# Usage: prune_sessions [--yes]
prune_sessions() {
    local assume_yes=false rows count reply name project dir age state tty activity activity_ts session_id
    local names=()
    [[ "${1:-}" == "--yes" || "${1:-}" == "-y" ]] && assume_yes=true

    # Status files of sessions that ended long ago are no use to --pick.
    if [[ -d "$SESSION_STATUS_DIR" ]]; then
        find "$SESSION_STATUS_DIR" -name '*.json' -mtime +7 -delete 2>/dev/null || true
    fi

    rows=$(session_rows | awk -F'\t' '$5 == "detached" || $5 == "legacy"')
    if [[ -z "$rows" ]]; then
        echo "No detached claude-docker sessions."
        return 0
    fi
    count=$(echo "$rows" | wc -l | tr -d ' ')

    echo "$count detached session(s):"
    {
        printf '  NAME\tPROJECT\tIDLE FOR\tNOTE\n'
        echo "$rows" | while IFS=$'\t' read -r name project dir age state tty activity activity_ts session_id; do
            local idle_for="unknown" note=""
            if [[ "$activity_ts" =~ ^[0-9]+$ ]]; then idle_for=$(format_duration $(( $(date +%s) - activity_ts ))); fi
            if [[ "$state" == "legacy" ]]; then note="legacy: started before client tracking, could not confirm it is attached"; fi
            printf '  %s\t%s\t%s\t%s\n' "$name" "$project" "$idle_for" "$note"
        done
    } | column -t -s $'\t'
    while IFS=$'\t' read -r name _; do names+=("$name"); done <<< "$rows"

    if ! $assume_yes; then
        printf 'Stop %s detached session(s)? [y/N] ' "$count"
        read -r reply || reply=""
        if [[ ! "$reply" =~ ^[Yy]([Ee][Ss])?$ ]]; then
            echo "Nothing stopped."
            return 0
        fi
    fi
    docker stop "${names[@]}" >/dev/null
    echo "Stopped ${#names[@]} session(s): ${names[*]}"
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
        { printf 'NAME\tPROJECT\tDIR\tSTATE\n'; echo "$matches" | awk -F'\t' -v OFS='\t' '{ print $1, $2, $3, $5 }'; } | column -t -s $'\t' >&2
        exit 1
    fi

    local name="${matches%%$'\t'*}"
    echo "Attaching to $name. Detach with Ctrl-Q Ctrl-Q (the session keeps running)." >&2
    echo "Exiting Claude ends the session for every attached terminal. If the screen stays blank, press a key." >&2
    exec docker attach --detach-keys "$ATTACH_DETACH_KEYS" "$name"
}
